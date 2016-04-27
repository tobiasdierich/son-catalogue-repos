# Class for Sonata_NS_Repository
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

  def build_http_link(offset, limit)
    link = ''
    # Next link
    next_offset = offset + 1
    next_nsr = Nsr.paginate(:page => next_offset, :limit => limit)
    begin
      link << '<' + address.to_s + ':' + port.to_s + '/records/nsr?offset=' + next_offset.to_s + '&limit=' + limit.to_s + '>; rel="next"' unless next_nsr.empty?
    rescue
      logger.error 'Error Establishing a Database Connection'
    end

    unless offset == 1
      # Previous link
      previous_offset = offset - 1
      previous_nsr = Nsr.paginate(:page => previous_offset, :limit => limit)
      unless previous_nsr.empty?
        link << ', ' unless next_nsr.empty?
        link << '<' + address.to_s + ':' + port.to_s + '/records/nsr?offset=' + previous_offset.to_s + '&limit=' + limit.to_s + '>; rel="last"'
      end
    end
    link
  end

  def json_to_yaml(input_json)
    require 'json'
    require 'yaml'

    begin
      output_yml = YAML.dump(JSON.parse(input_json))
    rescue
      logger.error 'Error parsing from JSON to YAML'
    end
  return output_yml
  end

  def interfaces_list
    [
      {
        'uri' => '/records/nsr/',
        'method' => 'GET',
        'purpose' => 'REST API Structure and Capability Discovery /records/nsr/'
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
