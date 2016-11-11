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
  get '/tests' do
    headers 'Content-Type' => 'text/plain; charset=utf8'
    result = 'This is a test'
    halt 200, result.to_yaml
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
    json_error 400, 'ERROR: NS Vendor not found' unless new_ns.has_key?('vendor')
    json_error 400, 'ERROR: NS Name not found' unless new_ns.has_key?('name')
    json_error 400, 'ERROR: NS Version not found' unless new_ns.has_key?('version')

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
      new_nsd = {}
      # Generate the UUID for the descriptor
      new_nsd['nsd'] = new_ns
      new_nsd['_id'] = SecureRandom.uuid
      new_nsd['status'] = 'active'
      ns = Ns.create!(new_nsd)
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
end