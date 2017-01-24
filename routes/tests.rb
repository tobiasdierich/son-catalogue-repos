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
## Neither the name of the SONATA-NFV
## nor the names of its contributors may be used to endorse or promote
## products derived from this software without specific prior written
## permission.
##
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the SONATA
## partner consortium (www.sonata-nfv.eu).

class CatalogueV2 < SonataCatalogue
  get '/api-docs' do
    redirect '/index.html'
  end
end


# @see SonCatalogue
class SonataCatalogue < Sinatra::Application
  require 'addressable/uri'

  get '/api-docs' do
    redirect '/index.html'
  end

  # @method get_root
  # @overload get '/catalogues/tests'
  # Get all available interfaces
  # -> Get all interfaces
  # get '/tests' do
  #   headers 'Content-Type' => 'text/plain; charset=utf8'
  #   result = 'This is a test'
  #   halt 200, result.to_yaml
  # end

  # @method get_nss
  # @overload get '/catalogues/network-services/?'
  #	Returns a list of NSs
  # -> List many descriptors
  get '/tests/?' do
    params['offset'] ||= DEFAULT_OFFSET
    params['limit'] ||= DEFAULT_LIMIT

    #uri = Addressable::URI.new
    #uri.query_values = params
    # puts 'params', params
    # puts 'query_values', uri.query_values
    #logger.info "Catalogue: entered GET /network-services?#{uri.query}"
    logger.info "Catalogue: entered GET /network-services?#{params}"
    logger.info "Catalogue: entered GET /network-services?#{query_string}"

    #puts 'request params', params

    # Modify Hash strings names to embedded docs names
    metadata = ['_id', 'status', 'signature', 'created_at', 'update_at', 'offset', 'limit', 'nsd', 'vnfd', 'pd']

    params.keys.each do |k|
      p 'k', k
      unless metadata.include?(k)
        p 'includes?', metadata.include?(k)
        params['nsd.'+k.to_s] = params.delete(k)
      end
    end
    p 'params', params

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)
    p 'keyed_params', keyed_params

    # Set headers
    case request.content_type
      when 'application/x-yaml'
        headers = { 'Accept' => 'application/x-yaml', 'Content-Type' => 'application/x-yaml' }
      else
        headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    end
    headers[:params] = params unless params.empty?
    p 'headers_params', headers[:params]
    # Get rid of :offset and :limit
    [:offset, :limit].each { |k| keyed_params.delete(k) }
    # puts 'keyed_params(1)', keyed_params

    # Check for special case (:version param == last)
    if keyed_params.key?(:'nsd.version') && keyed_params[:'nsd.version'] == 'last'
      # Do query for last version -> get_nsd_ns_vendor_last_version

      keyed_params.delete(:'nsd.version')
      p 'keyed_params(2)', keyed_params

      nss = Nsd.where((keyed_params)).sort({ 'nsd.version' => -1 }) #.limit(1).first()
      logger.info "Catalogue: NSDs=#{nss}"
      # nss = nss.sort({"version" => -1})
      # puts 'nss: ', nss.to_json

      if nss && nss.size.to_i > 0
        logger.info "Catalogue: leaving GET /network-services?#{uri.query} with #{nss}"

        # Paginate results
        # nss = nss.paginate(:offset => params[:offset], :limit => params[:limit]).sort({"version" => -1})

        nss_list = []
        checked_list = []

        # p 'NSS', nss.first.nsd['vendor']
        nss_name_vendor = Pair.new(nss.first.nsd['name'], nss.first.nsd['vendor'])
        #nss_name_vendor = Pair.new(nss.first.nsd, nss.first.nsd.vendor)
        # p 'nss_name_vendor:', [nss_name_vendor.one, nss_name_vendor.two]
        checked_list.push(nss_name_vendor)
        nss_list.push(nss.first)

        nss.each do |nsd|
          p 'nsd', nsd
          p 'nsd.nsd[name]', nsd.nsd['name']
          p 'nsd.nsd[vendor]', nsd.nsd['vendor']
          # p 'Comparison: ', [nsd.name, nsd.vendor].to_s + [nss_name_vendor.one, nss_name_vendor.two].to_s
          if (nsd.nsd['name'] != nss_name_vendor.one) || (nsd.nsd['vendor'] != nss_name_vendor.two)
            nss_name_vendor = Pair.new(nsd.nsd['name'], nsd.nsd['vendor'])
            # p 'nss_name_vendor(x):', [nss_name_vendor.one, nss_name_vendor.two]
            # checked_list.each do |pair|
            #  p [pair.one, nss_name_vendor.one], [pair.two, nss_name_vendor.two]
            #  p pair.one == nss_name_vendor.one && pair.two == nss_name_vendor.two
          end
          nss_list.push(nsd) unless checked_list.any? { |pair| pair.one == nss_name_vendor.one &&
              pair.two == nss_name_vendor.two }
          checked_list.push(nss_name_vendor)
        end
        # puts 'nss_list:', nss_list.each {|ns| p ns.name, ns.vendor}
      else
        # logger.error "ERROR: 'No NSDs were found'"
        logger.info "Catalogue: leaving GET /network-services?#{uri.query} with 'No NSDs were found'"
        # json_error 404, "No NSDs were found"
        nss_list = []
      end
      # nss = nss_list.paginate(:page => params[:offset], :per_page =>params[:limit])
      nss = apply_limit_and_offset(nss_list, offset=params[:offset], limit=params[:limit])

    else
      # Do the query
      p 'keyed_params', keyed_params

      nss = Nsd.where(keyed_params).all
      logger.info "Catalogue: NSDs=#{nss}"
      # puts nss.to_json
      if nss && nss.size.to_i > 0
        logger.info "Catalogue: leaving GET /network-services?#{uri.query} with #{nss}"

        # Paginate results
        nss = nss.paginate(offset: params[:offset], limit: params[:limit])

      else
        logger.info "Catalogue: leaving GET /network-services?#{uri.query} with 'No NSDs were found'"
        # json_error 404, "No NSDs were found"
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
  #	  GET one specific descriptor
  #	  @param :id [Symbol] unique identifier
  # Show a NS by internal ID (uuid)
  get '/tests/:id/?' do
    unless params[:id].nil?
      logger.debug "Catalogue: GET /network-services/#{params[:id]}"

      begin
        ns = Nsd.find(params[:id])
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

  # @method post_tests
  # @overload post '/catalogues/tests'
  # Post a NS in JSON or YAML format
  post '/tests' do
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
        # puts 'ns: ', new_ns.to_json
        # puts 'new_ns id', new_ns['_id'].to_json
        halt 400, errors.to_json if errors

      else
        # Compatibility support for JSON content-type
        # Parses and validates JSON format
        new_ns, errors = parse_json(request.body.read)
        halt 400, errors.to_json if errors
    end

    # Validate NS
    json_error 400, 'ERROR: NS Vendor not found' unless new_ns['nsd'].has_key?('vendor')
    json_error 400, 'ERROR: NS Name not found' unless new_ns['nsd'].has_key?('name')
    json_error 400, 'ERROR: NS Version not found' unless new_ns['nsd'].has_key?('version')

    p new_ns['nsd']['name']

    # Check if NS already exists in the catalogue by name, vendor and version
    begin
      ns = Nsd.find_by({ 'nsd.name' => new_ns['nsd']['name'], 'nsd.vendor' => new_ns['nsd']['vendor'], 'nsd.version' => new_ns['nsd']['version'] })
      json_return 200, 'Duplicated NS Name, Vendor and Version'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end
    # Check if NSD has an ID (it should not) and if it already exists in the catalogue
    begin
      ns = Nsd.find_by({ '_id' => new_ns['_id'] })
      json_return 200, 'Duplicated NS ID'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    # Save to DB
    begin
      new_nsd = Nsd.new('_id'=>SecureRandom.uuid, 'status' => 'active', 'signature' => 'null', )
      new_nsd.nsd = Ns.new(new_ns['nsd'])
      #ns = new_nsd.save!

      #new_nsd = {}
      # Generate the UUID for the descriptor
      #new_nsd['nsd'] = Ns.new(new_ns)
      #new_nsd['_id'] = SecureRandom.uuid
      #new_nsd['status'] = 'active'
      #new_nsd['signature'] = 'null'
      ns = Nsd.create!(new_nsd)
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
  put '/tests/?' do
    uri = Addressable::URI.new
    uri.query_values = params
    # puts 'params', params
    # puts 'query_values', uri.query_values
    logger.info "Catalogue: entered PUT /network-services?#{uri.query}"

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)
    # puts 'keyed_params', keyed_params

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
        # puts 'ns: ', new_ns.to_json
        # puts 'new_ns id', new_ns['_id'].to_json
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
    # begin
    #	  postcurb settings.nsd_validator + '/nsds', nsd.to_json, :content_type => :json
    # rescue => e
    #	  logger.error e.response
    #	return e.response.code, e.response.body
    # end

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
  put '/tests/:id/?' do
    # Return if content-type is invalid
    halt 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    unless params[:id].nil?
      logger.debug "Catalogue: PUT /network-services/#{params[:id]}"

      # Transform 'string' params Hash into keys
      keyed_params = keyed_hash(params)
      # puts 'keyed_params', keyed_params

      # Check for special case (:status param == <new_status>)
      p 'Special case detected= new_status'
      if keyed_params.key?(:status)
        p 'Detected key :status'
        # Do update of Descriptor status -> update_ns_status
        # uri = Addressable::URI.new
        # uri.query_values = params
        logger.info "Catalogue: entered PUT /network-services/#{query_string}"

        # Validate NS
        # Retrieve stored version
        begin
          puts 'Searching ' + params[:id].to_s
          ns = Ns.find_by({ '_id' => params[:id] })
          puts 'NS is found'
        rescue Mongoid::Errors::DocumentNotFound => e
          json_error 404, 'This NSD does not exists'
        end

        # Validate new status
        p 'Validating new status(keyed_params): ', keyed_params[:status]
        # p "Validating new status(params): ", params[:new_status]
        valid_status = %w(active inactive delete)
        if valid_status.include? keyed_params[:status]
          # Update to new status
          begin
            # ns.update_attributes(:status => params[:new_status])
            ns.update_attributes(status: keyed_params[:status])
          rescue Moped::Errors::OperationFailure => e
            json_error 400, 'ERROR: Operation failed'
          end
        else
          json_error 400, "Invalid new status #{keyed_params[:status]}"
        end

        # --> Validation disabled
        # Validate NSD
        # begin
        #	  postcurb settings.nsd_validator + '/nsds', nsd.to_json, :content_type => :json
        # rescue => e
        #	  logger.error e.response
        #	  return e.response.code, e.response.body
        # end

        halt 200, "Status updated to {#{query_string}}"

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
            # puts 'ns: ', new_ns.to_json
            # puts 'new_ns id', new_ns['_id'].to_json
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
        # begin
        #	  postcurb settings.nsd_validator + '/nsds', nsd.to_json, :content_type => :json
        # rescue => e
        #	  logger.error e.response
        #	  return e.response.code, e.response.body
        # end

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
  delete '/tests/?' do
    uri = Addressable::URI.new
    uri.query_values = params
    # puts 'params', params
    # puts 'query_values', uri.query_values
    logger.info "Catalogue: entered DELETE /network-services?#{uri.query}"

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)
    # puts 'keyed_params', keyed_params

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
  #	  Delete a NS by its ID
  #	  @param :id [Symbol] unique identifier
  # Delete a NS by uuid
  delete '/tests/:id/?' do
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
end