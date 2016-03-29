=begin
APIDOC comment
=end

class SonataNsRepository < Sinatra::Application

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
			halt (404)
		end
		return @nsInstance.to_json
	end


  # @method post_ns-instances
  # @overload post "/ns-instances"
  # Post a new ns-instances information

	post '/ns-instances' do
		return 415 unless request.content_type == 'application/json'

		instance, errors = parse_json(request.body.read)
		return 400, errors.to_json if errors

		begin
			instance = Nsr.find( { "_id" =>  instance['_id'] })
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

end
