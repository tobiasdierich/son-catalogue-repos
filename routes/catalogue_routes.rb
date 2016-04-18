# @see SonCatalogue
class SonataCatalogue < Sinatra::Application

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

	# @method get_log
	# @overload get '/network-services/log'
	#	Returns contents of log file
	# Management method to get log file of catalogue remotely
	#get '/log' do
  #  	headers "Content-Type" => "text/plain; charset=utf8"
	#	filename = 'log/development.log'
  #
	#	# For testing purposes only
	#	begin
	#		txt = open(filename)
	#
	#	rescue => err
	#		logger.error "Error reading log file: #{err}"
	#		return 500, "Error reading log file: #{err}"
	#	end
	#
	#	#return 200, nss.to_json
	#	return 200, txt.read.to_s
	#end

=begin
    GET /catalogues/network-services
    GET /catalogues/network-services/id/{_id}
    GET /catalogues/network-services/vendor/{vendor}
    GET /catalogues/network-services/vendor/{vendor}/name/{name}
    GET /catalogues/network-services/vendor/{vendor}/name/{name}/version/{version}
    GET /catalogues/network-services/vendor/{vendor}/last}
    GET /catalogues/network-services/name/{name}
    GET /catalogues/network-services/name/{name}/version/{version}
    GET /catalogues/network-services/name/{name}/last
    POST /catalogues/network-services
    PUT /catalogues/network-services/vendor/{vendor}/name/{name}/version/{version}
    PUT /catalogues/network-services/id/{_id}
    DELETE /catalogues/network-services/vendor/{vendor}/name/{name}/version/{version}
    DELETE /catalogues/network-services/id/{_id}

    GET /catalogues/vnfs
    GET /catalogues/vnfs/id/{_id}
    GET /catalogues/vnfs/vendor/{vendor}
    GET /catalogues/vnfs/vendor/{vendor}/name/{name}
    GET /catalogues/vnfs/vendor/{vendor}/name/{name}/version/{version}
    GET /catalogues/vnfs/vendor/{vendor}/last}
    GET /catalogues/vnfs/name/{name}
    GET /catalogues/vnfs/name/{name}/version/{version}
    GET /catalogues/vnfs/name/{name}/last
    POST /catalogues/vnfs
    PUT /catalogues/vnfs/vendor/{vendor}/name/{name}/version/{version}
    PUT /catalogues/vnfs/id/{_id}
    DELETE /catalogues/vnfs/vendor/{vendor}/name/{name}/version/{version}
    DELETE /catalogues/vnfs/id/{_id}

    GET /catalogues/packages
    GET /catalogues/packages/id/{_id}
    GET /catalogues/packages/vendor/{package_group}
    GET /catalogues/packages/vendor/{package_group}/name/{package_name}
    GET /catalogues/packages/vendor/{package_group}/name/{package_name}/version/{package_version}
    GET /catalogues/packages/vendor/{package_group}/last}
    GET /catalogues/packages/name/{package_name}
    GET /catalogues/packages/name/{package_name}/version/{package_version}
    GET /catalogues/packages/name/{package_name}/last
    POST /catalogues/packages
    PUT /catalogues/packages/vendor/{package_group}/name/{package_name}/version/{package_version}
    PUT /catalogues/packages/id/{_id}
    DELETE /catalogues/packages/vendor/{package_group}/name/{package_name}/version/{package_version}
    DELETE /catalogues/packages/id/{_id}
=end

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
	# @overload get '/catalogues/network-services'
	#	Returns a list of NSs
	# -> List all NSs in JSON or YAML format
	get '/network-services' do
		params[:offset] ||= 1
		params[:limit] ||= 50

		# Only accept positive numbers
		params[:offset] = 1 if params[:offset].to_i < 1
		params[:limit] = 2 if params[:limit].to_i < 1

		# Get paginated list
		nss = Ns.paginate(:page => params[:offset], :limit => params[:limit])
		logger.debug(nss)

		# Build HTTP Link Header
		headers['Link'] = build_http_link_ns(params[:offset].to_i, params[:limit])

		begin
			nss_json = nss.to_json # to remove _id field from documents (:except => :_id)
			#puts 'NSS: ', nss_json
			if request.content_type == 'application/json'
				return 200, nss_json
			elsif request.content_type == 'application/x-yaml'
				nss_yml = json_to_yaml(nss_json)
				return 200, nss_yml
			end
		rescue
			logger.error "Error Establishing a Database Connection"
			return 500, "Error Establishing a Database Connection"
		end
	end


	# @method get_ns_sp_ns_id
	# @overload get '/catalogues/network-services/id/:sp_ns_id'
	#	Show a NS in JSON or YAML format
	#	@param [Integer] sp_ns_id NS sp ID
	# Show a NS by internal ID (uuid)
	get '/network-services/id/:id' do
		begin
			ns = Ns.find(params[:id] )
			#ns = Ns.find_by( { "nsd.id" =>  params[:external_ns_id]})
		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end

		ns_json = ns.to_json
		#puts 'NSS: ', nss_json
		if request.content_type == 'application/json'
			return 200, ns_json
		elsif request.content_type == 'application/x-yaml'
			ns_yml = json_to_yaml(ns_json)
			return 200, ns_yml
		end
		#return 200, ns.nsd.to_json
	end

  # @method get_ns_sp_vendor
  # @overload get '/catalogues/network-services/vendor/:vendor'
  #	Returns an array of all NS by vendor in JSON or YAML format
  #	@param [String] ns_vendor NS vendor
  # Show a NS vendor
  get '/network-services/vendor/:vendor' do
    begin
      ns = Ns.where({"vendor" => params[:vendor]})
      puts 'NS: ', ns.size.to_s

      if ns.size.to_i == 0
        logger.error "ERROR: NSD not found"
        return 404
      end

    rescue Mongoid::Errors::DocumentNotFound => e
      logger.error e
      return 404
    end
    ns_json = ns.to_json
    if request.content_type == 'application/json'
      return 200, ns_json
    elsif request.content_type == 'application/x-yaml'
      ns_yml = json_to_yaml(ns_json)
      return 200, ns_yml
    end
  end

  # @method get_Nss_NS_vendor.name
  # @overload get '/catalogues/network-services/vendor/:vendor/name/:name'
  #	Returns an array of all NS by vendor and name in JSON or YAML format
  #	@param [String] ns_group NS vendor
  # Show a NS vendor
  #	@param [String] ns_name NS Name
  # Show a NS name
  get '/network-services/vendor/:vendor/name/:name' do
    begin
      ns = Ns.where({"vendor" =>  params[:vendor], "name" => params[:name]})

      if ns.size.to_i == 0
        logger.error "ERROR: NSD not found"
        return 404
      end

    rescue Mongoid::Errors::DocumentNotFound => e
      logger.error e
      return 404
    end

    ns_json = ns.to_json
    if request.content_type == 'application/json'
      return 200, ns_json
    elsif request.content_type == 'application/x-yaml'
      ns_yml = json_to_yaml(ns_json)
      return 200, ns_yml
    end
  end

  # @method get_nsd_ns_vendor.name.version
  # @overload get '/network-services/vendor/:vendor/name/:name/version/:version'
  #	Show a specific NS in JSON or YAML format
  #	@param [String] vendor NS external Vendor
  # Show a NS vendor
  #	@param [String] name NS external Name
  # Show a NS name
  #	@param [Integer] version NS version
  # Show a NS version
  get '/network-services/vendor/:vendor/name/:name/version/:version' do
    begin
      ns = Ns.find_by({"vendor" =>  params[:vendor], "name" =>  params[:name], "version" => params[:version]})
    rescue Mongoid::Errors::DocumentNotFound => e
      logger.error e
      return 404
    end

    ns_json = ns.to_json
    if request.content_type == 'application/json'
      return 200, ns_json
    elsif request.content_type == 'application/x-yaml'
      ns_yml = json_to_yaml(ns_json)
      return 200, ns_yml
    end
    #return 200, ns.nsd.to_json
  end

  # @method get_nsd_ns_vendor_last_version
  # @overload get '/catalogues/network-services/vendor/:vendor/last'
  #	Show a NS Vendor list for last version in JSON or YAML format
  #	@param [String] vendor NS Vendor
  # Show a NS vendor
  get '/network-services/vendor/:vendor/last' do
    # Search and get all NS items by vendor
    begin

      ns = Ns.where({"vendor" => params[:vendor]}).sort({"version" => -1})#.limit(1).first()

      if ns.size.to_i == 0
        logger.error "ERROR: NSD not found"
        return 404

      elsif ns == nil
        logger.error "ERROR: NSD not found"
        return 404

      else
        ns_list = []
        name_list = []
        ns_name = ns.first.name
        name_list.push(ns_name)
        ns_list.push(ns.first)
        ns.each do |nsd|

          if nsd.name != ns_name
            ns_name = nsd.name
            ns_list.push(nsd) unless name_list.include?(ns_name)
          end
        end
      end

    rescue Mongoid::Errors::DocumentNotFound => e
      logger.error e
      return 404
    end

    ns_json = ns_list.to_json
    puts 'NSs: ', ns_json

    if request.content_type == 'application/json'
      return 200, ns_json
    elsif request.content_type == 'application/x-yaml'
      ns_yml = json_to_yaml(ns_json)
      return 200, ns_yml
    end
  end

	# @method get_nss_ns_name
	# @overload get '/catalogues/network-services/:ns_name'
	#	Show a NS or NS list in JSON or YAML format
	#	@param [String] ns_name NS Name
	# Show a NS by name
	get '/network-services/name/:name' do

		begin
			ns = Ns.where({"name" => params[:name]})
			puts 'NS: ', ns.size.to_s

			if ns.size.to_i == 0
				logger.error "ERROR: NSD not found"
				return 404
			end

		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end
		ns_json = ns.to_json
		if request.content_type == 'application/json'
			return 200, ns_json
		elsif request.content_type == 'application/x-yaml'
			ns_yml = json_to_yaml(ns_json)
			return 200, ns_yml
		end
	end


	# @method get_nsd_sp_ns_version
	# @overload get '/catalogues/network-services/name/:ns_name/version/:version'
	#	Show a NS list in JSON or YAML format
	#	@param [String] ns_name NS Name
	# Show a NS name
	#	@param [Integer] ns_version NS version
	# Show a NS version
	get '/network-services/name/:name/version/:version' do
		begin
			ns = Ns.where({"name" =>  params[:name], "version" => params[:version]})

			if ns.size.to_i == 0
				logger.error "ERROR: NSD not found"
				return 404
			end

		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end

		ns_json = ns.to_json
		if request.content_type == 'application/json'
			return 200, ns_json
		elsif request.content_type == 'application/x-yaml'
			ns_yml = json_to_yaml(ns_json)
			return 200, ns_yml
		end
	end


	# @method get_nsd_ns_last_version
	# @overload get '/catalogues/network-services/name/:ns_name/last'
	#	Show a NS list for last version in JSON or YAML format
	#	@param [String] ns_name NS Name
	# Show a NS name
	get '/network-services/name/:name/last' do

		# Search and get all items of NS by name
		begin
			#puts 'params', params
			# Get paginated list
			#ns = CatalogueModels.paginate(:page => params[:offset], :limit => params[:limit])

			# Build HTTP Link Header
			#headers['Link'] = build_http_link_name(params[:offset].to_i, params[:limit], params[:external_ns_name])

			#ns = Ns.distinct( "nsd.version" )#.where({ "nsd.name" =>  params[:external_ns_name]})
			#ns = Ns.where({"nsd.name" => params[:external_ns_name]})
			ns = Ns.where({"name" => params[:name]}).sort({"version" => -1})#.limit(1).first()

			if ns.size.to_i == 0
				logger.error "ERROR: NSD not found"
				return 404

			elsif ns == nil
				logger.error "ERROR: NSD not found"
				return 404

			else
        ns_list = []
        vendor_list = []
        ns_vendor = ns.first.vendor
        vendor_list.push(ns_vendor)
        #puts 'first', ns.first.ns_version
        #last_version = ns.first.version
        #App.all.to_a
        ns_list.push(ns.first)
        ns.each do |nsd|
          if nsd.vendor != ns_vendor
            ns_vendor = nsd.vendor
            ns_list.push(nsd) unless vendor_list.include?(ns_vendor)
          end
				end
			end

		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end

		ns_json = ns_list.to_json
		puts 'NS: ', ns_json

		#if ns_json == 'null'
		#	logger.error "ERROR: NSD not found"
		#	return 404
		#end
		if request.content_type == 'application/json'
			return 200, ns_json
		elsif request.content_type == 'application/x-yaml'
			ns_yml = json_to_yaml(ns_json)
			return 200, ns_yml
		end

		#return 200, ns.to_json
	end

	# @method post_nss
	# @overload post '/catalogues/network-services'
	# Post a NS in in JSON or YAML format
	# @param [YAML] NS in YAML format
	# Post a NSD
	# @param [JSON] NS in JSON format
	# Post a NSD
	post '/network-services' do
		# Return if content-type is invalid
		return 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

		# Compatibility support for YAML content-type
		if request.content_type == 'application/x-yaml'

			# Validate YAML format
			ns, errors = parse_yaml(request.body.read)
			#ns, errors = parse_yaml(request.body)
			#puts 'NS :', ns.to_yaml
			#puts 'errors :', errors.to_s

			return 400, errors.to_json if errors

			# Translate from YAML format to JSON format
			#ns_yml = ns.nsd.to_json
			ns_json = yaml_to_json(ns)
			#ns_json = yaml_to_json(request.body.read)

			# Validate JSON format
			#ns, errors = parse_json(request.body.read)
			#ns, errors = parse_json(ns.to_json)
			ns, errors = parse_json(ns_json)
			puts 'ns: ', ns.to_json
			return 400, errors.to_json if errors

			# Compatibility support for JSON content-type
		elsif request.content_type == 'application/json'
			# Parses and validates JSON format
			ns, errors = parse_json(request.body.read)
			return 400, errors.to_json if errors
		end

		#logger.debug ns
		# Validate NS
		#return 400, 'ERROR: NS Name not found' unless ns.has_key?('name')
		#return 400, 'ERROR: NSD not found' unless ns.has_key?('nsd')

		return 400, 'ERROR: NS Name not found' unless ns.has_key?('name')
		return 400, 'ERROR: NS Vendor not found' unless ns.has_key?('vendor')
		return 400, 'ERROR: NS Version not found' unless ns.has_key?('version')

		# --> Validation disabled
		# Validate NSD
		#begin
		#	RestClient.post settings.nsd_validator + '/nsds', ns.to_json, :content_type => :json
		#rescue => e
		#	halt 500, {'Content-Type' => 'text/plain'}, "Validator mS unrechable."
		#end
		
		#vnfExists(ns['nsd']['vnfds'])
		# Check if NS already exists in the catalogue by name, vendor and version
		begin
			ns = Ns.find_by({"name" =>  ns['name'], "vendor" => ns['vendor'], "version" => ns['version']})
			return 400, 'ERROR: Duplicated NS Name, Vendor and Version'
		rescue Mongoid::Errors::DocumentNotFound => e
		end
		# Check if NSD has an ID (it should not) and if it already exists in the catalogue
		begin
			ns = Ns.find_by({"_id" =>  ns['_id']})
			return 400, 'ERROR: Duplicated NS ID'
		rescue Mongoid::Errors::DocumentNotFound => e
		end

		# Save to DB
		begin
			# Generate the UUID for the descriptor
			ns['_id'] = SecureRandom.uuid
			new_ns = Ns.create!(ns)
		rescue Moped::Errors::OperationFailure => e
			return 400, 'ERROR: Duplicated NS ID' if e.message.include? 'E11000'
		end

		puts 'New NS has been added'
		ns_json = new_ns['_id'].to_json
		if request.content_type == 'application/json'
			return 200, ns_json
			#return 200, new_ns['_id'].to_json

		elsif request.content_type == 'application/x-yaml'
			ns_yml = json_to_yaml(ns_json)
			return 200, ns_yml

		end
	end

  # @method update_nss_version_name_version
  # @overload put '/network-services/vendor/:vendor/name/:name/version/:version'
  # Update a NS by vendor, name and version in JSON or YAML format
  #	@param [String] NS_vendor NS vendor
  # Update a NS vendor
  #	@param [String] NS_name NS Name
  # Update a NS name
  #	@param [Integer] NS_version NS version
  # Update a NS version
  ## Catalogue - UPDATE
  put '/network-services/vendor/:vendor/name/:name/version/:version' do
    # Return if content-type is invalid
    return 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    # Compatibility support for YAML content-type
    if request.content_type == 'application/x-yaml'
      # Validate YAML format
      # When updating a NSD, the json object sent to API must contain just data inside
      # of the nsd, without the json field nsd: before <- this might be resolved
      ns, errors = parse_yaml(request.body.read)
      return 400, errors.to_json if errors

      # Translate from YAML format to JSON format
      new_ns_json = yaml_to_json(ns)

      # Validate JSON format
      new_ns, errors = parse_json(new_ns_json)
      puts 'ns: ', new_ns.to_json
      puts 'new_ns id', new_ns['_id'].to_json
      return 400, errors.to_json if errors

      # Compatibility support for JSON content-type
    elsif request.content_type == 'application/json'
      # Parses and validates JSON format
      new_ns, errors = parse_json(request.body.read)
      return 400, errors.to_json if errors
    end

    # Validate JSON format
    # When updating a NSD, the json object sent to API must contain just data inside
    # of the nsd, without the json field nsd: before <- this might be resolved
    #new_ns, errors = parse_json(request.body.read)
    #return 400, errors.to_json if errors

    # Validate NS
    # TODO: Check if same Group, Name, Version do already exists in the database
    #halt 400, 'ERROR: NSD not found' unless ns.has_key?('vnfd')
    return 400, 'ERROR: NS Vendor not found' unless new_ns.has_key?('vendor')
    return 400, 'ERROR: NS Name not found' unless new_ns.has_key?('name')
    return 400, 'ERROR: NS Version not found' unless new_ns.has_key?('version')

    # Retrieve stored version
    begin
      ns = Ns.find_by({"name" =>  params[:name], "vendor" => params[:vendor], "version" => params[:version]})
      puts 'NS is found'
    rescue Mongoid::Errors::DocumentNotFound => e
      return 400, 'This NSD does not exists'
    end
    # Check if NS already exists in the catalogue by name, group and version
    begin
      ns = Ns.find_by({"name" =>  new_ns['name'], "vendor" => new_ns['vendor'], "version" => new_ns['version']})
      return 400, 'ERROR: Duplicated NS Name, Vendor and Version'
    rescue Mongoid::Errors::DocumentNotFound => e
    end

    # Update to new version
    nsd = {}
    puts 'Updating...'
    new_ns['_id'] = new_ns['vendor'].to_s + '.' + new_ns['name'].to_s + '.' + new_ns['version'].to_s	# Unique IDs per NSD entries
    puts new_ns['_id'].to_s
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
      return 400, 'ERROR: Duplicated NS ID' if e.message.include? 'E11000'
    end

    ns_json = new_ns['_id'].to_json

    if request.content_type == 'application/json'
      return 200, ns_json

    elsif request.content_type == 'application/x-yaml'
      ns_yml = json_to_yaml(ns_json)
      return 200, ns_yml
    end
  end

	# @method update_nss
	# @overload put '/catalogues/network-services/id/:sp_ns_id'
	# Update a NS in JSON or YAML format
	# @param [YAML] NS in YAML format
	# Update a NS
	# @param [JSON] NS in JSON format
	# Update a NS
	## Catalogue - UPDATE
	put '/network-services/id/:id' do

		# Return if content-type is invalid
		return 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')
		#return 415 unless request.content_type == 'application/json'

		# Compatibility support for YAML content-type
		if request.content_type == 'application/x-yaml'
			# Validate YAML format
			# When updating a NSD, the json object sent to API must contain just data inside
			# of the nsd, without the json field nsd: before <- this might be resolved
			ns, errors = parse_yaml(request.body.read)
			return 400, errors.to_json if errors

			# Translate from YAML format to JSON format
			new_ns_json = yaml_to_json(ns)

			# Validate JSON format
			new_ns, errors = parse_json(new_ns_json)
			puts 'ns: ', new_ns.to_json
			puts 'new_ns id', new_ns['_id'].to_json
			return 400, errors.to_json if errors

			# Compatibility support for JSON content-type
		elsif request.content_type == 'application/json'
			# Parses and validates JSON format
			new_ns, errors = parse_json(request.body.read)
			return 400, errors.to_json if errors
		end

		# When updating a NSD, the json object sent to API must contain just data inside
		# of the nsd, without the json field nsd: before <- this might be resolved
		#new_ns, errors = parse_json(request.body.read)
		#return 400, errors.to_json if errors

		# Validate NS
		# TODO: Check if same vendor, Name, Version do already exists in the database
		#halt 400, 'ERROR: NSD not found' unless ns.has_key?('vnfd')
		return 400, 'ERROR: NS Vendor not found' unless new_ns.has_key?('vendor')
		return 400, 'ERROR: NS Name not found' unless new_ns.has_key?('name')
		return 400, 'ERROR: NS Version not found' unless new_ns.has_key?('version')

		# Retrieve stored version
		begin
			puts 'Searching ' + params[:id].to_s

			ns = Ns.find_by( { "_id" =>  params[:id] })

			puts 'NS is found'
		rescue Mongoid::Errors::DocumentNotFound => e
			return 400, 'This NSD does not exists'
		end
		# Check if NS already exists in the catalogue by name, vendor and version
		begin
			ns = Ns.find_by({"name" =>  new_ns['name'], "vendor" => new_ns['vendor'], "version" => new_ns['version']})
			return 400, 'ERROR: Duplicated NS Name, Vendor and Version'
		rescue Mongoid::Errors::DocumentNotFound => e
		end

		# Update to new version
		nsd = {}
		prng = Random.new
		puts 'Updating...'
		#puts 'new_ns', new_ns['id']
		#new_id = new_ns['id'].to_i + prng.rand(1000)
		#new_ns['id'] = new_id.to_s
		#new_ns['id'] = new_ns['id'].to_s + prng.rand(1000).to_s # Without unique IDs
		#new_ns['_id'] = new_ns['_id'].to_s + prng.rand(1000).to_s	# Unique IDs per NSD entries
		new_ns['_id'] = SecureRandom.uuid
		nsd = new_ns # TODO: Avoid having multiple 'nsd' fields containers


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
			return 400, 'ERROR: Duplicated NS ID' if e.message.include? 'E11000'
		end

		ns_json = new_ns['_id'].to_json
		if request.content_type == 'application/json'
			return 200, ns_json
			#return 200, new_ns['_id'].to_json

		elsif request.content_type == 'application/x-yaml'
			ns_yml = json_to_yaml(ns_json)
			return 200, ns_yml
		end
		#return 200, new_ns.to_json
	end

  # @method delete_nsd_sp_ns_id
  # @overload delete '/network-services/vendor/:vendor/name/:name/version/:version'
  #	Delete a NS by vendor, name and version in JSON or YAML format
  #	@param [String] NS_vendor NS vendor
  # Delete a NS by group
  #	@param [String] ns_name NS Name
  # Delete a NS by name
  #	@param [Integer] ns_version NS version
  # Delete a NS by version
  delete '/network-services/vendor/:vendor/name/:name/version/:version' do
    begin
      ns = Ns.find_by({"name" =>  params[:name], "vendor" => params[:vendor], "version" => params[:version]})
    rescue Mongoid::Errors::DocumentNotFound => e
      return 404,'ERROR: Operation failed'
    end
    ns.destroy
    return 200, 'OK: NSD removed'
  end

	# @method delete_nsd_sp_ns_id
	# @overload delete '/catalogues/network-service/:sp_ns_id'
	#	Delete a NS by its ID
	#	@param [Integer] sp_ns_id NS sp ID
	# Delete a NS
	delete '/network-services/id/:id' do
		#logger.error params[:external_ns_id]
		begin
			ns = Ns.find(params[:id] )
		rescue Mongoid::Errors::DocumentNotFound => e
			return 404,'ERROR: Operation failed'
		end
		ns.destroy
		return 200, 'OK: NSD removed'
	end


	############################################ VNFD API METHODS ############################################

	# @method get_vnfs
	# @overload get '/catalogues/vnfs'
	#	Returns a list of VNFs
	# List all VNFs in JSON or YAML format
	get '/vnfs' do
		params[:offset] ||= 1
		params[:limit] ||= 50

		# Only accept positive numbers
		params[:offset] = 1 if params[:offset].to_i < 1
		params[:limit] = 2 if params[:limit].to_i < 1

		# Get paginated list
		vnfs = Vnf.paginate(:page => params[:offset], :limit => params[:limit])

		# Build HTTP Link Header
		headers['Link'] = build_http_link_vnf(params[:offset].to_i, params[:limit])

		begin
			vnfs_json = vnfs.to_json
			#puts 'VNFS: ', vnfs_json
			if request.content_type == 'application/json'
				return 200, vnfs_json
			elsif request.content_type == 'application/x-yaml'
				vnfs_yml = json_to_yaml(vnfs_json)
				return 200, vnfs_yml
			end
				#puts 'VNFS: ', vnfs_yml
		rescue
			logger.error "Error Establishing a Database Connection"
			return 500, "Error Establishing a Database Connection"
		end
		#halt 200, vnfs.to_json
	end


	# @method get_vnfs_id
	# @overload get '/catalogues/vnfs/id/:id'
	#	Show a VNF in JSON or YAML format
	#	@param [String] id VNF ID
	# Show a VNF by internal ID (uuid)
	get '/vnfs/id/:id' do
		begin
			vnf = Vnf.find(params[:id])
		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			halt 404
		end

		vnf_json = vnf.to_json
		if request.content_type == 'application/json'
			return 200, vnf_json
		elsif request.content_type == 'application/x-yaml'
			vnf_yml = json_to_yaml(vnf_json)
			return 200, vnf_yml
		end
		#puts 'VNFS: ', vnf_json
		#halt 200, vnf.to_json
	end

  # @method get_vnf_sdk_vendor
  # @overload get '/catalogues/vnfs/vendor/:vendor'
  #	Returns an array of all VNF by vendor in JSON or YAML format
  #	@param [String] vnf_vendor VNF vendor
  # Show a VNF vendor
  get '/vnfs/vendor/:vendor' do
    begin
      vnf = Vnf.where({"vendor" => params[:vendor]})
      puts 'VNF: ', vnf.size.to_s

      if vnf.size.to_i == 0
        logger.error "ERROR: VNFD not found"
        return 404
      end

    rescue Mongoid::Errors::DocumentNotFound => e
      logger.error e
      return 404
    end
    vnf_json = vnf.to_json
    if request.content_type == 'application/json'
      return 200, vnf_json
    elsif request.content_type == 'application/x-yaml'
      vnf_yml = json_to_yaml(vnf_json)
      return 200, vnf_yml
    end
  end

  # @method get_vnfs_vnf_vendor.name
  # @overload get '/catalogues/vnfs/vendor/:vendor/name/:name'
  #	Returns an array of all VNF by vendor and name in JSON or YAML format
  #	@param [String] vnf_group VNF vendor
  # Show a VNF vendor
  #	@param [String] vnf_name VNF Name
  # Show a VNF name
  get '/vnfs/vendor/:vendor/name/:name' do
    begin
      vnf = Vnf.where({"vendor" =>  params[:vendor], "name" => params[:name]})

      if vnf.size.to_i == 0
        logger.error "ERROR: VNFD not found"
        return 404
      end

    rescue Mongoid::Errors::DocumentNotFound => e
      logger.error e
      return 404
    end

    vnf_json = vnf.to_json
    if request.content_type == 'application/json'
      return 200, vnf_json
    elsif request.content_type == 'application/x-yaml'
      vnf_yml = json_to_yaml(vnf_json)
      return 200, vnf_yml
    end
  end

  # @method get_vnfd_vnf_vendor.name.version
  # @overload get '/vnfs/vendor/:_vnf_vendor/name/:vnf_name/version/:version'
  #	Show a specific VNF in JSON or YAML format
  #	@param [String] vnf_vendor VNF vendor
  # Show a VNF vendor
  #	@param [String] vnf_name VNF Name
  # Show a VNF name
  #	@param [Integer] vnf_version VNF version
  # Show a VNF version
  get '/vnfs/vendor/:vendor/name/:name/version/:version' do
    begin
      vnf = Vnf.find_by( {"vendor" =>  params[:vendor], "name" =>  params[:name], "version" => params[:version]})
    rescue Mongoid::Errors::DocumentNotFound => e
      logger.error e
      return 404
    end

    vnf_json = vnf.to_json
    if request.content_type == 'application/json'
      return 200, vnf_json
    elsif request.content_type == 'application/x-yaml'
      vnf_yml = json_to_yaml(vnf_json)
      return 200, vnf_yml
    end
    #return 200, ns.nsd.to_json
  end

  # @method get_vnfs_vnf_vendor_last_version
  # @overload get '/catalogues/vnfs/vendor/:vendor/last'
  #	Show a VNF Vendor list for last version in JSON or YAML format
  #	@param [String] vendor VNF Vendor
  # Show a VNF vendor
  get '/vnfs/vendor/:vendor/last' do
    # Search and get all VNF items by vendor
    begin

      vnf = Vnf.where({"vendor" => params[:vendor]}).sort({"version" => -1})#.limit(1).first()

      if vnf.size.to_i == 0
        logger.error "ERROR: VNFD not found"
        return 404

      elsif vnf == nil
        logger.error "ERROR: VNFD not found"
        return 404

      else
        vnf_list = []
        name_list = []
        vnf_name = vnf.first.name
        name_list.push(vnf_name)
        vnf_list.push(vnf.first)
        vnf.each do |vnfd|
          if vnfd.name != vnf_name
            vnf_name = vnfd.name
            vnf_list.push(vnfd) unless name_list.include?(vnf_name)
          end
        end
      end

    rescue Mongoid::Errors::DocumentNotFound => e
      logger.error e
      return 404
    end

    vnf_json = vnf_list.to_json
    puts 'VNFs: ', vnf_json

    if request.content_type == 'application/json'
      return 200, vnf_json
    elsif request.content_type == 'application/x-yaml'
      vnf_yml = json_to_yaml(vnf_json)
      return 200, vnf_yml
    end
  end

	# @method get_vnfs_vnf_name
	# @overload get '/catalogues/vnfs/name/:vnf_name'
	#	Show a VNF or VNF list in JSON or YAML format
	#	@param [String] vnf_name VNF Name
	# Show a VNF by name
	get '/vnfs/name/:name' do
		#params[:offset] ||= 1
		#params[:limit] ||= 10

		# Only accept positive numbers
		#params[:offset] = 1 if params[:offset].to_i < 1
		#params[:limit] = 2 if params[:limit].to_i < 1

		begin
			# Get paginated list
			#ns = Vnf.paginate(:page => params[:offset], :limit => params[:limit])

			# Build HTTP Link Header
			#headers['Link'] = build_http_link_name(params[:offset].to_i, params[:limit], params[:vnf_name])

			#ns = Ns.distinct( "nsd.version" )#.where({ "nsd.name" =>  params[:external_ns_name]})
			vnf = Vnf.where({"name" => params[:name]})
			puts 'VNF: ', vnf.size.to_s

			if vnf.size.to_i == 0
				logger.error "ERROR: VNFD not found"
				return 404
			end

		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end
		vnf_json = vnf.to_json
		if request.content_type == 'application/json'
			return 200, vnf_json
		elsif request.content_type == 'application/x-yaml'
			vnf_yml = json_to_yaml(vnf_json)
			return 200, vnf_yml
		end
	end


	# @method get_vnfd_vnf_version
	# @overload get '/catalogues/vnfs/name/:vnf_name/version/:version'
	#	Show a VNF list in JSON or YAML format
	#	@param [String] vnf_name VNF  Name
	# Show a VNF name
	#	@param [Integer] vnf_version VNF version
	# Show a VNF version
	get '/vnfs/name/:name/version/:version' do
		begin
#			ns = CatalogueModels.find( params[:external_ns_id] )
			vnf = Vnf.where( { "name" =>  params[:name], "version" => params[:version]})

			if vnf.size.to_i == 0
				logger.error "ERROR: VNFD not found"
				return 404
			end

		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end

		vnf_json = vnf.to_json
		if request.content_type == 'application/json'
			return 200, vnf_json
		elsif request.content_type == 'application/x-yaml'
			vnf_yml = json_to_yaml(vnf_json)
			return 200, vnf_yml
		end
		#return 200, ns.nsd.to_json
	end


	# @method get_vnfd_vnf_last_version
	# @overload get '/catalogues/vnfs/:vnf_name/last'
	#	Show a VNF list with last version in JSON or YAML format
	#	@param [String] vnf_name VNF Name
	# Show a VNF name
	get '/vnfs/name/:name/last' do

		# Search and get all items of NS by name
		begin
			puts 'params', params
			vnf = Vnf.where({"name" => params[:name]}).sort({"version" => -1})#.limit(1).first()
			puts 'VNF: ', vnf

			if vnf.size.to_i == 0
				logger.error "ERROR: VNFD not found"
				return 404

			elsif vnf == nil
				logger.error "ERROR: VNFD not found"
				return 404

			else
        vnf_list = []

        vendor_list = []
        vnf_vendor = vnf.first.vendor
        vendor_list.push(vnf_vendor)
        vnf_list.push(vnf.first)
        vnf.each do |vnfd|
          if vnfd.vendor != vnf_vendor
            vnf_vendor = vnfd.vendor
            vnf_list.push(vnfd) unless vendor_list.include?(vnf_vendor)
          end
        end
			end

		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end

		vnf_json = vnf.to_json
		puts 'VNF: ', vnf_json
		if request.content_type == 'application/json'
			return 200, vnf_json
		elsif request.content_type == 'application/x-yaml'
			vnf_yml = json_to_yaml(vnf_json)
			return 200, vnf_yml
		end
	end

	# @method post_vnfs
	# @overload post '/catalogues/vnfs'
	# 	Post a VNF in JSON or YAML format
	# 	@param [YAML] VNF in YAML format
	# Post a VNFD
	# 	@param [JSON] VNF in JSON format
	# Post a VNFD
	post '/vnfs' do
		# Return if content-type is invalid
		return 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

		# Compatibility support for YAML content-type
		if request.content_type == 'application/x-yaml'

			# Validate YAML format
			vnf, errors = parse_yaml(request.body.read)
			#ns, errors = parse_yaml(request.body)
			#puts 'NS :', ns.to_yaml
			#puts 'errors :', errors.to_s
			#vnf = parse_json(request.body.read)
			return 400, errors.to_json if errors

			# Translate from YAML format to JSON format
			vnf_json = yaml_to_json(vnf)

			# Validate JSON format
			vnf, errors = parse_json(vnf_json)
			puts 'vnf: ', vnf.to_json
			return 400, errors.to_json if errors

			# Compatibility support for JSON content-type
		elsif request.content_type == 'application/json'
			# Parses and validates JSON format
			vnf, errors = parse_json(request.body.read)
			return 400, errors.to_json if errors
		end

		# Validate VNF
		#halt 400, 'ERROR: VNFD not found' unless vnf.has_key?('vnfd')
		return 400, 'ERROR: VNF Vendor not found' unless vnf.has_key?('vendor')
		return 400, 'ERROR: VNF Name not found' unless vnf.has_key?('name')
		return 400, 'ERROR: VNF Version not found' unless vnf.has_key?('version')

		# --> Validation disabled
		# Validate VNFD
		#begin
		#	RestClient.post settings.vnfd_validator + '/vnfds', vnf['vnfd'].to_json, 'X-Auth-Token' => @client_token, :content_type => :json
		#rescue Errno::ECONNREFUSED
		#	halt 500, 'VNFD Validator unreachable'
		#rescue => e
		#	logger.error e.response
		#	halt e.response.code, e.response.body
		#end

		# Check if VNF already exists in the catalogue by name, vendor and version
		begin
			vnf = Vnf.find_by( {"name"=>vnf['name'], "vendor" => vnf['vendor'], "version"=>vnf['version']} )
			return 400, 'ERROR: Duplicated VNF Name, Vendor and Version'
		rescue Mongoid::Errors::DocumentNotFound => e
		end
		# Check if VNFD has an ID (it should not) and if it already exists in the catalogue
		begin
			vnf = Ns.find_by({"_id" =>  vnf['_id']})
			return 400, 'ERROR: Duplicated VNF ID'
		rescue Mongoid::Errors::DocumentNotFound => e
		end

		# Save to BD
		begin
			# Generate the UUID for the descriptor
			vnf['_id'] = SecureRandom.uuid
			new_vnf = Vnf.create!(vnf)
		rescue Moped::Errors::OperationFailure => e
			halt 400, 'ERROR: Duplicated VNF ID' if e.message.include? 'E11000'
			halt 400, e.message
		end

		puts 'New VNF has been added'
		vnf_json = new_vnf['_id'].to_json
		if request.content_type == 'application/json'
			return 200, vnf_json
		elsif request.content_type == 'application/x-yaml'
			vnf_yml = json_to_yaml(vnf_json)
			return 200, vnf_yml
		end
		#return 200, new_vnf.to_json
	end

  # @method update_vnfs_vendor_name_version
  # @overload put '/vnfs/vendor/:vendor/name/:name/version/:version'
  # Update a VNF by vendor, name and version in JSON or YAML format
  #	@param [String] VNF_vendor VNF vendor
  # Update a VNF vendor
  #	@param [String] VNF_name VNF Name
  # Update a VNF name
  #	@param [Integer] VNF_version VNF version
  # Update a VNF version
  put '/vnfs/vendor/:vendor/name/:name/version/:version' do
    # Return if content-type is invalid
    return 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')
    #halt 415 unless request.content_type == 'application/json'

    # Compatibility support for YAML content-type
    if request.content_type == 'application/x-yaml'
      # Validate YAML format
      # When updating a NSD, the json object sent to API must contain just data inside
      # of the nsd, without the json field nsd: before <- this might be resolved
      new_vnf, errors = parse_yaml(request.body.read)
      return 400, errors.to_json if errors

      # Translate from YAML format to JSON format
      new_vnf_json = yaml_to_json(new_vnf)

      # Validate JSON format
      new_vnf, errors = parse_json(new_vnf_json)
      puts 'vnf: ', new_vnf.to_json
      puts 'new_vnf id', new_vnf['_id'].to_json
      return 400, errors.to_json if errors

      # Compatibility support for JSON content-type
    elsif request.content_type == 'application/json'
      # Parses and validates JSON format
      new_vnf, errors = parse_json(request.body.read)
      return 400, errors.to_json if errors
    end

    # Validate VNF
    #halt 400, 'ERROR: VNFD not found' unless vnf.has_key?('vnfd')
    return 400, 'ERROR: VNF Vendor not found' unless new_vnf.has_key?('vendor')
    return 400, 'ERROR: VNF Name not found' unless new_vnf.has_key?('name')
    return 400, 'ERROR: VNF Version not found' unless new_vnf.has_key?('version')

    # Validate VNFD
    #begin
    #	RestClient.post settings.vnfd_validator + '/vnfds', new_vnf['vnfd'].to_json, 'X-Auth-Token' => @client_token, :content_type => :json
    #rescue Errno::ECONNREFUSED
    #	halt 500, 'VNFD Validator unreachable'
    #rescue => e
    #	logger.error e.response
    #	halt e.response.code, e.response.body
    #end

    # Retrieve stored version
    begin
      vnf = Vnf.find_by({"name" =>  params[:name], "vendor" => params[:vendor], "version" => params[:version]})
    rescue Mongoid::Errors::DocumentNotFound => e
      halt 404 # 'This VNFD does not exists'
    end
    begin
      vnf = Vnf.find_by( {"name"=>new_vnf['name'], "vendor"=>new_vnf['vendor'], "version"=>new_vnf['version']} )
      return 400, 'ERROR: Duplicated VNF Name, Vendor and Version'
    rescue Mongoid::Errors::DocumentNotFound => e
    end

    # Update to new version
    #vnf.update_attributes(new_vnf)
    vnfd = {}
    puts 'Updating...'
    # Update the group.name.version ID for the descriptor
    new_vnf['_id'] = new_vnf['vendor'].to_s + '.' + new_vnf['name'].to_s + '.' + new_vnf['version'].to_s
    vnfd = new_vnf # TODO: Avoid having multiple 'vnfd' fields containers

    begin
      new_vnf = Vnf.create!(vnfd)
    rescue Moped::Errors::OperationFailure => e
      return 400, 'ERROR: Duplicated VNF ID' if e.message.include? 'E11000'
    end

    vnf_json = new_vnf['_id'].to_json
    if request.content_type == 'application/json'
      return 200, vnf_json
    elsif request.content_type == 'application/x-yaml'
      vnf_yml = json_to_yaml(vnf_json)
      return 200, vnf_yml
    end
    #halt 200, vnf.to_json
  end

	# @method update_vnfs
	# @overload put '/catalogues/vnfs/id/:id'
	#	Update a VNF by its ID in JSON or YAML format
	#	@param [String] id VNF ID
	# Update a VNF
	put '/vnfs/id/:id' do
		# Return if content-type is invalid
		return 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')
		#halt 415 unless request.content_type == 'application/json'

		# Compatibility support for YAML content-type
		if request.content_type == 'application/x-yaml'

			# Validate JSON format
			#new_vnf = parse_json(request.body.read)

			# Validate YAML format
			# When updating a NSD, the json object sent to API must contain just data inside
			# of the nsd, without the json field nsd: before <- this might be resolved
			new_vnf, errors = parse_yaml(request.body.read)
			return 400, errors.to_json if errors

			# Translate from YAML format to JSON format
			new_vnf_json = yaml_to_json(new_vnf)

			# Validate JSON format
			new_vnf, errors = parse_json(new_vnf_json)
			puts 'vnf: ', new_vnf.to_json
			puts 'new_vnf id', new_vnf['_id'].to_json
			return 400, errors.to_json if errors

			# Compatibility support for JSON content-type
		elsif request.content_type == 'application/json'
			# Parses and validates JSON format
			new_vnf, errors = parse_json(request.body.read)
			return 400, errors.to_json if errors
		end

		# Validate VNF
		# TODO: Check if same vendor, Name, Version do already exists in the database
		#halt 400, 'ERROR: VNFD not found' unless vnf.has_key?('vnfd')
		return 400, 'ERROR: VNF Vendor not found' unless new_vnf.has_key?('vendor')
		return 400, 'ERROR: VNF Name not found' unless new_vnf.has_key?('name')
		return 400, 'ERROR: VNF Version not found' unless new_vnf.has_key?('version')

		# Validate VNFD
		#begin
		#	RestClient.post settings.vnfd_validator + '/vnfds', new_vnf['vnfd'].to_json, 'X-Auth-Token' => @client_token, :content_type => :json
		#rescue Errno::ECONNREFUSED
		#	halt 500, 'VNFD Validator unreachable'
		#rescue => e
		#	logger.error e.response
		#	halt e.response.code, e.response.body
		#end

		# Retrieve stored version
		begin
			vnf = Vnf.find(params[:id])
		rescue Mongoid::Errors::DocumentNotFound => e
			halt 404 # 'This VNFD does not exists'
		end
		begin
			vnf = Vnf.find_by( {"name"=>new_vnf['name'], "vendor"=>new_vnf['vendor'], "version"=>new_vnf['version']} )
			return 400, 'ERROR: Duplicated VNF Name, Vendor and Version'
		rescue Mongoid::Errors::DocumentNotFound => e
		end

		# Update to new version
		#vnf.update_attributes(new_vnf)
		vnfd = {}
		prng = Random.new
		puts 'Updating...'

		#new_vnf['_id'] = new_vnf['_id'].to_s + prng.rand(1000).to_s	# Unique IDs per VNFD entries
		new_vnf['_id'] = SecureRandom.uuid
		vnfd = new_vnf # TODO: Avoid having multiple 'vnfd' fields containers

		begin
			new_vnf = Vnf.create!(vnfd)
		rescue Moped::Errors::OperationFailure => e
			return 400, 'ERROR: Duplicated VNF ID' if e.message.include? 'E11000'
		end

		vnf_json = new_vnf['_id'].to_json
		if request.content_type == 'application/json'
			return 200, vnf_json
		elsif request.content_type == 'application/x-yaml'
			vnf_yml = json_to_yaml(vnf_json)
			return 200, vnf_yml
		end
		#halt 200, vnf.to_json
	end

  # @method delete_vnfd_sdk_vnf_id
  # @overload delete '/vnfs/vendor/:vendor/name/:name/version/:version'
  #	Delete a VNF by vendor, name and version in JSON or YAML format
  #	@param [String] vnf_vendor VNF vendor
  # Delete a VNF by group
  #	@param [String] vnf_name VNF Name
  # Delete a VNF by name
  #	@param [Integer] vnf_version VNF version
  # Delete a VNF by version
  delete '/vnfs/vendor/:vendor/name/:name/version/:version' do
    begin
      vnf = Vnf.find_by({"name" =>  params[:name], "vendor" => params[:vendor], "version" => params[:version]})
    rescue Mongoid::Errors::DocumentNotFound => e
      return 404,'ERROR: Operation failed'
    end
    vnf.destroy
    return 200, 'OK: VNFD removed'
  end

	# @method delete_vnfd_sp_vnf_id
	# @overload delete '/catalogues/vnfs/id/:id'
	#	Delete a VNF by its ID
	#	@param [String] id VNF ID
	# Delete a VNF
	delete '/vnfs/id/:id' do
		begin
			vnf = Vnf.find(params[:id])
		rescue Mongoid::Errors::DocumentNotFound => e
			halt 404, e.to_s
		end

		vnf.destroy

		return 200, 'OK: VNFD removed'
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
		pks_json = new_pks['_id'].to_json
		if request.content_type == 'application/json'
			return 200, pks_json

		elsif request.content_type == 'application/x-yaml'
			pks_yml = json_to_yaml(pks_json)
			return 200, pks_yml

		end
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

end