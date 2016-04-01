class Sonata < Sinatra::Application

	# @method get_log
	# @overload get '/network-services/log'
	#	Returns contents of log file
	# Management method to get log file of catalogue remotely
	get '/log' do
    	headers "Content-Type" => "text/plain; charset=utf8"
		filename = 'log/development.log'

		# For testing purposes only
		begin
			txt = open(filename)

		rescue => err
			logger.error "Error reading log file: #{err}"
			return 500, "Error reading log file: #{err}"
		end

		#return 200, nss.to_json
		return 200, txt.read.to_s
	end


	# @method get_root
	# @overload get '/'
	# Get all available interfaces
	# -> Get all interfaces
	get '/' do
    	headers "Content-Type" => "text/plain; charset=utf8"
		halt 200, api_routes.to_yaml
	end

	get '/records' do
    	headers "Content-Type" => "text/plain; charset=utf8"
		halt 200, api_routes.to_yaml
	end
end
