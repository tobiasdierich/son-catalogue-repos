# This Class is the Class of Sonata Ns Repository
class SonataNsRepository < Sinatra::Application
  # @method get_root
  # @overload get '/'
  get '/' do
    headers 'Content-Type' => 'text/plain; charset=utf8'
    halt 200, interfaces_list.to_yaml
  end

  # @method get_ns-instances
  # @overload get "/ns-instances"
  # Gets all ns-instances
  get '/ns-instances' do
    if params[:status]
      @nsInstances = Nsr.where(:status => params[:status])
    else
      @nsInstances = Nsr.all
    end
    return @nsInstances.to_json
  end

  # @method get_ns-instances
  # @overload get "/ns-instances"
  # Gets ns-instances with an id

  get '/ns-instances/:id' do
    begin
      @nsInstance = Nsr.find(params[:id])
        rescue Mongoid::Errors::DocumentNotFound => e
          halt(404)
        end
    return @nsInstance.to_json
  end

  # Method post_ns-instances
  # @overload post "/ns-instances"
  # Post a new ns-instances information

  post '/ns-instances' do
    return 415 unless request.content_type == 'application/json'
    # Validate JSON format
    instance, errors = parse_json(request.body.read)
    return 400, errors.to_json if errors
    begin
      instance = Nsr.find({ '_id' => instance['_id'] })
      return 400, 'ERROR: Duplicated NS ID'
    rescue Mongoid::Errors::DocumentNotFound => e
    end

    begin
      instance = Nsr.create!(instance)
    rescue Moped::Errors::OperationFailure => e
      return 400, 'ERROR: Duplicated NS ID' if e.message.include? 'E11000'
    end
    return 200, instance.to_json
  end

  put '/ns-instances/:id' do
    # Return if content-type is invalid
    415 unless request.content_type == 'application/json'
    # Validate JSON format
    instance, errors = parse_json(request.body.read)
    return 400, errors.to_json if errors
    # Retrieve stored version
    new_nsr = instance
      begin
        nsr = Nsr.find_by( { "_id" =>  params[:id] })
			puts 'NS is found'
		rescue Mongoid::Errors::DocumentNotFound => e
			return 400, 'This NSD does not exists'
		end

		# Update to new version
		puts 'Updating...'
		begin
			#Delete old record
			Nsr.where( { "_id" => params[:id] }).delete
			#Create a record
			new_nsr = Nsr.create!(instance)
		rescue Moped::Errors::OperationFailure => e
			return 400, 'ERROR: Duplicated NS ID' if e.message.include? 'E11000'
		end

		nsr_json = new_nsr.to_json
		return 200, nsr_json
		#return 200, new_ns.to_json
	end

end
