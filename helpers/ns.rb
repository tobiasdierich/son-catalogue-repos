class SonataNsRepository < Sinatra::Application

  require 'json'
  require 'yaml'
  
	# Checks if a JSON message is valid
	#
	# @param [JSON] message some JSON message
	# @return [Hash, nil] if the parsed message is a valid JSON
	# @return [Hash, String] if the parsed message is an invalid JSON
	def parse_json(message)
		# Check JSON message format
		begin
			parsed_message = JSON.parse(message) # parse json message
		rescue JSON::ParserError => e
			# If JSON not valid, return with errors
			logger.error "JSON parsing: #{e.to_s}"
			return message, e.to_s + "\n"
		end

		return parsed_message, nil
	end

	def interfaces_list
		[
				{
						'uri' => '/records/nsr/',
						'method' => 'GET',
						'purpose' => 'REST API Structure and Capability Discovery for /records/nsr/'
				},
				{
						'uri' => '/records/nsr/ns-instances',
						'method' => 'GET',
						'purpose' => 'List all NSR'
				},
				{
						'uri' => '/records/nsr/ns-instances/:id',
						'method' => 'GET',
						'purpose' => 'List specific NSR'
				},
				{
						'uri' => '/records/nsr/ns-instances',
						'method' => 'POST',
						'purpose' => 'Store a new NSR'
				}
		]
	end

end
