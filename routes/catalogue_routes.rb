# @see SonCatalogue
class SonataCatalogue < Sinatra::Application
  require 'addressable/uri'

	before do
		# Gatekeepr authn. code will go here for future implementation
		# --> Gatekeeper authn. disabled
		#if request.path_info == '/gk_credentials'
		#	return
		#end
		if settings.environment == 'development'
			return
		end
		#authorized?
  end

  DEFAULT_OFFSET = "0"
  DEFAULT_LIMIT = "10"
  DEFAULT_MAX_LIMIT = "100"

	# @method get_root
	# @overload get '/catalogues/'
	# Get all available interfaces
	# -> Get all interfaces
	get '/' do
    	headers "Content-Type" => "text/plain; charset=utf8"
		halt 200, interfaces_list.to_yaml
	end

	############################################ NSD API METHODS ############################################

	# @method get_nss
	# @overload get '/catalogues/network-services/?'
	#	Returns a list of NSs
	# -> List many descriptors
  get '/network-services/?' do
    params['offset'] ||= DEFAULT_OFFSET
    params['limit'] ||= DEFAULT_LIMIT

    uri = Addressable::URI.new
    uri.query_values = params
    puts 'params', params
    puts 'query_values', uri.query_values
    logger.info "Catalogue: entered GET /network-services?#{uri.query}"

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)
    puts 'keyed_params', keyed_params

    # Set headers
    case request.content_type
      when 'application/x-yaml'
        headers = { 'Accept' => 'application/x-yaml', 'Content-Type' => 'application/x-yaml' }
      else
        headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    end
    headers[:params] = params unless params.empty?

    # Get rid of :offset and :limit
    [:offset, :limit].each { |k| keyed_params.delete(k) }
    #puts 'keyed_params(1)', keyed_params

    # Check for special case (:version param == last)
    if keyed_params.key?(:version) && keyed_params[:version] == 'last'
      # Do query for last version -> get_nsd_ns_vendor_last_version

      keyed_params.delete(:version)
      #puts 'keyed_params(2)', keyed_params

      nss = Ns.where((keyed_params)).sort({"version" => -1})#.limit(1).first()
      logger.info "Catalogue: NSDs=#{nss}"
      #nss = nss.sort({"version" => -1})
      #puts 'nss: ', nss.to_json

      if nss && nss.size.to_i > 0
        logger.info "Catalogue: leaving GET /network-services?#{uri.query} with #{nss}"

        # Paginate results
        #nss = nss.paginate(:offset => params[:offset], :limit => params[:limit]).sort({"version" => -1})

        nss_list = []
        checked_list = []

        nss_name_vendor = Pair.new(nss.first.name, nss.first.vendor)
        #p 'nss_name_vendor:', [nss_name_vendor.one, nss_name_vendor.two]
        checked_list.push(nss_name_vendor)
        nss_list.push(nss.first)

        nss.each do |nsd|
          #p 'Comparison: ', [nsd.name, nsd.vendor].to_s + [nss_name_vendor.one, nss_name_vendor.two].to_s
          if (nsd.name != nss_name_vendor.one) || (nsd.vendor != nss_name_vendor.two)
            nss_name_vendor = Pair.new(nsd.name, nsd.vendor)
            #p 'nss_name_vendor(x):', [nss_name_vendor.one, nss_name_vendor.two]
            #checked_list.each do |pair|
            #  p [pair.one, nss_name_vendor.one], [pair.two, nss_name_vendor.two]
            #  p pair.one == nss_name_vendor.one && pair.two == nss_name_vendor.two
            end
            nss_list.push(nsd) unless
                checked_list.any? {|pair| pair.one == nss_name_vendor.one && pair.two == nss_name_vendor.two}
            checked_list.push(nss_name_vendor)
          end

          #puts 'nss_list:', nss_list.each {|ns| p ns.name, ns.vendor}
        else
            logger.error "ERROR: 'No NSDs were found'"
            logger.info "Catalogue: leaving GET /network-services?#{uri.query} with 'No NSDs were found'"
            json_error 404, "No NSDs were found"
        end
        #nss = nss_list.paginate(:page => params[:offset], :per_page =>params[:limit])
      nss = nss_list

    else
      # Do the query
      nss = Ns.where(keyed_params)
      logger.info "Catalogue: NSDs=#{nss}"
      #puts nss.to_json
      if nss && nss.size.to_i > 0
        logger.info "Catalogue: leaving GET /network-services?#{uri.query} with #{nss}"

        # Paginate results
        nss = nss.paginate(:offset => params[:offset], :limit => params[:limit])

      else
        logger.info "Catalogue: leaving GET /network-services?#{uri.query} with 'No NSDs were found'"
        json_error 404, "No NSDs were found"
      end
    end

      case request.content_type
        when 'application/json'
          response = nss.to_json
        when 'application/x-yaml'
          response = json_to_yaml(nss.to_json)
        else
          halt 415
        end
        halt 200, response
  end

  # @method get_ns_sp_ns_id
  # @overload get '/catalogues/network-services/:id/?'
  #	GET one specific descriptor
  #	@param [String] sp_ns_id NS sp ID
  # Show a NS by internal ID (uuid)
  get '/network-services/:id/?' do
    unless params[:id].nil?
      logger.debug "Catalogue: GET /network-services/#{params[:id]}"

      begin
        ns = Ns.find(params[:id] )
      rescue Mongoid::Errors::DocumentNotFound => e
        logger.error e
        json_error 404, "The NSD ID #{params[:id]} does not exist" unless ns
      end
      logger.debug "Catalogue: leaving GET /network-services/#{params[:id]}\" with NSD #{ns}"

      case request.content_type
        when 'application/json'
          response = ns.to_json
        when 'application/x-yaml'
          response = json_to_yaml(ns.to_json)
        else
          halt 415
      end
      halt 200, response

    end
    logger.debug "Catalogue: leaving GET /network-services/#{params[:id]} with 'No NSD ID specified'"
    json_error 400, "No NSD ID specified"
  end

	# @method post_nss
	# @overload post '/catalogues/network-services'
	# Post a NS in JSON or YAML format
	post '/network-services' do
		# Return if content-type is invalid
		halt 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

		# Compatibility support for YAML content-type
    case request.content_type
      when 'application/x-yaml'
        # Validate YAML format
        # When updating a NSD, the json object sent to API must contain just data inside
        # of the nsd, without the json field nsd: before
        ns, errors = parse_yaml(request.body.read)
        halt 400, errors.to_json if errors

        # Translate from YAML format to JSON format
        new_ns_json = yaml_to_json(ns)

        # Validate JSON format
        new_ns, errors = parse_json(new_ns_json)
        puts 'ns: ', new_ns.to_json
        #puts 'new_ns id', new_ns['_id'].to_json
        halt 400, errors.to_json if errors

      else
        # Compatibility support for JSON content-type
        # Parses and validates JSON format
        new_ns, errors = parse_json(request.body.read)
        halt 400, errors.to_json if errors
    end

		# Validate NS
    json_error 400, "ERROR: NS Vendor not found" unless new_ns.has_key?('vendor')
    json_error 400, "ERROR: NS Name not found" unless new_ns.has_key?('name')
    json_error 400, "ERROR: NS Version not found" unless new_ns.has_key?('version')

		# --> Validation disabled
		# Validate NSD
		#begin
		#	RestClient.post settings.nsd_validator + '/nsds', ns.to_json, :content_type => :json
		#rescue => e
		#	halt 500, {'Content-Type' => 'text/plain'}, "Validator mS unrechable."
		#end

		# Check if NS already exists in the catalogue by name, vendor and version
		begin
			ns = Ns.find_by({"name" =>  new_ns['name'], "vendor" => new_ns['vendor'], "version" => new_ns['version']})
      json_error 400, "ERROR: Duplicated NS Name, Vendor and Version"
		rescue Mongoid::Errors::DocumentNotFound => e
		end
		# Check if NSD has an ID (it should not) and if it already exists in the catalogue
		begin
			ns = Ns.find_by({"_id" =>  new_ns['_id']})
      json_error 400, "ERROR: Duplicated NS ID"
		rescue Mongoid::Errors::DocumentNotFound => e
		end

		# Save to DB
		begin
			# Generate the UUID for the descriptor
      new_ns['_id'] = SecureRandom.uuid
      new_ns['status'] = 'inactive'
			ns = Ns.create!(new_ns)
		rescue Moped::Errors::OperationFailure => e
      json_error 400, "ERROR: Duplicated NS ID" if e.message.include? 'E11000'
		end

		puts 'New NS has been added'
    case request.content_type
      when 'application/json'
        response = ns.to_json
      when 'application/x-yaml'
        response = json_to_yaml(ns.to_json)
      else
        halt 415
    end
    halt 201, response
  end

  # @method update_nss
  # @overload put '/catalogues/network-services/?'
  # Update a NS by vendor, name and version in JSON or YAML format
  ## Catalogue - UPDATE
  put '/network-services/?' do
    uri = Addressable::URI.new
    uri.query_values = params
    puts 'params', params
    puts 'query_values', uri.query_values
    logger.info "Catalogue: entered PUT /network-services?#{uri.query}"

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)
    puts 'keyed_params', keyed_params

    # Return if content-type is invalid
    halt 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    # Compatibility support for YAML content-type
    case request.content_type
      when 'application/x-yaml'
        # Validate YAML format
        # When updating a NSD, the json object sent to API must contain just data inside
        # of the nsd, without the json field nsd: before
        ns, errors = parse_yaml(request.body.read)
        halt 400, errors.to_json if errors

        # Translate from YAML format to JSON format
        new_ns_json = yaml_to_json(ns)

        # Validate JSON format
        new_ns, errors = parse_json(new_ns_json)
        puts 'ns: ', new_ns.to_json
        #puts 'new_ns id', new_ns['_id'].to_json
        halt 400, errors.to_json if errors

      else
        # Compatibility support for JSON content-type
        # Parses and validates JSON format
        new_ns, errors = parse_json(request.body.read)
        halt 400, errors.to_json if errors
    end

    # Validate NS
    # Check if same vendor, Name, Version do already exists in the database
    json_error 400, "ERROR: NS Vendor not found" unless new_ns.has_key?('vendor')
    json_error 400, "ERROR: NS Name not found" unless new_ns.has_key?('name')
    json_error 400, "ERROR: NS Version not found" unless new_ns.has_key?('version')

    # Set headers
    case request.content_type
      when 'application/x-yaml'
        headers = { 'Accept' => 'application/x-yaml', 'Content-Type' => 'application/x-yaml' }
      else
        headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    end
    headers[:params] = params unless params.empty?

    # Retrieve stored version
    unless keyed_params[:vendor].nil? && keyed_params[:name].nil? && keyed_params[:version].nil?
      begin
        ns = Ns.find_by({"vendor" => keyed_params[:vendor], "name" =>  keyed_params[:name], "version" => keyed_params[:version]})
        puts 'NS is found'
      rescue Mongoid::Errors::DocumentNotFound => e
        json_error 404, "The NSD Vendor #{keyed_params[:vendor]}, Name #{keyed_params[:name]}, Version #{keyed_params[:version]} does not exist"
      end
    end
    # Check if NS already exists in the catalogue by name, group and version
    begin
      ns = Ns.find_by({"name" =>  new_ns['name'], "vendor" => new_ns['vendor'], "version" => new_ns['version']})
      json_error 400, "ERROR: Duplicated NS Name, Vendor and Version"
    rescue Mongoid::Errors::DocumentNotFound => e
    end

    # Update to new version
    puts 'Updating...'
    new_ns['_id'] = SecureRandom.uuid	# Unique UUIDs per NSD entries
    nsd = new_ns

    # --> Validation disabled
    # Validate NSD
    #begin
    #	RestClient.post settings.nsd_validator + '/nsds', nsd.to_json, :content_type => :json
    #rescue => e
    #	logger.error e.response
    #	return e.response.code, e.response.body
    #end

    begin
      new_ns = Ns.create!(nsd)
    rescue Moped::Errors::OperationFailure => e
      json_error 400, "ERROR: Duplicated NS ID" if e.message.include? 'E11000'
    end
    logger.debug "Catalogue: leaving PUT /network-services?#{uri.query}\" with NSD #{new_ns}"

    case request.content_type
      when 'application/json'
        response = new_ns.to_json
      when 'application/x-yaml'
        response = json_to_yaml(new_ns.to_json)
      else
        halt 415
    end
    halt 200, response
  end

	# @method update_nss_id
	# @overload put '/catalogues/network-services/:id/?'
	# Update a NS in JSON or YAML format
	## Catalogue - UPDATE
	put '/network-services/:id/?' do
		# Return if content-type is invalid
		halt 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    unless params[:id].nil?
      logger.debug "Catalogue: PUT /network-services/#{params[:id]}"

      # Transform 'string' params Hash into keys
      keyed_params = keyed_hash(params)
      puts 'keyed_params', keyed_params

      # Check for special case (:status param == <new_status>)
      if keyed_params.key?(:status)
        # Do update of Descriptor status -> update_ns_status
        uri = Addressable::URI.new
        uri.query_values = params
        logger.info "Catalogue: entered PUT /network-services/#{uri.query}"

        # Validate NS
        # Retrieve stored version
        begin
          puts 'Searching ' + params[:id].to_s
          ns = Ns.find_by( { "_id" =>  params[:id] } )
          puts 'NS is found'
        rescue Mongoid::Errors::DocumentNotFound => e
          json_error 404, "This NSD does not exists"
        end

        #Validate new status
        valid_status = ['active', 'inactive', 'delete']
        if valid_status.include? keyed_params[:status]
          # Update to new status
          begin
            ns.update_attributes(:status => params[:new_status])
          rescue Moped::Errors::OperationFailure => e
            json_error 400, "ERROR: Operation failed"
          end
        else
          json_error 400, "Invalid new status #{keyed_params[:status]}"
        end

        # --> Validation disabled
        # Validate NSD
        #begin
        #	RestClient.post settings.nsd_validator + '/nsds', nsd.to_json, :content_type => :json
        #rescue => e
        #	logger.error e.response
        #	return e.response.code, e.response.body
        #end

        halt 200, "Status updated to #{uri.query_values}"

      else
		    # Compatibility support for YAML content-type
		    case request.content_type
          when 'application/x-yaml'
            # Validate YAML format
            # When updating a NSD, the json object sent to API must contain just data inside
            # of the nsd, without the json field nsd: before
            ns, errors = parse_yaml(request.body.read)
            halt 400, errors.to_json if errors

            # Translate from YAML format to JSON format
            new_ns_json = yaml_to_json(ns)

            # Validate JSON format
            new_ns, errors = parse_json(new_ns_json)
            puts 'ns: ', new_ns.to_json
            #puts 'new_ns id', new_ns['_id'].to_json
            halt 400, errors.to_json if errors

          else
            # Compatibility support for JSON content-type
            # Parses and validates JSON format
            new_ns, errors = parse_json(request.body.read)
            halt 400, errors.to_json if errors
        end

		    # Validate NS
		    # Check if same vendor, Name, Version do already exists in the database
        json_error 400, "ERROR: NS Vendor not found" unless new_ns.has_key?('vendor')
        json_error 400, "ERROR: NS Name not found" unless new_ns.has_key?('name')
        json_error 400, "ERROR: NS Version not found" unless new_ns.has_key?('version')

		    # Retrieve stored version
		    begin
			    puts 'Searching ' + params[:id].to_s
			    ns = Ns.find_by( { "_id" =>  params[:id] })
			    puts 'NS is found'
        rescue Mongoid::Errors::DocumentNotFound => e
          json_error 404, "The NSD ID #{params[:id]} does not exist"
        end

		    # Check if NS already exists in the catalogue by name, vendor and version
		    begin
			    ns = Ns.find_by({"name" =>  new_ns['name'], "vendor" => new_ns['vendor'], "version" => new_ns['version']})
          json_error 400, "ERROR: Duplicated NS Name, Vendor and Version"
		    rescue Mongoid::Errors::DocumentNotFound => e
		    end

		    # Update to new version
		    puts 'Updating...'
		    new_ns['_id'] = SecureRandom.uuid
		    nsd = new_ns

		    # --> Validation disabled
		    # Validate NSD
		    #begin
		    #	RestClient.post settings.nsd_validator + '/nsds', nsd.to_json, :content_type => :json
		    #rescue => e
		    #	logger.error e.response
		    #	return e.response.code, e.response.body
		    #end

		    begin
			    new_ns = Ns.create!(nsd)
		    rescue Moped::Errors::OperationFailure => e
          json_error 400, "ERROR: Duplicated NS ID" if e.message.include? 'E11000'
        end
        logger.debug "Catalogue: leaving PUT /network-services/#{params[:id]}\" with NSD #{new_ns}"

        case request.content_type
          when 'application/json'
            response = new_ns.to_json
          when 'application/x-yaml'
            response = json_to_yaml(new_ns.to_json)
          else
            halt 415
        end
        halt 200, response
      end
    end
    logger.debug "Catalogue: leaving PUT /network-services/#{params[:id]} with 'No NSD ID specified'"
    json_error 400, "No NSD ID specified"
  end

  # @method delete_nsd_sp_ns
  # @overload delete '/network-services/?'
  #	Delete a NS by vendor, name and version
  delete '/network-services/?' do
    uri = Addressable::URI.new
    uri.query_values = params
    puts 'params', params
    puts 'query_values', uri.query_values
    logger.info "Catalogue: entered DELETE /network-services?#{uri.query}"

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)
    puts 'keyed_params', keyed_params

    unless keyed_params[:vendor].nil? && keyed_params[:name].nil? && keyed_params[:version].nil?
      begin
        ns = Ns.find_by({"vendor" => keyed_params[:vendor], "name" =>  keyed_params[:name], "version" => keyed_params[:version]})
        puts 'NS is found'
      rescue Mongoid::Errors::DocumentNotFound => e
        json_error 404, "The NSD Vendor #{keyed_params[:vendor]}, Name #{keyed_params[:name]}, Version #{keyed_params[:version]} does not exist"
      end
      logger.debug "Catalogue: leaving DELETE /network-services?#{uri.query}\" with NSD #{ns}"
      ns.destroy
      halt 200, "OK: NSD removed"
    end
    logger.debug "Catalogue: leaving DELETE /network-services?#{uri.query} with 'No NSD Vendor, Name, Version specified'"
    json_error 400, "No NSD Vendor, Name, Version specified"
  end

	# @method delete_nsd_sp_ns_id
	# @overload delete '/catalogues/network-service/:id/?'
	#	Delete a NS by its ID
	#	@param [uuid] sp_ns_id NS sp ID
	# Delete a NS by uuid
	delete '/network-services/:id/?' do
    unless params[:id].nil?
      logger.debug "Catalogue: DELETE /network-services/#{params[:id]}"
      begin
        ns = Ns.find(params[:id] )
      rescue Mongoid::Errors::DocumentNotFound => e
        logger.error e
        json_error 404, "The NSD ID #{params[:id]} does not exist" unless ns
      end
      logger.debug "Catalogue: leaving DELETE /network-services/#{params[:id]}\" with NSD #{ns}"
      ns.destroy
      halt 200, 'OK: NSD removed'
    end
    logger.debug "Catalogue: leaving DELETE /network-services/#{params[:id]} with 'No NSD ID specified'"
    json_error 400, "No NSD ID specified"
	end


	############################################ VNFD API METHODS ############################################

  # @method get_vnfs
  # @overload get '/catalogues/vnfs/?'
  #	Returns a list of VNFs
  # -> List many descriptors
  get '/vnfs/?' do
    params['offset'] ||= DEFAULT_OFFSET
    params['limit'] ||= DEFAULT_LIMIT

    uri = Addressable::URI.new
    uri.query_values = params
    puts 'params', params
    puts 'query_values', uri.query_values
    logger.info "Catalogue: entered GET /vnfs?#{uri.query}"

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)
    puts 'keyed_params', keyed_params

    # Set headers
    case request.content_type
      when 'application/x-yaml'
        headers = { 'Accept' => 'application/x-yaml', 'Content-Type' => 'application/x-yaml' }
      else
        headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    end
    headers[:params] = params unless params.empty?

    # Get rid of :offset and :limit
    [:offset, :limit].each { |k| keyed_params.delete(k) }
    #puts 'keyed_params(1)', keyed_params

    # Check for special case (:version param == last)
    if keyed_params.key?(:version) && keyed_params[:version] == 'last'
      # Do query for last version -> get_nsd_ns_vendor_last_version

      keyed_params.delete(:version)
      #puts 'keyed_params(2)', keyed_params

      vnfs = Vnf.where((keyed_params)).sort({"version" => -1})#.limit(1).first()
      logger.info "Catalogue: VNFDs=#{vnfs}"
      #vnfs = vnfs.sort({"version" => -1})
      #puts 'vnfs: ', vnfs.to_json

      if vnfs && vnfs.size.to_i > 0
        logger.info "Catalogue: leaving GET /vnfs?#{uri.query} with #{vnfs}"

        # Paginate results
        #vnfs = vnfs.paginate(:offset => params[:offset], :limit => params[:limit]).sort({"version" => -1})

        vnfs_list = []
        checked_list = []

        vnfs_name_vendor = Pair.new(vnfs.first.name, vnfs.first.vendor)
        #p 'vnfs_name_vendor:', [vnfs_name_vendor.one, vnfs_name_vendor.two]
        checked_list.push(vnfs_name_vendor)
        vnfs_list.push(vnfs.first)

        vnfs.each do |vnfd|
          #p 'Comparison: ', [vnfd.name, vnfd.vendor].to_s + [vnfs_name_vendor.one, vnfs_name_vendor.two].to_s
          if (vnfd.name != vnfs_name_vendor.one) || (vnfd.vendor != vnfs_name_vendor.two)
            vnfs_name_vendor = Pair.new(vnfd.name, vnfd.vendor)
          end
          vnfs_list.push(vnfd) unless
              checked_list.any? {|pair| pair.one == vnfs_name_vendor.one && pair.two == vnfs_name_vendor.two}
          checked_list.push(vnfs_name_vendor)
        end
        #puts 'vnfs_list:', vnfs_list.each {|vnf| p vnf.name, vnf.vendor}
      else
        logger.error "ERROR: 'No VNFDs were found'"
        logger.info "Catalogue: leaving GET /vnfs?#{uri.query} with 'No VNFDs were found'"
        json_error 404, "No VNFDs were found"
      end
      #vnfs = vnfs_list.paginate(:page => params[:offset], :per_page =>params[:limit])
      vnfs = vnfs_list

    else
      # Do the query
      vnfs = Vnf.where(keyed_params)
      logger.info "Catalogue: VNFDs=#{vnfs}"
      #puts vnfs.to_json
      if vnfs && vnfs.size.to_i > 0
        logger.info "Catalogue: leaving GET /vnfs?#{uri.query} with #{vnfs}"

        # Paginate results
        vnfs = vnfs.paginate(:offset => params[:offset], :limit => params[:limit])

      else
        logger.info "Catalogue: leaving GET /vnfs?#{uri.query} with 'No VNFDs were found'"
        json_error 404, "No VNFDs were found"
      end
    end

    case request.content_type
      when 'application/json'
        response = vnfs.to_json
      when 'application/x-yaml'
        response = json_to_yaml(vnfs.to_json)
      else
        halt 415
    end
    halt 200, response
  end

  # @method get_vnfs_id
  # @overload get '/catalogues/vnfs/:id/?'
  #	GET one specific descriptor
  #	@param [String] id VNF ID
  # Show a VNF by internal ID (uuid)
  get '/vnfs/:id/?' do
    unless params[:id].nil?
      logger.debug "Catalogue: GET /vnfs/#{params[:id]}"

      begin
        vnf = Vnf.find(params[:id] )
      rescue Mongoid::Errors::DocumentNotFound => e
        logger.error e
        json_error 404, "The VNFD ID #{params[:id]} does not exist" unless vnf
      end
      logger.debug "Catalogue: leaving GET /vnfs/#{params[:id]}\" with VNFD #{vnf}"

      case request.content_type
        when 'application/json'
          response = vnf.to_json
        when 'application/x-yaml'
          response = json_to_yaml(vnf.to_json)
        else
          halt 415
      end
      halt 200, response

    end
    logger.debug "Catalogue: leaving GET /vnfs/#{params[:id]} with 'No VNFD ID specified'"
    json_error 400, "No VNFD ID specified"
  end

	# @method post_vnfs
	# @overload post '/catalogues/vnfs'
	# Post a VNF in JSON or YAML format

	post '/vnfs' do
    # Return if content-type is invalid
    halt 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    # Compatibility support for YAML content-type
    case request.content_type
      when 'application/x-yaml'
        # Validate YAML format
        # When updating a VNFD, the json object sent to API must contain just data inside
        # of the vnfd, without the json field vnfd: before
        vnf, errors = parse_yaml(request.body.read)
        halt 400, errors.to_json if errors

        # Translate from YAML format to JSON format
        new_vnf_json = yaml_to_json(vnf)

        # Validate JSON format
        new_vnf, errors = parse_json(new_vnf_json)
        puts 'vnf: ', new_vnf.to_json
        #puts 'new_vnf id', new_vnf['_id'].to_json
        halt 400, errors.to_json if errors

      else
        # Compatibility support for JSON content-type
        # Parses and validates JSON format
        new_vnf, errors = parse_json(request.body.read)
        halt 400, errors.to_json if errors
    end

    # Validate VNF
    json_error 400, "ERROR: VNF Vendor not found" unless new_vnf.has_key?('vendor')
    json_error 400, "ERROR: VNF Name not found" unless new_vnf.has_key?('name')
    json_error 400, "ERROR: VNF Version not found" unless new_vnf.has_key?('version')

    # --> Validation disabled
    # Validate VNFD
    #begin
    #	RestClient.post settings.nsd_validator + '/nsds', ns.to_json, :content_type => :json
    #rescue => e
    #	halt 500, {'Content-Type' => 'text/plain'}, "Validator mS unrechable."
    #end

    # Check if VNFD already exists in the catalogue by name, vendor and version
    begin
      vnf = Vnf.find_by({"name" =>  new_vnf['name'], "vendor" => new_vnf['vendor'], "version" => new_vnf['version']})
      json_error 400, "ERROR: Duplicated VNF Name, Vendor and Version"
    rescue Mongoid::Errors::DocumentNotFound => e
    end
    # Check if VNFD has an ID (it should not) and if it already exists in the catalogue
    begin
      vnf = Vnf.find_by({"_id" =>  new_vnf['_id']})
      json_error 400, "ERROR: Duplicated VNF ID"
    rescue Mongoid::Errors::DocumentNotFound => e
    end

    # Save to DB
    begin
      # Generate the UUID for the descriptor
      new_vnf['_id'] = SecureRandom.uuid
      new_vnf['status'] = 'inactive'
      vnf = Vnf.create!(new_vnf)
    rescue Moped::Errors::OperationFailure => e
      json_error 400, "ERROR: Duplicated VNF ID" if e.message.include? 'E11000'
    end

    puts 'New VNF has been added'
    case request.content_type
      when 'application/json'
        response = ns.to_json
      when 'application/x-yaml'
        response = json_to_yaml(ns.to_json)
      else
        halt 415
    end
    halt 201, response
  end

  # @method update_vnfs
  # @overload put '/vnfs/?'
  # Update a VNF by vendor, name and version in JSON or YAML format
  ## Catalogue - UPDATE
  put '/vnfs/?' do
    uri = Addressable::URI.new
    uri.query_values = params
    puts 'params', params
    puts 'query_values', uri.query_values
    logger.info "Catalogue: entered PUT /vnfs?#{uri.query}"

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)
    puts 'keyed_params', keyed_params

    # Return if content-type is invalid
    halt 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    # Compatibility support for YAML content-type
    case request.content_type
      when 'application/x-yaml'
        # Validate YAML format
        # When updating a NSD, the json object sent to API must contain just data inside
        # of the nsd, without the json field nsd: before
        vnf, errors = parse_yaml(request.body.read)
        halt 400, errors.to_json if errors

        # Translate from YAML format to JSON format
        new_vnf_json = yaml_to_json(vnf)

        # Validate JSON format
        new_vnf, errors = parse_json(new_vnf_json)
        puts 'vnf: ', new_vnf.to_json
        #puts 'new_vnf id', new_vnf['_id'].to_json
        halt 400, errors.to_json if errors

      else
        # Compatibility support for JSON content-type
        # Parses and validates JSON format
        new_vnf, errors = parse_json(request.body.read)
        halt 400, errors.to_json if errors
    end

    # Validate NS
    # Check if same vendor, Name, Version do already exists in the database
    json_error 400, "ERROR: VNF Vendor not found" unless new_vnf.has_key?('vendor')
    json_error 400, "ERROR: VNF Name not found" unless new_vnf.has_key?('name')
    json_error 400, "ERROR: VNF Version not found" unless new_vnf.has_key?('version')

    # Set headers
    case request.content_type
      when 'application/x-yaml'
        headers = { 'Accept' => 'application/x-yaml', 'Content-Type' => 'application/x-yaml' }
      else
        headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    end
    headers[:params] = params unless params.empty?

    # Retrieve stored version
    unless keyed_params[:vendor].nil? && keyed_params[:name].nil? && keyed_params[:version].nil?
      begin
        vnf = Vnf.find_by({"vendor" => keyed_params[:vendor], "name" =>  keyed_params[:name], "version" => keyed_params[:version]})
        puts 'VNF is found'
      rescue Mongoid::Errors::DocumentNotFound => e
        json_error 404, "The VNFD Vendor #{keyed_params[:vendor]}, Name #{keyed_params[:name]}, Version #{keyed_params[:version]} does not exist"
      end
    end
    # Check if VNF already exists in the catalogue by name, group and version
    begin
      vnf = Vnf.find_by({"name" =>  new_vnf['name'], "vendor" => new_vnf['vendor'], "version" => new_vnf['version']})
      json_error 400, "ERROR: Duplicated VNF Name, Vendor and Version"
    rescue Mongoid::Errors::DocumentNotFound => e
    end

    # Update to new version
    puts 'Updating...'
    new_vnf['_id'] = SecureRandom.uuid	# Unique UUIDs per VNFD entries
    vnfd = new_vnf

    # --> Validation disabled
    # Validate VNFD
    #begin
    #	RestClient.post settings.nsd_validator + '/nsds', nsd.to_json, :content_type => :json
    #rescue => e
    #	logger.error e.response
    #	return e.response.code, e.response.body
    #end

    begin
      new_vnf = Vnf.create!(vnfd)
    rescue Moped::Errors::OperationFailure => e
      json_error 400, "ERROR: Duplicated VNF ID" if e.message.include? 'E11000'
    end
    logger.debug "Catalogue: leaving PUT /vnfs?#{uri.query}\" with VNFD #{new_vnf}"

    case request.content_type
      when 'application/json'
        response = new_vnf.to_json
      when 'application/x-yaml'
        response = json_to_yaml(new_vnf.to_json)
      else
        halt 415
    end
    halt 200, response
  end

	# @method update_vnfs_id
	# @overload put '/catalogues/vnfs/:id/?'
	#	Update a VNF by its ID in JSON or YAML format
  ## Catalogue - UPDATE
	put '/vnfs/:id/?' do
    # Return if content-type is invalid
    halt 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    unless params[:id].nil?
      logger.debug "Catalogue: PUT /vnfs/#{params[:id]}"

      # Transform 'string' params Hash into keys
      keyed_params = keyed_hash(params)
      puts 'keyed_params', keyed_params

      # Check for special case (:status param == <new_status>)
      if keyed_params.key?(:status)
        # Do update of Descriptor status -> update_ns_status
        uri = Addressable::URI.new
        uri.query_values = params
        logger.info "Catalogue: entered PUT /vnfs/#{uri.query}"

        # Validate VNF
        # Retrieve stored version
        begin
          puts 'Searching ' + params[:id].to_s
          vnf = Vnf.find_by( { "_id" =>  params[:id] } )
          puts 'VNF is found'
        rescue Mongoid::Errors::DocumentNotFound => e
          json_error 404, "This VNFD does not exists"
        end

        #Validate new status
        valid_status = ['active', 'inactive', 'delete']
        if valid_status.include? keyed_params[:status]
          # Update to new status
          begin
            vnf.update_attributes(:status => params[:new_status])
          rescue Moped::Errors::OperationFailure => e
            json_error 400, "ERROR: Operation failed"
          end
        else
          json_error 400, "Invalid new status #{keyed_params[:status]}"
        end

        # --> Validation disabled
        # Validate VNFD
        #begin
        #	RestClient.post settings.nsd_validator + '/nsds', nsd.to_json, :content_type => :json
        #rescue => e
        #	logger.error e.response
        #	return e.response.code, e.response.body
        #end

        halt 200, "Status updated to #{uri.query_values}"

      else
        # Compatibility support for YAML content-type
        case request.content_type
          when 'application/x-yaml'
            # Validate YAML format
            # When updating a VNFD, the json object sent to API must contain just data inside
            # of the vnfd, without the json field vnfd: before
            vnf, errors = parse_yaml(request.body.read)
            halt 400, errors.to_json if errors

            # Translate from YAML format to JSON format
            new_vnf_json = yaml_to_json(vnf)

            # Validate JSON format
            new_vnf, errors = parse_json(new_vnf_json)
            puts 'vnf: ', new_ns.to_json
            #puts 'new_vnf id', new_vnf['_id'].to_json
            halt 400, errors.to_json if errors

          else
            # Compatibility support for JSON content-type
            # Parses and validates JSON format
            new_vnf, errors = parse_json(request.body.read)
            halt 400, errors.to_json if errors
        end

        # Validate VNF
        # Check if same vendor, Name, Version do already exists in the database
        json_error 400, "ERROR: VNF Vendor not found" unless new_vnf.has_key?('vendor')
        json_error 400, "ERROR: VNF Name not found" unless new_vnf.has_key?('name')
        json_error 400, "ERROR: VNF Version not found" unless new_vnf.has_key?('version')

        # Retrieve stored version
        begin
          puts 'Searching ' + params[:id].to_s
          vnf = Vnf.find_by( { "_id" =>  params[:id] })
          puts 'VNF is found'
        rescue Mongoid::Errors::DocumentNotFound => e
          json_error 404, "The VNFD ID #{params[:id]} does not exist"
        end

        # Check if VNF already exists in the catalogue by name, vendor and version
        begin
          vnf = Vnf.find_by({"name" =>  new_vnf['name'], "vendor" => new_vnf['vendor'], "version" => new_vnf['version']})
          json_error 400, "ERROR: Duplicated VNF Name, Vendor and Version"
        rescue Mongoid::Errors::DocumentNotFound => e
        end

        # Update to new version
        puts 'Updating...'
        new_vnf['_id'] = SecureRandom.uuid
        vnfd = new_vnf

        # --> Validation disabled
        # Validate VNFD
        #begin
        #	RestClient.post settings.nsd_validator + '/nsds', nsd.to_json, :content_type => :json
        #rescue => e
        #	logger.error e.response
        #	return e.response.code, e.response.body
        #end

        begin
          new_vnf = Vnf.create!(vnfd)
        rescue Moped::Errors::OperationFailure => e
          json_error 400, "ERROR: Duplicated VNF ID" if e.message.include? 'E11000'
        end
        logger.debug "Catalogue: leaving PUT /vnfs/#{params[:id]}\" with VNFD #{new_vnf}"

        case request.content_type
          when 'application/json'
            response = new_vnf.to_json
          when 'application/x-yaml'
            response = json_to_yaml(new_vnf.to_json)
          else
            halt 415
        end
        halt 200, response
      end
    end
    logger.debug "Catalogue: leaving PUT /vnfs/#{params[:id]} with 'No VNF ID specified'"
    json_error 400, "No VNF ID specified"
  end

  # @method delete_vnfd_sp_vnf
  # @overload delete '/vnfs/?'
  #	Delete a VNF by vendor, name and version
  delete '/vnfs/?' do
    uri = Addressable::URI.new
    uri.query_values = params
    puts 'params', params
    puts 'query_values', uri.query_values
    logger.info "Catalogue: entered DELETE /vnfs?#{uri.query}"

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)
    puts 'keyed_params', keyed_params

    unless keyed_params[:vendor].nil? && keyed_params[:name].nil? && keyed_params[:version].nil?
      begin
        vnf = Vnf.find_by({"vendor" => keyed_params[:vendor], "name" =>  keyed_params[:name], "version" => keyed_params[:version]})
        puts 'VNF is found'
      rescue Mongoid::Errors::DocumentNotFound => e
        json_error 404, "The VNFD Vendor #{keyed_params[:vendor]}, Name #{keyed_params[:name]}, Version #{keyed_params[:version]} does not exist"
      end
      logger.debug "Catalogue: leaving DELETE /vnfs?#{uri.query}\" with NSD #{vnf}"
      vnf.destroy
      halt 200, "OK: VNFD removed"
    end
    logger.debug "Catalogue: leaving DELETE /vnfs?#{uri.query} with 'No VNFD Vendor, Name, Version specified'"
    json_error 400, "No VNFD Vendor, Name, Version specified"
  end

	# @method delete_vnfd_sp_vnf_id
	# @overload delete '/catalogues/vnfs/:id/?'
	#	Delete a VNF by its ID
	#	@param [uuid] id VNF ID
	# Delete a VNF by uuid
	delete '/vnfs/:id/?' do
    unless params[:id].nil?
      logger.debug "Catalogue: DELETE /vnfs/#{params[:id]}"
      begin
        vnf = Vnf.find(params[:id] )
      rescue Mongoid::Errors::DocumentNotFound => e
        logger.error e
        json_error 404, "The VNFD ID #{params[:id]} does not exist" unless vnf
      end
      logger.debug "Catalogue: leaving DELETE /vnfs/#{params[:id]}\" with NSD #{vnf}"
      vnf.destroy
      halt 200, 'OK: VNFD removed'
    end
    logger.debug "Catalogue: leaving DELETE /vnfs/#{params[:id]} with 'No VNFD ID specified'"
    json_error 400, "No VNFD ID specified"
	end


	############################################ PD API METHODS ############################################

	# @method get_packages
	# @overload get '/catalogues/packages'
	#	Returns a list of all Packages
	# List all Packages in JSON or YAML format
	get '/packages' do
		params[:offset] ||= 1
		params[:limit] ||= 50

		# Only accept positive numbers
		params[:offset] = 1 if params[:offset].to_i < 1
		params[:limit] = 2 if params[:limit].to_i < 1

		# Get paginated list
		pks = Package.paginate(:page => params[:offset], :limit => params[:limit])
		logger.debug(pks)

		# Build HTTP Link Header
		#headers['Link'] = build_http_link_packs(params[:offset].to_i, params[:limit])

		begin
			pks_json = pks.to_json # to remove _id field from documents (:except => :_id)
			#puts 'NSS: ', nss_json
			if request.content_type == 'application/json'
				return 200, pks_json
			elsif request.content_type == 'application/x-yaml'
				pks_yml = json_to_yaml(pks_json)
				return 200, pks_yml
			end
		rescue
			logger.error "Error Establishing a Database Connection"
			return 500, "Error Establishing a Database Connection"
		end
	end

	# @method get_packages_package_id
	# @overload get '/catalogues//packages/id/:id'
	#	Return one (or zero) Package by ID in JSON or YAML format
	#	@param [String] package_group Package id
	# Show a Package group
	get '/packages/id/:id' do
		begin
			pks = Package.find(params[:id] )
		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end

		pks_json = pks.to_json
		if request.content_type == 'application/json'
			return 200, pks_json
		elsif request.content_type == 'application/x-yaml'
			pks_yml = json_to_yaml(pks_json)
			return 200, pks_yml
		end
		#return 200, ns.nsd.to_json
	end

	# @method get_packages_package_group
	# @overload get '/catalogues/packages/vendor/:package_group'
	#	Returns an array of all packages by vendor in JSON or YAML format
	#	@param [String] package_group Package vendor
	# Show a Package group
	get '/packages/vendor/:package_group' do # '/catalogues/packages?vendor=:package_group'
		begin
			pks = Package.where({"package_group" => params[:package_group]})
			puts 'Package: ', pks.size.to_s

			if pks.size.to_i == 0
				logger.error "ERROR: PD not found"
				return 404
			end

		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end
		pks_json = pks.to_json
		if request.content_type == 'application/json'
			return 200, pks_json
		elsif request.content_type == 'application/x-yaml'
			pks_yml = json_to_yaml(pks_json)
			return 200, pks_yml
		end
	end

	# @method get_packages_package_group.name
	# @overload get '/catalogues/packages/vendor/:package_group/name/:package_name'
	#	Returns an array of all packages by group and name in JSON or YAML format
	#	@param [String] package_group Package vendor
	# Show a Package group
	#	@param [String] package_name Package Name
	# Show a Package name
	get '/packages/vendor/:package_group/name/:package_name' do # '/catalogues/packages?vendor=:package_group&name=:package_name'
		begin
			pks = Package.where({"package_group" =>  params[:package_group], "package_name" => params[:package_name]})

			if pks.size.to_i == 0
				logger.error "ERROR: PD not found"
				return 404
			end

		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end

		pks_json = pks.to_json
		if request.content_type == 'application/json'
			return 200, pks_json
		elsif request.content_type == 'application/x-yaml'
			pks_yml = json_to_yaml(pks_json)
			return 200, pks_yml
		end
	end

	# @method get_packages_package_group.name.version
	# @overload get '/catalogues/packages/vendor/:package_group/name/:package_name/version/:package_version'
	#	Return one (or zero) Package by vendor, name, version in JSON or YAML format
	#	@param [String] package_group Package vendor
	# Show a Package group
	#	@param [String] package_name Package Name
	# Show a Package name
	#	@param [Integer] package_version Package version
	# Show a Package version
	get '/packages/vendor/:package_group/name/:package_name/version/:package_version' do
		begin
			pks = Package.find_by({"package_group" =>  params[:package_group], "package_name" =>  params[:package_name], "package_version" => params[:package_version]})
		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end

		pks_json = pks.to_json
		if request.content_type == 'application/json'
			return 200, pks_json
		elsif request.content_type == 'application/x-yaml'
			pks_yml = json_to_yaml(pks_json)
			return 200, pks_yml
		end
	end

	# @method get_packages_package_vendor_last_version
	# @overload get '/catalogues/packages/vendor/:package_group/last'
	#	Show a Package Vendor list for last version in JSON or YAML format
	#	@param [String] package_vendor Package Vendor
	# Show a Package vendor
	get '/packages/vendor/:package_group/last' do  # '/catalogues/packages?vendor=:package_group&last'
  #get '/catalogues/packages?vendor=:package_group/last' do
    # Search and get all package items by vendor
		begin
			#puts 'params', params

			pks = Package.where({"package_group" => params[:package_group]}).sort({"package_version" => -1})#.limit(1).first()

			if pks.size.to_i == 0
				logger.error "ERROR: PD not found"
				return 404

			elsif pks == nil
				logger.error "ERROR: PD not found"
				return 404

      else
				pks_list = []
        name_list = []
        pk_name = pks.first.package_name
        name_list.push(pk_name)
        pks_list.push(pks.first)
				pks.each do |pd|
				  #if pd.package_name == pk_name #and pd.package_version == last_version
          #  pks_list.push(pd)
          #  pks.shift
          if pd.package_name != pk_name
            pk_name = pd.package_name
            pks_list.push(pd) unless name_list.include?(pk_name)
          end
        end
      end

		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end

		pks_json = pks_list.to_json
		puts 'Packages: ', pks_json

		if request.content_type == 'application/json'
			return 200, pks_json
		elsif request.content_type == 'application/x-yaml'
			pks_yml = json_to_yaml(pks_json)
			return 200, pks_yml
		end
	end

	# @method get_packages_package_name
	# @overload get '/catalogues/packages/name/:name'
	#	Show a Package or Package list in JSON or YAML format
	#	@param [String] package_name NS Name
	# Show a Package by name
	get '/packages/name/:package_name' do
		begin
			#ns = Ns.distinct( "nsd.version" )#.where({ "nsd.name" =>  params[:external_ns_name]})
			pks = Package.where({"package_name" => params[:package_name]})
			puts 'Package: ', pks.size.to_s

			if pks.size.to_i == 0
				logger.error "ERROR: NSD not found"
				return 404
			end

		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end
		pks_json = pks.to_json
		if request.content_type == 'application/json'
			return 200, pks_json
		elsif request.content_type == 'application/x-yaml'
			pks_yml = json_to_yaml(pks_json)
			return 200, pks_yml
		end
	end

	# @method get_packages_package_name_version
	# @overload get '/catalogues/packages/name/:name/version/:version'
	#	Show a Package list in JSON or YAML format
	#	@param [String] package_name Package Name
	# Show a Package name
	#	@param [Integer] package_version Package version
	# Show a Package version
	get '/packages/name/:name/version/:version' do
		begin
			pks = Package.where({"package_name" =>  params[:name], "package_version" => params[:version]})

			if pks.size.to_i == 0
				logger.error "ERROR: PD not found"
				return 404
			end

		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end

		pks_json = pks.to_json
		if request.content_type == 'application/json'
			return 200, pks_json
		elsif request.content_type == 'application/x-yaml'
			pks_yml = json_to_yaml(pks_json)
			return 200, pks_yml
		end
	end

	# @method get_packages_package_name_last_version
	# @overload get '/catalogues/packages/name/:name/last'
	#	Show a Package list for last version in JSON or YAML format
	#	@param [String] package_name Package Name
	# Show a Package name
	get '/packages/name/:name/last' do
		# Search and get all package items by name
		begin
			#puts 'params', params

			pks = Package.where({"package_name" => params[:name]}).sort({"package_version" => -1})#.limit(1).first()

			if pks.size.to_i == 0
				logger.error "ERROR: PD not found"
				return 404

			elsif pks == nil
				logger.error "ERROR: PD not found"
				return 404

      else
        pks_list = []
        vendor_list = []
        pk_vendor = pks.first.package_group
        vendor_list.push(pk_vendor)
        pks_list.push(pks.first)
        pks.each do |pd|
          if pd.package_group != pk_vendor
            pk_vendor = pd.package_group
            pks_list.push(pd) unless vendor_list.include?(pk_vendor)
          end
        end
      end

		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end

		pks_json = pks_list.to_json
		puts 'Packages: ', pks_json

		if request.content_type == 'application/json'
			return 200, pks_json
		elsif request.content_type == 'application/x-yaml'
			pks_yml = json_to_yaml(pks_json)
			return 200, pks_yml
		end
	end

	# @method post_package
	# @overload post '/catalogues/packages'
	# 	Post a Package in JSON or YAML format
	# 	@param [YAML] Package in YAML format
	# Post a Package
	# 	@param [JSON] Package in JSON format
	# Post a Package
	post '/packages' do
		#A bit more work as it needs to parse the package descriptor to get GROUP, NAME, and VERSION.
		# Return if content-type is invalid
		return 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

		# Compatibility support for YAML content-type
		if request.content_type == 'application/x-yaml'

			# Validate YAML format
			pks, errors = parse_yaml(request.body.read)

			return 400, errors.to_json if errors

			# Translate from YAML format to JSON format
			pks_json = yaml_to_json(pks)

			# Validate JSON format
			pks, errors = parse_json(pks_json)
			#puts 'PD: ', pks.to_json
			return 400, errors.to_json if errors

			# Compatibility support for JSON content-type
		elsif request.content_type == 'application/json'
			# Parses and validates JSON format
			pks, errors = parse_json(request.body.read)
			return 400, errors.to_json if errors
		end

		return 400, 'ERROR: Package Name not found' unless pks.has_key?('package_name')
		return 400, 'ERROR: Package Vendor not found' unless pks.has_key?('package_group')
		return 400, 'ERROR: Package Version not found' unless pks.has_key?('package_version')

		# --> Validation disabled
		# Validate PD
		#begin
		#	RestClient.post settings.pd_validator + '/pds', pks.to_json, :content_type => :json
		#rescue => e
		#	halt 500, {'Content-Type' => 'text/plain'}, "Validator mS unrechable."
		#end

		# Check if package already exists in the catalogue by name, vendor and version
		begin
			pks = Package.find_by({"package_name" =>  pks['package_name'], "package_vendor" => pks['package_vendor'], "package_version" => pks['package_version']})
			return 400, 'ERROR: Duplicated PD Name, Vendor and Version'
		rescue Mongoid::Errors::DocumentNotFound => e
		end
		# Check if PD has an ID (it should not) and if it already exists in the catalogue
		begin
			pks = Package.find_by({"_id" =>  pks['_id']})
			return 400, 'ERROR: Duplicated PD ID'
		rescue Mongoid::Errors::DocumentNotFound => e
		end

		# Save to DB
		begin
			# Generate the UUID for the descriptor
			pks['_id'] = SecureRandom.uuid
			new_pks = Package.create!(pks)
		rescue Moped::Errors::OperationFailure => e
			return 400, 'ERROR: Duplicated PD ID' if e.message.include? 'E11000'
		end

		puts 'New PD has been added'
    case request.content_type
      when 'application/json'
        response = new_pks.to_json
      when 'application/x-yaml'
        response = json_to_yaml(new_pks.to_json)
      else
        halt 415
    end
    halt 201, response

		#pks_json = new_pks['_id'].to_json
		#if request.content_type == 'application/json'
		#	return 200, pks_json
		#elsif request.content_type == 'application/x-yaml'
		#	pks_yml = json_to_yaml(pks_json)
		#	return 200, pks_yml
		#end
	end

	# @method update_package_group_name_version
	# @overload put '/catalogues/packages/vendor/:package_group/name/:package_name/version/:package_version
	#	Update a Package by group, name and version in JSON or YAML format
	#	@param [String] package_group Package vendor
	# Update a Package group
	#	@param [String] package_name Package Name
	# Update a Package name
	#	@param [Integer] package_version Package version
	# Update a Package version
	put '/packages/vendor/:package_group/name/:package_name/version/:package_version' do
		# Return if content-type is invalid
		return 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

		# Compatibility support for YAML content-type
		if request.content_type == 'application/x-yaml'
			# Validate YAML format
			pks, errors = parse_yaml(request.body.read)
			return 400, errors.to_json if errors

			# Translate from YAML format to JSON format
			new_pks_json = yaml_to_json(pks)

			# Validate JSON format
			new_pks, errors = parse_json(new_pks_json)
			puts 'pks: ', new_pks.to_json
			puts 'new_pks id', new_pks['_id'].to_json
			return 400, errors.to_json if errors

			# Compatibility support for JSON content-type
		elsif request.content_type == 'application/json'
			# Parses and validates JSON format
			new_pks, errors = parse_json(request.body.read)
			return 400, errors.to_json if errors
		end

		# Validate NS
		# TODO: Check if same vendor, Name, Version do already exists in the database
		return 400, 'ERROR: PD Vendor not found' unless new_pks.has_key?('package_group')
		return 400, 'ERROR: PD Name not found' unless new_pks.has_key?('package_name')
		return 400, 'ERROR: PD Version not found' unless new_pks.has_key?('package_version')

		# Retrieve stored version
		begin
			puts 'Searching ' + params[:id].to_s

			pks = Package.find_by({"package_name" =>  params[:package_name], "package_vendor" => params[:package_vendor], "package_version" => params[:package_version]})
			#puts 'PD is found'

		rescue Mongoid::Errors::DocumentNotFound => e
			return 400, 'This PD does not exists'
		end
		# Check if PD already exists in the catalogue by name, vendor and version
		begin
			pks = Package.find_by({"package_name" =>  new_pks['package_name'], "package_vendor" => new_pks['package_vendor'], "package_version" => new_pks['package_version']})
			return 400, 'ERROR: Duplicated Package Name, Vendor and Version'
		rescue Mongoid::Errors::DocumentNotFound => e
		end

		# Update to new version
		pks = {}
		prng = Random.new
		puts 'Updating...'

		new_pks['_id'] = SecureRandom.uuid
		pks = new_pks # Avoid having multiple PD fields containers

		# --> Validation disabled
		# Validate PD
		#begin
		#	RestClient.post settings.pd_validator + '/pds', pd.to_json, :content_type => :json
		#rescue => e
		#	logger.error e.response
		#	return e.response.code, e.response.body
		#end

		begin
			new_pks = Package.create!(pks)
		rescue Moped::Errors::OperationFailure => e
			return 400, 'ERROR: Duplicated Package ID' if e.message.include? 'E11000'
		end

		pks_json = new_pks['_id'].to_json
		if request.content_type == 'application/json'
			return 200, pks_json

		elsif request.content_type == 'application/x-yaml'
			pks_yml = json_to_yaml(pks_json)
			return 200, pks_yml
		end
	end

	# @method update_package_id
	# @overload put '/catalogues/packages/vendor/:package_group/name/:package_name/version/:package_version
	#	Update a Package by group, name and version in JSON or YAML format
	#	@param [String] id PD ID
	# Update a PD by ID
	put '/packages/id/:id' do
		# Return if content-type is invalid
		return 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

		# Compatibility support for YAML content-type
		if request.content_type == 'application/x-yaml'
			# Validate YAML format
			pks, errors = parse_yaml(request.body.read)
			return 400, errors.to_json if errors

			# Translate from YAML format to JSON format
			new_pks_json = yaml_to_json(pks)

			# Validate JSON format
			new_pks, errors = parse_json(new_pks_json)
			puts 'pks: ', new_pks.to_json
			puts 'new_pks id', new_pks['_id'].to_json
			return 400, errors.to_json if errors

			# Compatibility support for JSON content-type
		elsif request.content_type == 'application/json'
			# Parses and validates JSON format
			new_pks, errors = parse_json(request.body.read)
			return 400, errors.to_json if errors
		end

		# Validate NS
		# TODO: Check if same vendor, Name, Version do already exists in the database
		return 400, 'ERROR: PD Vendor not found' unless new_pks.has_key?('package_group')
		return 400, 'ERROR: PD Name not found' unless new_pks.has_key?('package_name')
		return 400, 'ERROR: PD Version not found' unless new_pks.has_key?('package_version')

		# Retrieve stored version
		begin
			puts 'Searching ' + params[:id].to_s

			pks = Package.find_by({"_id" =>  params[:id]})
				#puts 'PD is found'

		rescue Mongoid::Errors::DocumentNotFound => e
			return 400, 'This PD does not exists'
		end
		# Check if PD already exists in the catalogue by name, vendor and version
		begin
			pks = Package.find_by({"package_name" =>  new_pks['package_name'], "package_vendor" => new_pks['package_vendor'], "package_version" => new_pks['package_version']})
			return 400, 'ERROR: Duplicated Package Name, Vendor and Version'
		rescue Mongoid::Errors::DocumentNotFound => e
		end

		# Update to new version
		pks = {}
		prng = Random.new
		puts 'Updating...'

		new_pks['_id'] = SecureRandom.uuid
		pks = new_pks # Avoid having multiple PD fields containers

		# --> Validation disabled
		# Validate PD
		#begin
		#	RestClient.post settings.pd_validator + '/pds', pd.to_json, :content_type => :json
		#rescue => e
		#	logger.error e.response
		#	return e.response.code, e.response.body
		#end

		begin
			new_pks = Package.create!(pks)
		rescue Moped::Errors::OperationFailure => e
			return 400, 'ERROR: Duplicated Package ID' if e.message.include? 'E11000'
		end

		pks_json = new_pks['_id'].to_json
		if request.content_type == 'application/json'
			return 200, pks_json

		elsif request.content_type == 'application/x-yaml'
			pks_yml = json_to_yaml(pks_json)
			return 200, pks_yml
		end
	end

	# @method delete_pd_package_group_name_version
	# @overload delete '/catalogues/packages/vendor/:package_group/name/:package_name/version/:package_version'
	#	Delete a PD by group, name and version in JSON or YAML format
	#	@param [String] package_group Package vendor
	# Delete a Package by group
	#	@param [String] package_name Package Name
	# Delete a Package by name
	#	@param [Integer] package_version Package version
	# Delete a Package by version
	delete '/packages/vendor/:package_group/name/:package_name/version/:package_version' do
		begin
			pks = Package.find_by({"package_name" =>  params[:package_name], "package_vendor" => params[:package_vendor], "package_version" => params[:package_version]})
		rescue Mongoid::Errors::DocumentNotFound => e
			return 404,'ERROR: Operation failed'
		end
		pks.destroy
		return 200, 'OK: PD removed'
	end

	# @method delete_pd_package_id
	# @overload delete '/catalogues/packages/vendor/:package_group/name/:package_name/version/:package_version'
	#	Delete a PD by its ID
	#	@param [String] id PD ID
	# Delete a PD
	delete '/packages/id/:id' do
		begin
			pks = Package.find(params[:id] )
		rescue Mongoid::Errors::DocumentNotFound => e
			return 404,'ERROR: Operation failed'
		end
		pks.destroy
		return 200, 'OK: PD removed'
	end


  ############################################ PZIP API METHODS ############################################

  # @method post_zip_package
  # @overload post '/catalogues/zip-package'
  # 	Post a Package zip in binary-data
  post '/zip-packages' do
    # Return if content-type is invalid
    return 415 unless request.content_type == 'application/zip'

    # Reads body data
    file, errors = request.body
    return 400, errors.to_json if errors

    #Zip::Archive.open_buffer(response.body) do |ar|
    #  ar.fopen(0) do |zf|
    #    open(zf.name, 'wb') do |f|
    #      f << zf.read
    #    end
    #  end
    #end

    #return 400, 'ERROR: Package Name not found' unless pzip.has_key?('package_name')
    #return 400, 'ERROR: Package Vendor not found' unless pzip.has_key?('package_group')
    #return 400, 'ERROR: Package Version not found' unless pzip.has_key?('package_version')

    #file = File.open('/home/osboxes/sonata/son-catalogue-repos/samples/package_example.zip')

    grid_fs   = Mongoid::GridFs
    grid_file = grid_fs.put(file,
                            #:filename     => "package.zip",
                            :content_type => "application/zip",
                            #:_id          => 'a-unique-id-to-use-in-lieu-of-a-random-one',
                            #:chunk_size   => 100 * 1024,
                            #:metadata     => {'description' => "taken after a game of ultimate"}
                            )

    FileContainer.new.tap do |file_container|
      file_container.grid_fs_id = grid_file.id
      file_container.save
    end

    halt 201, grid_file.id.to_json
  end

  # @method get_package_zip_pzip_id
  # @overload get '/catalogues/zip-packages/id/:pzip_id'
  #	Get a zip-package
  #	@param [Integer] zip-package ID
  # Zip-package internal database identifier
  get '/zip-packages/id/:id' do
    puts 'ID: ', params[:id]
    begin
      FileContainer.find_by({"grid_fs_id" => params[:id]} )
      puts 'FileContainer FOUND'
    rescue Mongoid::Errors::DocumentNotFound => e
      logger.error e
      return 404
    end

    grid_fs   = Mongoid::GridFs
    grid_file = grid_fs.get(params[:id])
    #grid_file.data # big huge blob

    #temp=Tempfile.new('package.zip', 'wb')
    #grid_file.each do |chunk|
    #  temp.write(chunk) # streaming write
    #end

    return 200, grid_file.data

  end

end