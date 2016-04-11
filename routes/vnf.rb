=begin
APIDOC comment
=end

# @see VNFRepository
class SonataVnfRepository < Sinatra::Application

  #@@vnfr_schema=JSON.parse(JSON.dump(YAML.load_file("#{settings.root}/schemas/vnfr_schema.yml")))  
  @@vnfr_schema=JSON.parse(JSON.dump(YAML.load(open('https://github.com/sonata-nfv/son-schema/blob/master/function-record/vnfr-schema.yml'){|f| f.read})))

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

	# @method get_root
 	# @overload get '/'
	get '/' do
    	headers "Content-Type" => "text/plain; charset=utf8"
		halt 200, interfaces_list.to_yaml
	end
	
	# @method get_log
	# @overload get '/vnf-instances/log'
	#	Returns contents of log file
	# Management method to get log file of repository remotely
	get '/vnf-instances/log' do
		filename = 'log/development.log'

		# For testing purposes only
		begin
			txt = open(filename)

		rescue => err
			logger.error "Error reading log file: #{err}"
			return 500, "Error reading log file: #{err}"
		end

		return 200, txt.read.to_s
	end

	# @method get_vnfs
	# @overload get '/vnf-instances'
	#	Returns a list of VNFRs
	# List all VNFRs
	get '/vnf-instances' do
		params[:offset] ||= 1
		params[:limit] ||= 10

		# Only accept positive numbers
		params[:offset] = 1 if params[:offset].to_i < 1
		params[:limit] = 2 if params[:limit].to_i < 1

		# Get paginated list
		vnfs = Vnfr.paginate(:page => params[:offset], :limit => params[:limit])
		logger.debug(vnfs)
		# Build HTTP Link Header
		headers['Link'] = build_http_link(params[:offset].to_i, params[:limit])

		begin
			vnfs_json = vnfs.to_json
			vnfs_yml = json_to_yaml(vnfs_json)
		rescue
			logger.error "Error Establishing a Database Connection"
			return 500, "Error Establishing a Database Connection"
		end

		return 200, vnfs_yml
	end

	# @method get_vnfr_external_vnf_version
	# @overload get '/vnf-instances/:external_vnfr_name/version/:version'
	#	Show a vnf
	#	@param [String] external_vnf_name VNF external Name
	# Show a vnf name
	#	@param [Integer] external_vnf_version VNF version
	# Show a vnf version
	get '/vnf-instances/name/:external_vnf_name/version/:version' do
		begin
			vnf = Vnfr.find_by( { "vnfr.properties.name" =>  params[:external_vnf_name], "vnfr.properties.version" => params[:version]})
		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end

		vnf_json = Vnfr.vnfr.to_json
		vnf_yml = json_to_yaml(vnf_json)
		return 200, vnf_yml
	end

	# @method get_vnfr_external_vnf_last_version
	# @overload get '/vnf-instances/:external_vnfr_name/last'
	#	Show a VNF last version
	#	@param [String] external_vnfr_name vnf external Name
	# Show a VNFR name
	get '/vnf-instances/name/:external_vnfr_name/last' do

		# Search and get all items of vnf by name
		begin
			puts 'params', params
			
			vnf = Vnfr.where({"vnf.properties.name" => params[:external_vnf_name]}).sort({"vnf.properties.version" => -1}).limit(1).first()
			puts 'VNF: ', vnf

			if vnf == nil
				logger.error "ERROR: vnfr not found"
				return 404
			end

		rescue Mongoid::Errors::DocumentNotFound => e
			logger.error e
			return 404
		end

		vnf_json = vnf.to_json
		puts 'VNF: ', vnf_json

		vnf_yml = json_to_yaml(vnf_json)
		return 200, vnf_yml

		
	end

	# @method post_vnfrs
	# @overload post '/vnf-instances'
	# Post a VNF in YAML format
	# @param [YAML] VNF in YAML format
	# Post a vnfr
	post '/vnf-instances' do
		# Return if content-type is invalid
		return 415 unless request.content_type == 'application/x-yaml'

		# Validate YAML format
		vnf, errors = parse_yaml(request.body.read)

		return 400, errors.to_json if errors


		vnf_json = yaml_to_json(vnf)


		vnf, errors = parse_json(vnf_json)
		puts 'vnf: ', Vnfr.to_json
		errors = validate_json(vnf_json,@@vnfr_schema)
		return 400, errors.to_json if errors

		return 400, 'ERROR: vnfr not found' unless vnf.has_key?('vnfr')

		

		begin
			vnf = Vnfr.find_by( { "vnfr.id" =>  vnf['vnfr']['id'] })
			#, "nsr.properties.version" => ns['nsr']['properties']['version'],"nsr.properties.vendor" => ns['nsr']['properties']['vendor']})
			return 400, 'ERROR: Duplicated VNF ID'
		rescue Mongoid::Errors::DocumentNotFound => e
		end

		# Save to DB
		begin
			new_vnf = Vnfr.create!(vnf)
		rescue Moped::Errors::OperationFailure => e
			return 400, 'ERROR: Duplicated VNF ID' if e.message.include? 'E11000'
		end

		puts 'New VNF has been added'
		vnf_json = new_vnf.to_json
		vnf_yml = json_to_yaml(vnf_json)
		return 200, vnf_yml
	end

	# @method delete_vnfr_external_vnf_id
	# @overload delete '/vnf-instances/:external_vnf_id'
	#	Delete a vnf by its ID
	#	@param [Integer] external_vnf_id vnf external ID
	# Delete a vnf
	delete '/vnf-instances/id/:external_vnf_id' do
		begin
			vnf = Vnfr.find_by( { "vnfr.id" =>  params[:external_vnf_id]})
		rescue Mongoid::Errors::DocumentNotFound => e
			return 404,'ERROR: Operation failed'
		end
		vnf.destroy
		return 200, 'OK: vnfr removed'
	end


end