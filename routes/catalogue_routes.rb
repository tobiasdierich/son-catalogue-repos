##
## Copyright (c) 2015 SONATA-NFV
## ALL RIGHTS RESERVED.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
## Neither the name of the SONATA-NFV [, ANY ADDITIONAL AFFILIATION]
## nor the names of its contributors may be used to endorse or promote
## products derived from this software without specific prior written
## permission.
##
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the SONATA
## partner consortium (www.sonata-nfv.eu).

# @see SonCatalogue
class SonataCatalogue < Sinatra::Application
  require 'addressable/uri'

  before do
    # Gatekeeper authn. code will go here for future implementation
    # --> Gatekeeper authn. disabled

    if settings.environment == 'development'
      p 'Development settings'
    end
    #authorized?
  end

  DEFAULT_OFFSET = '0'
  DEFAULT_LIMIT = '10'
  DEFAULT_MAX_LIMIT = '100'

  # @method get_root
  # @overload get '/catalogues/'
  # Get all available interfaces
  # -> Get all interfaces
  get '/' do
    headers 'Content-Type' => 'text/plain; charset=utf8'
    halt 200, interfaces_list.to_yaml
  end

  ### NSD API METHODS ###

  # @method get_nss
  # @overload get '/catalogues/network-services/?'
  #	Returns a list of NSs
  # -> List many descriptors
  get '/network-services/?' do
    params['offset'] ||= DEFAULT_OFFSET
    params['limit'] ||= DEFAULT_LIMIT

    uri = Addressable::URI.new
    uri.query_values = params
    # puts 'params', params
    # puts 'query_values', uri.query_values
    logger.info "Catalogue: entered GET /network-services?#{uri.query}"

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)
    # puts 'keyed_params', keyed_params

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

      nss = Ns.where((keyed_params)).sort({ 'version' => -1 }) #.limit(1).first()
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
          nss_list.push(nsd) unless checked_list.any? { |pair| pair.one == nss_name_vendor.one &&
              pair.two == nss_name_vendor.two }
          checked_list.push(nss_name_vendor)
        end
        #puts 'nss_list:', nss_list.each {|ns| p ns.name, ns.vendor}
      else
        #logger.error "ERROR: 'No NSDs were found'"
        logger.info "Catalogue: leaving GET /network-services?#{uri.query} with 'No NSDs were found'"
        #json_error 404, "No NSDs were found"
        nss_list = []
      end
      #nss = nss_list.paginate(:page => params[:offset], :per_page =>params[:limit])
      nss = apply_limit_and_offset(nss_list, offset=params[:offset], limit=params[:limit])

    else
      # Do the query
      nss = Ns.where(keyed_params)
      logger.info "Catalogue: NSDs=#{nss}"
      #puts nss.to_json
      if nss && nss.size.to_i > 0
        logger.info "Catalogue: leaving GET /network-services?#{uri.query} with #{nss}"

        # Paginate results
        nss = nss.paginate(offset: params[:offset], limit: params[:limit])

      else
        logger.info "Catalogue: leaving GET /network-services?#{uri.query} with 'No NSDs were found'"
        #json_error 404, "No NSDs were found"
      end
    end

    response = ''
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
        ns = Ns.find(params[:id])
      rescue Mongoid::Errors::DocumentNotFound => e
        logger.error e
        json_error 404, "The NSD ID #{params[:id]} does not exist" unless ns
      end
      logger.debug "Catalogue: leaving GET /network-services/#{params[:id]}\" with NSD #{ns}"

      response = ''
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
    json_error 400, 'No NSD ID specified'
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
    json_error 400, 'ERROR: NS Vendor not found' unless new_ns.has_key?('vendor')
    json_error 400, 'ERROR: NS Name not found' unless new_ns.has_key?('name')
    json_error 400, 'ERROR: NS Version not found' unless new_ns.has_key?('version')

    # --> Validation disabled
    # Validate NSD
    #begin
    #	RestClient.post settings.nsd_validator + '/nsds', ns.to_json, :content_type => :json
    #rescue => e
    #	halt 500, {'Content-Type' => 'text/plain'}, "Validator mS unreachable."
    #end

    # Check if NS already exists in the catalogue by name, vendor and version
    begin
      ns = Ns.find_by({ 'name' => new_ns['name'], 'vendor' => new_ns['vendor'], 'version' => new_ns['version'] })
      json_return 200, 'Duplicated NS Name, Vendor and Version'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end
    # Check if NSD has an ID (it should not) and if it already exists in the catalogue
    begin
      ns = Ns.find_by({ '_id' => new_ns['_id'] })
      json_return 200, 'Duplicated NS ID'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    # Save to DB
    begin
      # Generate the UUID for the descriptor
      new_ns['_id'] = SecureRandom.uuid
      new_ns['status'] = 'active'
      ns = Ns.create!(new_ns)
    rescue Moped::Errors::OperationFailure => e
      json_return 200, 'Duplicated NS ID' if e.message.include? 'E11000'
    end

    puts 'New NS has been added'
    response = ''
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

    # Return 400 if params are empty
    json_error 400, 'Update parameters are null' if keyed_params.empty?

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
    json_error 400, 'ERROR: NS Vendor not found' unless new_ns.has_key?('vendor')
    json_error 400, 'ERROR: NS Name not found' unless new_ns.has_key?('name')
    json_error 400, 'ERROR: NS Version not found' unless new_ns.has_key?('version')

    # Set headers
    case request.content_type
      when 'application/x-yaml'
        headers = { 'Accept' => 'application/x-yaml', 'Content-Type' => 'application/x-yaml' }
      else
        headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    end
    headers[:params] = params unless params.empty?

    # Retrieve stored version
    if keyed_params[:vendor].nil? && keyed_params[:name].nil? && keyed_params[:version].nil?
      json_error 400, 'Update Vendor, Name and Version parameters are null'
    else
      begin
        ns = Ns.find_by({ 'vendor' => keyed_params[:vendor], 'name' => keyed_params[:name],
                         'version' => keyed_params[:version] })
        puts 'NS is found'
      rescue Mongoid::Errors::DocumentNotFound => e
        json_error 404, "The NSD Vendor #{keyed_params[:vendor]}, Name #{keyed_params[:name]}, Version #{keyed_params[:version]} does not exist"
      end
    end
    # Check if NS already exists in the catalogue by name, group and version
    begin
      ns = Ns.find_by({ 'name' => new_ns['name'], 'vendor' => new_ns['vendor'], 'version' => new_ns['version'] })
      json_return 200, 'Duplicated NS Name, Vendor and Version'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    # Update to new version
    puts 'Updating...'
    new_ns['_id'] = SecureRandom.uuid # Unique UUIDs per NSD entries
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
      json_return 200, 'Duplicated NS ID' if e.message.include? 'E11000'
    end
    logger.debug "Catalogue: leaving PUT /network-services?#{uri.query}\" with NSD #{new_ns}"

    response = ''
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
      p 'Special case detected= new_status'
      if keyed_params.key?(:status)
        p 'Detected key :status'
        # Do update of Descriptor status -> update_ns_status
        uri = Addressable::URI.new
        uri.query_values = params
        logger.info "Catalogue: entered PUT /network-services/#{uri.query}"

        # Validate NS
        # Retrieve stored version
        begin
          puts 'Searching ' + params[:id].to_s
          ns = Ns.find_by({ '_id' => params[:id] })
          puts 'NS is found'
        rescue Mongoid::Errors::DocumentNotFound => e
          json_error 404, 'This NSD does not exists'
        end

        #Validate new status
        p 'Validating new status(keyed_params): ', keyed_params[:status]
        #p "Validating new status(params): ", params[:new_status]
        valid_status = %w(active inactive delete)
        if valid_status.include? keyed_params[:status]
          # Update to new status
          begin
            #ns.update_attributes(:status => params[:new_status])
            ns.update_attributes(status: keyed_params[:status])
          rescue Moped::Errors::OperationFailure => e
            json_error 400, 'ERROR: Operation failed'
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
        json_error 400, 'ERROR: NS Vendor not found' unless new_ns.has_key?('vendor')
        json_error 400, 'ERROR: NS Name not found' unless new_ns.has_key?('name')
        json_error 400, 'ERROR: NS Version not found' unless new_ns.has_key?('version')

        # Retrieve stored version
        begin
          puts 'Searching ' + params[:id].to_s
          ns = Ns.find_by({ '_id' => params[:id] })
          puts 'NS is found'
        rescue Mongoid::Errors::DocumentNotFound => e
          json_error 404, "The NSD ID #{params[:id]} does not exist"
        end

        # Check if NS already exists in the catalogue by name, vendor and version
        begin
          ns = Ns.find_by({ 'name' => new_ns['name'], 'vendor' => new_ns['vendor'], 'version' => new_ns['version'] })
          json_return 200, 'Duplicated NS Name, Vendor and Version'
        rescue Mongoid::Errors::DocumentNotFound => e
          # Continue
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
          json_return 200, 'Duplicated NS ID' if e.message.include? 'E11000'
        end
        logger.debug "Catalogue: leaving PUT /network-services/#{params[:id]}\" with NSD #{new_ns}"

        response = ''
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
    json_error 400, 'No NSD ID specified'
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
        ns = Ns.find_by({ 'vendor' => keyed_params[:vendor], 'name' => keyed_params[:name],
                         'version' => keyed_params[:version]} )
        puts 'NS is found'
      rescue Mongoid::Errors::DocumentNotFound => e
        json_error 404, "The NSD Vendor #{keyed_params[:vendor]}, Name #{keyed_params[:name]}, Version #{keyed_params[:version]} does not exist"
      end
      logger.debug "Catalogue: leaving DELETE /network-services?#{uri.query}\" with NSD #{ns}"
      ns.destroy
      halt 200, 'OK: NSD removed'
    end
    logger.debug "Catalogue: leaving DELETE /network-services?#{uri.query} with 'No NSD Vendor, Name, Version specified'"
    json_error 400, 'No NSD Vendor, Name, Version specified'
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
        ns = Ns.find(params[:id])
      rescue Mongoid::Errors::DocumentNotFound => e
        logger.error e
        json_error 404, "The NSD ID #{params[:id]} does not exist" unless ns
      end
      logger.debug "Catalogue: leaving DELETE /network-services/#{params[:id]}\" with NSD #{ns}"
      ns.destroy
      halt 200, 'OK: NSD removed'
    end
    logger.debug "Catalogue: leaving DELETE /network-services/#{params[:id]} with 'No NSD ID specified'"
    json_error 400, 'No NSD ID specified'
  end


  ### VNFD API METHODS ###

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

      vnfs = Vnf.where((keyed_params)).sort({ 'version' => -1 }) #.limit(1).first()
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
          vnfs_list.push(vnfd) unless checked_list.any? { |pair| pair.one == vnfs_name_vendor.one &&
              pair.two == vnfs_name_vendor.two }
          checked_list.push(vnfs_name_vendor)
        end
        #puts 'vnfs_list:', vnfs_list.each {|vnf| p vnf.name, vnf.vendor}
      else
        #logger.error "ERROR: 'No VNFDs were found'"
        logger.info "Catalogue: leaving GET /vnfs?#{uri.query} with 'No VNFDs were found'"
        #json_error 404, "No VNFDs were found"
        vnfs_list = []
      end
      #vnfs = vnfs_list.paginate(:page => params[:offset], :per_page =>params[:limit])
      vnfs = apply_limit_and_offset(vnfs_list, offset=params[:offset], limit=params[:limit])

    else
      # Do the query
      vnfs = Vnf.where(keyed_params)
      logger.info "Catalogue: VNFDs=#{vnfs}"
      #puts vnfs.to_json
      if vnfs && vnfs.size.to_i > 0
        logger.info "Catalogue: leaving GET /vnfs?#{uri.query} with #{vnfs}"

        # Paginate results
        vnfs = vnfs.paginate(offset: params[:offset], limit: params[:limit])

      else
        logger.info "Catalogue: leaving GET /vnfs?#{uri.query} with 'No VNFDs were found'"
        #json_error 404, "No VNFDs were found"
      end
    end

    response = ''
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
        vnf = Vnf.find(params[:id])
      rescue Mongoid::Errors::DocumentNotFound => e
        logger.error e
        json_error 404, "The VNFD ID #{params[:id]} does not exist" unless vnf
      end
      logger.debug "Catalogue: leaving GET /vnfs/#{params[:id]}\" with VNFD #{vnf}"

      response = ''
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
    json_error 400, 'No VNFD ID specified'
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
    json_error 400, 'ERROR: VNF Vendor not found' unless new_vnf.has_key?('vendor')
    json_error 400, 'ERROR: VNF Name not found' unless new_vnf.has_key?('name')
    json_error 400, 'ERROR: VNF Version not found' unless new_vnf.has_key?('version')

    # --> Validation disabled
    # Validate VNFD
    #begin
    #	RestClient.post settings.nsd_validator + '/nsds', ns.to_json, :content_type => :json
    #rescue => e
    #	halt 500, {'Content-Type' => 'text/plain'}, "Validator mS unrechable."
    #end

    # Check if VNFD already exists in the catalogue by name, vendor and version
    begin
      vnf = Vnf.find_by({ 'name' => new_vnf['name'], 'vendor' => new_vnf['vendor'], 'version' => new_vnf['version'] })
      json_return 200, 'Duplicated VNF Name, Vendor and Version'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end
    # Check if VNFD has an ID (it should not) and if it already exists in the catalogue
    begin
      vnf = Vnf.find_by({ '_id' => new_vnf['_id'] })
      json_return 200, 'Duplicated VNF ID'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    # Save to DB
    begin
      # Generate the UUID for the descriptor
      new_vnf['_id'] = SecureRandom.uuid
      new_vnf['status'] = 'active'
      vnf = Vnf.create!(new_vnf)
    rescue Moped::Errors::OperationFailure => e
      json_return 200, 'Duplicated VNF ID' if e.message.include? 'E11000'
    end

    puts 'New VNF has been added'
    response = ''
    case request.content_type
      when 'application/json'
        response = vnf.to_json
      when 'application/x-yaml'
        response = json_to_yaml(vnf.to_json)
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

    # Return if params are empty
    json_error 400, 'Update parameters are null' if keyed_params.empty?

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
    json_error 400, 'ERROR: VNF Vendor not found' unless new_vnf.has_key?('vendor')
    json_error 400, 'ERROR: VNF Name not found' unless new_vnf.has_key?('name')
    json_error 400, 'ERROR: VNF Version not found' unless new_vnf.has_key?('version')

    # Set headers
    case request.content_type
      when 'application/x-yaml'
        headers = { 'Accept' => 'application/x-yaml', 'Content-Type' => 'application/x-yaml' }
      else
        headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    end
    headers[:params] = params unless params.empty?

    # Retrieve stored version
    if keyed_params[:vendor].nil? && keyed_params[:name].nil? && keyed_params[:version].nil?
      json_error 400, 'Update Vendor, Name and Version parameters are null'
    else
      begin
        vnf = Vnf.find_by({ 'vendor' => keyed_params[:vendor], 'name' => keyed_params[:name],
                           'version' => keyed_params[:version] })
        puts 'VNF is found'
      rescue Mongoid::Errors::DocumentNotFound => e
        json_error 404, "The VNFD Vendor #{keyed_params[:vendor]}, Name #{keyed_params[:name]}, Version #{keyed_params[:version]} does not exist"
      end
    end
    # Check if VNF already exists in the catalogue by name, group and version
    begin
      vnf = Vnf.find_by({ 'name' => new_vnf['name'], 'vendor' => new_vnf['vendor'], 'version' => new_vnf['version'] })
      json_return 200, 'Duplicated VNF Name, Vendor and Version'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    # Update to new version
    puts 'Updating...'
    new_vnf['_id'] = SecureRandom.uuid # Unique UUIDs per VNFD entries
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
      json_return 200, 'Duplicated VNF ID' if e.message.include? 'E11000'
    end
    logger.debug "Catalogue: leaving PUT /vnfs?#{uri.query}\" with VNFD #{new_vnf}"

    response = ''
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
          vnf = Vnf.find_by({ '_id' => params[:id] })
          puts 'VNF is found'
        rescue Mongoid::Errors::DocumentNotFound => e
          json_error 404, 'This VNFD does not exists'
        end

        #Validate new status
        valid_status = %w(active inactive delete)
        if valid_status.include? keyed_params[:status]
          # Update to new status
          begin
            #vnf.update_attributes(:status => params[:new_status])
            vnf.update_attributes(status: keyed_params[:status])
          rescue Moped::Errors::OperationFailure => e
            json_error 400, 'ERROR: Operation failed'
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
        json_error 400, 'ERROR: VNF Vendor not found' unless new_vnf.has_key?('vendor')
        json_error 400, 'ERROR: VNF Name not found' unless new_vnf.has_key?('name')
        json_error 400, 'ERROR: VNF Version not found' unless new_vnf.has_key?('version')

        # Retrieve stored version
        begin
          puts 'Searching ' + params[:id].to_s
          vnf = Vnf.find_by({ '_id' => params[:id] })
          puts 'VNF is found'
        rescue Mongoid::Errors::DocumentNotFound => e
          json_error 404, "The VNFD ID #{params[:id]} does not exist"
        end

        # Check if VNF already exists in the catalogue by name, vendor and version
        begin
          vnf = Vnf.find_by({ 'name' => new_vnf['name'], 'vendor' => new_vnf['vendor'], 'version' => new_vnf['version'] })
          json_return 200, 'Duplicated VNF Name, Vendor and Version'
        rescue Mongoid::Errors::DocumentNotFound => e
          # Continue
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
          json_return 200, 'Duplicated VNF ID' if e.message.include? 'E11000'
        end
        logger.debug "Catalogue: leaving PUT /vnfs/#{params[:id]}\" with VNFD #{new_vnf}"

        response = ''
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
    json_error 400, 'No VNF ID specified'
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
        vnf = Vnf.find_by({ 'vendor' => keyed_params[:vendor], 'name' => keyed_params[:name],
                           'version' => keyed_params[:version] })
        puts 'VNF is found'
      rescue Mongoid::Errors::DocumentNotFound => e
        json_error 404, "The VNFD Vendor #{keyed_params[:vendor]}, Name #{keyed_params[:name]}, Version #{keyed_params[:version]} does not exist"
      end
      logger.debug "Catalogue: leaving DELETE /vnfs?#{uri.query}\" with NSD #{vnf}"
      vnf.destroy
      halt 200, 'OK: VNFD removed'
    end
    logger.debug "Catalogue: leaving DELETE /vnfs?#{uri.query} with 'No VNFD Vendor, Name, Version specified'"
    json_error 400, 'No VNFD Vendor, Name, Version specified'
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
        vnf = Vnf.find(params[:id])
      rescue Mongoid::Errors::DocumentNotFound => e
        logger.error e
        json_error 404, "The VNFD ID #{params[:id]} does not exist" unless vnf
      end
      logger.debug "Catalogue: leaving DELETE /vnfs/#{params[:id]}\" with NSD #{vnf}"
      vnf.destroy
      halt 200, 'OK: VNFD removed'
    end
    logger.debug "Catalogue: leaving DELETE /vnfs/#{params[:id]} with 'No VNFD ID specified'"
    json_error 400, 'No VNFD ID specified'
  end


  ### PD API METHODS ###

  # @method get_packages
  # @overload get '/catalogues/packages/?'
  #	Returns a list of all Packages
  # -> List many descriptors
  get '/packages/?' do
    params['offset'] ||= DEFAULT_OFFSET
    params['limit'] ||= DEFAULT_LIMIT

    uri = Addressable::URI.new
    uri.query_values = params
    puts 'params', params
    puts 'query_values', uri.query_values
    logger.info "Catalogue: entered GET /packages?#{uri.query}"

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

      pks = Package.where((keyed_params)).sort({ 'version' => -1 }) #.limit(1).first()
      logger.info "Catalogue: PDs=#{pks}"
      #pks = pks.sort({"version" => -1})
      #puts 'pks: ', pks.to_json

      if pks && pks.size.to_i > 0
        logger.info "Catalogue: leaving GET /packages?#{uri.query} with #{pks}"

        # Paginate results
        #pks = pks.paginate(:offset => params[:offset], :limit => params[:limit]).sort({"version" => -1})

        pks_list = []
        checked_list = []

        pks_name_vendor = Pair.new(pks.first.name, pks.first.vendor)
        #p 'pks_name_vendor:', [pks_name_vendor.one, pks_name_vendor.two]
        checked_list.push(pks_name_vendor)
        pks_list.push(pks.first)

        pks.each do |pd|
          #p 'Comparison: ', [pd.name, pd.vendor].to_s + [pks_name_vendor.one, pks_name_vendor.two].to_s
          if (pd.name != pks_name_vendor.one) || (pd.vendor != pks_name_vendor.two)
            pks_name_vendor = Pair.new(pd.name, pd.vendor)
          end
          pks_list.push(pd) unless checked_list.any? { |pair| pair.one == pks_name_vendor.one &&
              pair.two == pks_name_vendor.two }
          checked_list.push(pks_name_vendor)
        end

        #puts 'pks_list:', pks_list.each {|p| p p.name, p.vendor}
      else
        #logger.error "ERROR: 'No PDs were found'"
        logger.info "Catalogue: leaving GET /packages?#{uri.query} with 'No PDs were found'"
        #json_error 404, "No PDs were found"
        pks_list = []
      end
      #pks = pks_list.paginate(:page => params[:offset], :per_page =>params[:limit])
      pks = apply_limit_and_offset(pks_list, offset=params[:offset], limit=params[:limit])

    else
      # Do the query
      pks = Package.where(keyed_params)
      logger.info "Catalogue: PDs=#{pks}"
      #puts pks.to_json
      if pks && pks.size.to_i > 0
        logger.info "Catalogue: leaving GET /packages?#{uri.query} with #{pks}"

        # Paginate results
        pks = pks.paginate(offset: params[:offset], limit: params[:limit])

      else
        logger.info "Catalogue: leaving GET /packages?#{uri.query} with 'No PDs were found'"
        #json_error 404, "No PDs were found"
      end
    end

    response = ''
    case request.content_type
      when 'application/json'
        response = pks.to_json
      when 'application/x-yaml'
        response = json_to_yaml(pks.to_json)
      else
        halt 415
    end
    halt 200, response
  end

  # @method get_packages_package_id
  # @overload get '/catalogues/packages:id/?'
  #	GET one specific descriptor
  #	@param [String] package_uuid Package id
  # Show a Package by uuid
  get '/packages/:id/?' do
    unless params[:id].nil?
      logger.debug "Catalogue: GET /packages/#{params[:id]}"

      begin
        pks = Package.find(params[:id])
      rescue Mongoid::Errors::DocumentNotFound => e
        logger.error e
        json_error 404, "The PD ID #{params[:id]} does not exist" unless pks
      end
      logger.debug "Catalogue: leaving GET /packages/#{params[:id]}\" with PD #{pks}"

      response = ''
      case request.content_type
        when 'application/json'
          response = pks.to_json
        when 'application/x-yaml'
          response = json_to_yaml(pks.to_json)
        else
          halt 415
      end
      halt 200, response

    end
    logger.debug "Catalogue: leaving GET /packages/#{params[:id]} with 'No PD ID specified'"
    json_error 400, 'No PD ID specified'
  end

  # @method post_package
  # @overload post '/catalogues/packages'
  # Post a Package in JSON or YAML format
  post '/packages' do
    #A bit more work as it needs to parse the package descriptor to get GROUP, NAME, and VERSION.
    # Return if content-type is invalid
    halt 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    # Compatibility support for YAML content-type
    case request.content_type
      when 'application/x-yaml'
        # Validate YAML format
        # When updating a PD, the json object sent to API must contain just data inside
        # of the pd, without the json field pd: before
        pks, errors = parse_yaml(request.body.read)
        halt 400, errors.to_json if errors

        # Translate from YAML format to JSON format
        new_pks_json = yaml_to_json(pks)

        # Validate JSON format
        new_pks, errors = parse_json(new_pks_json)
        puts 'pks: ', new_pks.to_json
        #puts 'new_pks id', new_pks['_id'].to_json
        halt 400, errors.to_json if errors

      else
        # Compatibility support for JSON content-type
        # Parses and validates JSON format
        new_pks, errors = parse_json(request.body.read)
        halt 400, errors.to_json if errors
    end

    # Validate NS
    json_error 400, 'ERROR: Package Vendor not found' unless new_pks.has_key?('vendor')
    json_error 400, 'ERROR: Package Name not found' unless new_pks.has_key?('name')
    json_error 400, 'ERROR: Package Version not found' unless new_pks.has_key?('version')

    # --> Validation disabled
    # Validate PD
    #begin
    #	RestClient.post settings.nsd_validator + '/nsds', ns.to_json, :content_type => :json
    #rescue => e
    #	halt 500, {'Content-Type' => 'text/plain'}, "Validator mS unrechable."
    #end

    # Check if PD already exists in the catalogue by name, vendor and version
    begin
      pks = Package.find_by({ 'name' => new_pks['name'], 'vendor' => new_pks['vendor'], 'version' => new_pks['version'] })
      json_return 200, 'Duplicated Package Name, Vendor and Version'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end
    # Check if PD has an ID (it should not) and if it already exists in the catalogue
    begin
      pks = Package.find_by({ '_id' => new_pks['_id'] })
      json_return 200, 'Duplicated Package ID'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    # Save to DB
    begin
      # Generate the UUID for the descriptor
      new_pks['_id'] = SecureRandom.uuid
      new_pks['status'] = 'active'
      pks = Package.create!(new_pks)
    rescue Moped::Errors::OperationFailure => e
      json_return 200, 'Duplicated Package ID' if e.message.include? 'E11000'
    end

    puts 'New Package has been added'
    response = ''
    case request.content_type
      when 'application/json'
        response = pks.to_json
      when 'application/x-yaml'
        response = json_to_yaml(pks.to_json)
      else
        halt 415
    end
    halt 201, response
  end

  # @method update_package_group_name_version
  # @overload put '/catalogues/packages/vendor/:package_group/name/:package_name/version/:package_version
  #	Update a Package vendor, name and version in JSON or YAML format
  ## Catalogue - UPDATE
  put '/packages/?' do
    uri = Addressable::URI.new
    uri.query_values = params
    puts 'params', params
    puts 'query_values', uri.query_values
    logger.info "Catalogue: entered PUT /packages?#{uri.query}"

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)
    puts 'keyed_params', keyed_params

    # Return if content-type is invalid
    halt 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    # Return if params are empty
    json_error 400, 'Update parameters are null' if keyed_params.empty?

    # Compatibility support for YAML content-type
    case request.content_type
      when 'application/x-yaml'
        # Validate YAML format
        # When updating a PD, the json object sent to API must contain just data inside
        # of the pd, without the json field pd: before
        pks, errors = parse_yaml(request.body.read)
        halt 400, errors.to_json if errors

        # Translate from YAML format to JSON format
        new_pks_json = yaml_to_json(pks)

        # Validate JSON format
        new_pks, errors = parse_json(new_pks_json)
        puts 'pks: ', new_pks.to_json
        #puts 'new_pks id', new_pks['_id'].to_json
        halt 400, errors.to_json if errors

      else
        # Compatibility support for JSON content-type
        # Parses and validates JSON format
        new_pks, errors = parse_json(request.body.read)
        halt 400, errors.to_json if errors
    end

    # Validate Package
    # Check if same vendor, Name, Version do already exists in the database
    json_error 400, 'ERROR: Package Vendor not found' unless new_pks.has_key?('vendor')
    json_error 400, 'ERROR: Package Name not found' unless new_pks.has_key?('name')
    json_error 400, 'ERROR: Package Version not found' unless new_pks.has_key?('version')

    # Set headers
    case request.content_type
      when 'application/x-yaml'
        headers = { 'Accept' => 'application/x-yaml', 'Content-Type' => 'application/x-yaml' }
      else
        headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    end
    headers[:params] = params unless params.empty?

    # Retrieve stored version
    if keyed_params[:vendor].nil? && keyed_params[:name].nil? && keyed_params[:version].nil?
      json_error 400, 'Update Vendor, Name and Version parameters are null'
    else
      begin
        pks = Package.find_by({ 'vendor' => keyed_params[:vendor], 'name' => keyed_params[:name],
                               'version' => keyed_params[:version] })
        puts 'Package is found'
      rescue Mongoid::Errors::DocumentNotFound => e
        json_error 404, "The PD Vendor #{keyed_params[:vendor]}, Name #{keyed_params[:name]}, Version #{keyed_params[:version]} does not exist"
      end
    end
    # Check if PD already exists in the catalogue by name, group and version
    begin
      pks = Package.find_by({ 'name' => new_pks['name'], 'vendor' => new_pks['vendor'], 'version' => new_pks['version'] })
      json_return 200, 'Duplicated PD Name, Vendor and Version'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    # Update to new version
    puts 'Updating...'
    new_pks['_id'] = SecureRandom.uuid # Unique UUIDs per PD entries
    pd = new_pks

    # --> Validation disabled
    # Validate PD
    # begin
    #	RestClient.post settings.nsd_validator + '/nsds', nsd.to_json, :content_type => :json
    # rescue => e
    #	logger.error e.response
    #	return e.response.code, e.response.body
    # end

    begin
      new_pks = Package.create!(pd)
    rescue Moped::Errors::OperationFailure => e
      json_return 200, 'Duplicated Package ID' if e.message.include? 'E11000'
    end
    logger.debug "Catalogue: leaving PUT /packages?#{uri.query}\" with PD #{new_pks}"

    response = ''
    case request.content_type
      when 'application/json'
        response = new_pks.to_json
      when 'application/x-yaml'
        response = json_to_yaml(new_pks.to_json)
      else
        halt 415
    end
    halt 200, response
  end

  # @method update_package_id
  # @overload put '/catalogues/packages/:id/?'
  #	Update a Package in JSON or YAML format
  ## Catalogue - UPDATE
  put '/packages/:id/?' do
    # Return if content-type is invalid
    halt 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    unless params[:id].nil?
      logger.debug "Catalogue: PUT /packages/#{params[:id]}"

      # Transform 'string' params Hash into keys
      keyed_params = keyed_hash(params)
      puts 'keyed_params', keyed_params

      # Check for special case (:status param == <new_status>)
      if keyed_params.key?(:status)
        # Do update of Descriptor status -> update_ns_status
        uri = Addressable::URI.new
        uri.query_values = params
        logger.info "Catalogue: entered PUT /network-services/#{uri.query}"

        # Validate Package
        # Retrieve stored version
        begin
          puts 'Searching ' + params[:id].to_s
          pks = Package.find_by({ '_id' => params[:id] })
          puts 'Package is found'
        rescue Mongoid::Errors::DocumentNotFound => e
          json_error 404, 'This PD does not exists'
        end

        # Validate new status
        valid_status = %w(active inactive delete)
        if valid_status.include? keyed_params[:status]
          # Update to new status
          begin
            #pks.update_attributes(:status => params[:new_status])
            pks.update_attributes(status: keyed_params[:status])
          rescue Moped::Errors::OperationFailure => e
            json_error 400, 'ERROR: Operation failed'
          end
        else
          json_error 400, "Invalid new status #{keyed_params[:status]}"
        end

        # --> Validation disabled
        # Validate PD
        # begin
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
            pks, errors = parse_yaml(request.body.read)
            halt 400, errors.to_json if errors

            # Translate from YAML format to JSON format
            new_ns_json = yaml_to_json(pks)

            # Validate JSON format
            new_pks, errors = parse_json(new_ns_json)
            puts 'pks: ', new_pks.to_json
            #puts 'new_pks id', new_pks['_id'].to_json
            halt 400, errors.to_json if errors

          else
            # Compatibility support for JSON content-type
            # Parses and validates JSON format
            new_pks, errors = parse_json(request.body.read)
            halt 400, errors.to_json if errors
        end

        # Validate Package
        # Check if same vendor, Name, Version do already exists in the database
        json_error 400, 'ERROR: Package Vendor not found' unless new_pks.has_key?('vendor')
        json_error 400, 'ERROR: Package Name not found' unless new_pks.has_key?('name')
        json_error 400, 'ERROR: Package Version not found' unless new_pks.has_key?('version')

        # Retrieve stored version
        begin
          puts 'Searching ' + params[:id].to_s
          pks = Package.find_by({ '_id' => params[:id] })
          puts 'Package is found'
        rescue Mongoid::Errors::DocumentNotFound => e
          json_error 404, "The PD ID #{params[:id]} does not exist"
        end

        # Check if Package already exists in the catalogue by name, vendor and version
        begin
          pks = Package.find_by({ 'name' => new_pks['name'], 'vendor' => new_pks['vendor'],
                                 'version' => new_pks['version'] })
          json_return 200, 'Duplicated Package Name, Vendor and Version'
        rescue Mongoid::Errors::DocumentNotFound => e
          # Continue
        end

        # Update to new version
        puts 'Updating...'
        new_pks['_id'] = SecureRandom.uuid
        pd = new_pks

        # --> Validation disabled
        # Validate PD
        #begin
        #	RestClient.post settings.nsd_validator + '/nsds', nsd.to_json, :content_type => :json
        #rescue => e
        #	logger.error e.response
        #	return e.response.code, e.response.body
        #end

        begin
          new_pks = Package.create!(pd)
        rescue Moped::Errors::OperationFailure => e
          json_return 200, 'Duplicated Package ID' if e.message.include? 'E11000'
        end
        logger.debug "Catalogue: leaving PUT /packages/#{params[:id]}\" with PD #{new_pks}"

        response = ''
        case request.content_type
          when 'application/json'
            response = new_pks.to_json
          when 'application/x-yaml'
            response = json_to_yaml(new_pks.to_json)
          else
            halt 415
        end
        halt 200, response
      end
    end
    logger.debug "Catalogue: leaving PUT /packages/#{params[:id]} with 'No PD ID specified'"
    json_error 400, 'No PD ID specified'
  end

  # @method delete_pd_package_group_name_version
  # @overload delete '/catalogues/packages/vendor/:package_group/name/:package_name/version/:package_version'
  #	Delete a PD by group, name and version
  delete '/packages/?' do
    uri = Addressable::URI.new
    uri.query_values = params
    puts 'params', params
    puts 'query_values', uri.query_values
    logger.info "Catalogue: entered DELETE /packages?#{uri.query}"

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)
    puts 'keyed_params', keyed_params

    unless keyed_params[:vendor].nil? && keyed_params[:name].nil? && keyed_params[:version].nil?
      begin
        pks = Package.find_by({ 'vendor' => keyed_params[:vendor], 'name' => keyed_params[:name],
                               'version' => keyed_params[:version] })
        puts 'Package is found'
      rescue Mongoid::Errors::DocumentNotFound => e
        json_error 404, "The PD Vendor #{keyed_params[:vendor]}, Name #{keyed_params[:name]}, Version #{keyed_params[:version]} does not exist"
      end
      logger.debug "Catalogue: leaving DELETE /packages?#{uri.query}\" with PD #{pks}"
      pks.destroy
      halt 200, 'OK: PD removed'
    end
    logger.debug "Catalogue: leaving DELETE /packages?#{uri.query} with 'No PD Vendor, Name, Version specified'"
    json_error 400, 'No PD Vendor, Name, Version specified'
  end

  # @method delete_pd_package_id
  # @overload delete '/catalogues/packages/:id/?'
  #	Delete a PD by its ID
  #	@param [uuid] id PD ID
  # Delete a PD by uuid
  delete '/packages/:id/?' do
    unless params[:id].nil?
      logger.debug "Catalogue: DELETE /packages/#{params[:id]}"
      begin
        pks = Package.find(params[:id])
      rescue Mongoid::Errors::DocumentNotFound => e
        logger.error e
        json_error 404, "The PD ID #{params[:id]} does not exist" unless pks
      end
      logger.debug "Catalogue: leaving DELETE /packages/#{params[:id]}\" with PD #{pks}"
      pks.destroy
      halt 200, 'OK: PD removed'
    end
    logger.debug "Catalogue: leaving DELETE /packages/#{params[:id]} with 'No PD ID specified'"
    json_error 400, 'No PD ID specified'
  end


  ### SONP API METHODS ###

  # @method get_son_package_list
  # @overload get '/catalogues/son-packages/?'
  #	Returns a list of son-packages
  #	-> List many son-packages
  get '/son-packages/?' do
    params['offset'] ||= DEFAULT_OFFSET
    params['limit'] ||= DEFAULT_LIMIT

    uri = Addressable::URI.new
    uri.query_values = params
    puts 'params', params
    puts 'query_values', uri.query_values
    logger.info "Catalogue: entered GET /son-packages?#{uri.query}"

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

    # Do the query

    file_list = FileContainer.where(keyed_params)

    logger.info "Catalogue: leaving GET /son-packages?#{uri.query} with #{file_list}"

    # Paginate results
    file_list = file_list.paginate(offset: params[:offset], limit: params[:limit])

    response = ''
    case request.content_type
      when 'application/json'
        response = file_list.to_json
      when 'application/x-yaml'
        response = json_to_yaml(file_list.to_json)
      else
        halt 415
    end
    halt 200, response
  end

  # @method get_son_package_id
  # @overload get '/catalogues/sonp-packages/:id/?'
  #	Get a son-package
  #	@param [string] son-package ID
  # son-package internal database identifier
  get '/son-packages/:id/?' do
    #Dir.chdir(File.dirname(__FILE__))
    logger.debug "Catalogue: entered GET /son-packages/#{params[:id]}"
    #puts 'ID: ', params[:id]
    begin
      sonp = FileContainer.find_by({ '_id' => params[:id] })
      #p 'FileContainer FOUND'
      p 'Filename: ', sonp['grid_fs_name']
      p 'grid_fs_id: ', sonp['grid_fs_id']
    rescue Mongoid::Errors::DocumentNotFound => e
      logger.error e
      halt 404
    end

    grid_fs = Mongoid::GridFs
    grid_file = grid_fs.get(sonp['grid_fs_id'])

    #grid_file.data # big huge blob
    #temp=Tempfile.new("/home/osboxes/Downloads/#{sonp['grid_fs_name'].to_s}", 'wb')
    #grid_file.each do |chunk|
    #  temp.write(chunk) # streaming write
    #end
    ## Client file recovery
    #temp=File.new("/home/osboxes/Downloads/#{sonp['grid_fs_name']}", 'wb')
    #temp.write(grid_file.data)
    #temp.close

    logger.debug "Catalogue: leaving GET /son-packages/#{params[:id]}"
    halt 200, grid_file.data
  end

  # @method post_son_package
  # @overload post '/catalogues/son-package'
  # Post a son Package in binary-data
  post '/son-packages' do
    logger.debug 'Catalogue: entered POST /son-packages/'
    # Return if content-type is invalid
    halt 415 unless request.content_type == 'application/zip'

    #puts "headers", request.env["HTTP_CONTENT_DISPOSITION"]
    att = request.env['HTTP_CONTENT_DISPOSITION']
    filename = att.match(/filename=(\"?)(.+)\1/)[2]
    #puts "filename", filename
    #JSON.pretty_generate(request.env)

    # Reads body data
    file, errors = request.body
    halt 400, errors.to_json if errors

    ### Implemented here the MD5 checksum for the file
    #p "TEST", file.string
    #file_hash = checksum file.string
    #p "FILE HASH is: ", file_hash

    # Check duplicates
    # -> grid_fs_name
    # Check if son-package already exists in the catalogue by filename (grid-fs-name identifier)
    begin
      sonpkg = FileContainer.find_by({ 'grid_fs_name' => filename })
      json_return 200, 'Duplicated son-package Filename'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    # Save to DB
    #return 400, 'ERROR: Package Name not found' unless sonp.has_key?('package_name')
    #return 400, 'ERROR: Package Vendor not found' unless sonp.has_key?('package_group')
    #return 400, 'ERROR: Package Version not found' unless sonp.has_key?('package_version')

    #file = File.open('/home/osboxes/sonata/son-catalogue-repos/samples/package_example.zip')
    # Content-Disposition: attachment; filename=FILENAME

    grid_fs = Mongoid::GridFs
    grid_file = grid_fs.put(file,
                            filename: filename,
                            content_type: 'application/zip',
                            _id: SecureRandom.uuid,
    #:file_hash   => file_hash,
    #:chunk_size   => 100 * 1024,
    #:metadata     => {'description' => "SONATA zip package"}
    )

    sonp_id = SecureRandom.uuid
    FileContainer.new.tap do |file_container|
      file_container._id = sonp_id
      file_container.grid_fs_id = grid_file.id
      file_container.grid_fs_name = filename
      file_container.md5 = grid_file.md5
      file_container.save
    end
    logger.debug "Catalogue: leaving POST /son-packages/ with #{grid_file.id}"
    #halt 201, grid_file.id.to_json
    halt 201, sonp_id.to_json
  end

  # @method update_son_package_id
  # @overload put '/catalogues/son-packages/:id/?'
  #	Update a son-package in JSON or YAML format
  ## Catalogue - UPDATE
  put '/son-packages/:id/?' do
    # Work in progress
    halt 501
  end

  # @method delete_son_package_id
  # @overload delete '/catalogues/son-packages/:id/?'
  #	Delete a son-package by its ID
  #	@param [uuid] son-package ID
  delete '/son-packages/:id/?' do
    unless params[:id].nil?
      logger.debug "Catalogue: entered DELETE /son-packages/#{params[:id]}"
      begin
        sonp = FileContainer.find_by('_id' => params[:id])
      rescue Mongoid::Errors::DocumentNotFound => e
        logger.error e
        json_error 404, "The son-package ID #{params[:id]} does not exist" unless sonp
      end

      # Remove files from grid
      grid_fs = Mongoid::GridFs
      grid_fs.delete(sonp['grid_fs_id'])
      sonp.destroy

      logger.debug "Catalogue: leaving DELETE /son-packages/#{params[:id]}\" with son-package #{sonp}"
      halt 200, 'OK: son-package removed'
    end
    logger.debug "Catalogue: leaving DELETE /son-packages/#{params[:id]} with 'No son-package ID specified'"
    json_error 400, 'No son-package ID specified'
  end
end