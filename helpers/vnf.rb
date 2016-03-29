
# @see VNFRepository
class SonataVnfRepository < Sinatra::Application

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

	# Checks if a JSON message is valid acording to a json_schema
	#
	# @param [JSON] message some JSON message
	# @return [Hash, nil] if the parsed message is a valid JSON
	# @return [Hash, String] if the parsed message is an invalid JSON

	def validate_json(json_message,schema)
		begin
		       JSON::Validator.validate!(schema,json_message)
		rescue JSON::Schema::ValidationError => e
			logger.error "JSON validating: #{e.to_s}"
			return e.to_s + "\n"
		end
		return nil
	end
  # Checks if a YAML message is valid
  #
  # @param [YAML] message some YAML message
  # @return [Hash, nil] if the parsed message is a valid YAML
  # @return [Hash, String] if the parsed message is an invalid YAML
   def parse_yaml(message)
    # Check YAML message format
    begin
      parsed_message = YAML.load(message) # parse YAML message
      #puts 'PARSED_MESSAGE: ', parsed_message.to_yaml
    rescue YAML::ParserError => e
      # If YAML not valid, return with errors
      logger.error "YAML parsing: #{e.to_s}"
      return message, e.to_s + "\n"
    end

    return parsed_message, nil
  end

  
  
  # Translates a message from YAML to JSON
  #
  # @param [YAML] input_yml some YAML message
  # @return [Hash, nil] if the input message is a valid YAML
  # @return [Hash, String] if the input message is an invalid YAML
	def yaml_to_json(input_yml)
    #puts input_yml.to_s
    puts 'Parsing from YAML to JSON'

		begin
			#output_json = JSON.dump(YAML::load(input_yml))
      #puts 'input: ', input_yml.to_json
      output_json = JSON.dump(input_yml)
      #output_json = JSON.dump(input_yml.to_json)
		rescue
			logger.error "Error parsing from YAML to JSON"
			end

    puts 'Parsing DONE', output_json
	return output_json
	end

  # Translates a message from JSON to YAML
  #
  # @param [JSON] input_json some JSON message
  # @return [Hash, nil] if the input message is a valid JSON
  # @return [Hash, String] if the input message is an invalid JSON
	def json_to_yaml(input_json)
		require 'json'
		require 'yaml'

		begin
			output_yml = YAML.dump(JSON.parse(input_json))
		rescue
			logger.error "Error parsing from JSON to YAML"
			end

		return output_yml
	end

  # Builds an HTTP link for pagination
	#
	# @param [Integer] offset link offset
	# @param [Integer] limit link limit position
	def build_http_link(offset, limit)
		link = ''
		# Next link
		next_offset = offset + 1
		next_vnfs = Vnf.paginate(:page => next_offset, :limit => limit)
		begin
			link << '<localhost:4011/virtual-network-functions?offset=' + next_offset.to_s + '&limit=' + limit.to_s + '>; rel="next"' unless next_vnfs.empty?
		rescue
			logger.error "Error Establishing a Database Connection"
		end

		unless offset == 1
			# Previous link
			previous_offset = offset - 1
			previous_vnfs = Vnf.paginate(:page => previous_offset, :limit => limit)
			unless previous_vnfs.empty?
				link << ', ' unless next_vnfs.empty?
				link << '<localhost:4011/virtual-network-functions?offset=' + previous_offset.to_s + '&limit=' + limit.to_s + '>; rel="last"'
			end
		end
		link
	end

	# Extension of build_http_link
	def build_http_link_name(offset, limit, name)
		link = ''
		# Next link
		next_offset = offset + 1
		next_vnfs = Vnf.paginate(:page => next_offset, :limit => limit)
		begin
			link << '<localhost:4011/virtual-network-functions/name/' + name.to_s + '?offset=' + next_offset.to_s + '&limit=' + limit.to_s + '>; rel="next"' unless next_vnfs.empty?
		rescue
			logger.error "Error Establishing a Database Connection"
		end

		unless offset == 1
			# Previous link
			previous_offset = offset - 1
			previous_vnfs = Vnf.paginate(:page => previous_offset, :limit => limit)
			unless previous_vnfs.empty?
				link << ', ' unless next_vnfs.empty?
				link << '<localhost:4011/virtual-network-functions/name/' + name.to_s + '?offset=' + previous_offset.to_s + '&limit=' + limit.to_s + '>; rel="last"'
			end
		end
		link
	end
	
end
