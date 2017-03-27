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

require 'json'
require 'yaml'
require 'jwt'
require 'sinatra'
require 'net/http'
require 'uri'

# Sonata class for API routes
class Sonata < Sinatra::Application
  require 'json'
  require 'yaml'

  # Root routes
  def api_routes
    [
      {
        'uri' => '/',
        'method' => 'GET',
        'purpose' => 'REST API Structure and Capability Discovery'
      },
      {
        'uri' => '/records/nsr/',
        'method' => 'GET',
        'purpose' => 'REST API Structure and Capability Discovery nsr'
      },
      {
        'uri' => '/records/vnfr/',
        'method' => 'GET',
        'purpose' => 'REST API Structure and Capability Discovery vnfr'
      },
      {
        'uri' => '/catalogues/',
        'method' => 'GET',
        'purpose' => 'REST API Structure and Capability Discovery catalogues'
      }
  ]
  end
end

def parse_json(message)
  # Check JSON message format
  begin
    parsed_message = JSON.parse(message)
  rescue JSON::ParserError => e
    # If JSON not valid, return with errors
    return message, e.to_s + "\n"
  end
  return parsed_message, nil
end

def get_public_key(address, port)
  #TODO: Check failures
  # p "ADDRESS_PORT", address, port
  url = URI("http://#{address}:#{port}/api/v1/public-key")
  #url = URI("http://127.0.0.1:9292/api/v1/public-key")
  http = Net::HTTP.new(url.host, url.port)
  request = Net::HTTP::Get.new(url)
  response = http.request(request)
  # puts response.read_body

  # p "RESPONSE", response.body
  # p "CODE", response.code

  if response.code.to_i != 200
    raise 'Error: Public key not available'
  else
    # Writes the Keycloak public key to a config file
    File.open('config/public_key.txt', 'w') do |f|
      f.puts response.body
    end
    puts "Keycloak PUBLIC_KEY saved"  #, response.body.to_s
    response.body
  end
end

def register_service(address, port)
  #TODO: Check failures
  # READ REGISTRATION FROM CONFIG_FORM
  catalogue_reg = JSON.parse(File.read('config/catalogue_registration.json'))
  # repos_reg = JSON.parse(File.read('config/repos_registration.json'))
  # puts "CATALOGUE_REG_FORM", catalogue_reg

  url = URI("http://#{address}:#{port}/api/v1/register/service")
  # url = URI("http://127.0.0.1:9292/api/v1/register/service")
  http = Net::HTTP.new(url.host, url.port)
  request = Net::HTTP::Post.new(url)
  request["content-type"] = 'application/json'

  request.body = catalogue_reg.to_json
  response = http.request(request)
  # puts "CODE", response.code
  # puts "BODY", response.body
  if response.code.to_i != '201'
    return
    #raise 'Error: registration failure'
    # handle 409, {"error":"{\"errorMessage\":\"Client son-catalogue already exists\"}"}
  else
    puts "SON-CATALOGUE Service client: Registered"
    return # Return an OK?
  end
end

def login_service(address, port)
  adapter_yml = YAML.load_file('config/adapter.yml')
  url = URI("http://#{address}:#{port}/api/v1/login/service")
  http = Net::HTTP.new(url.host, url.port)
  request = Net::HTTP::Post.new(url)
  request.basic_auth(adapter_yml['catalogue_client'], adapter_yml['catalogue_secret'])
  # request.basic_auth(adapter_yml[repos_client], adapter_yml[repos_secret])
  response = http.request(request)
  # p "RESPONSE", response.body
  # p "CODE", response.code

  if response.code.to_i != ''
    parsed_res, errors = parse_json(response.body)
    # puts "PARSED_RES", parsed_res
    # Write access token
    File.open('config/catalogue_token.json', 'w') do |f|
      # File.open('config/repos_token.json', 'w') do |f|
      f.puts parsed_res['access_token']
      #f.puts response.body # .to_json
    end
    puts "SON-CATALOGUE Service client: Logged-in"
  else
    raise 'Error: login failure'
  end
end

#def authorized?(address, port, token)
# TODO: CHECK IF A PROVIDED TOKEN IS VALID
#end

def check_token(address, port, keycloak_pub_key)
  #p uts "CHECKING ACCESS TOKEN"
  #=> READ TOKEN, READ PUBLIC KEY
  catalogue_token = (File.read('config/catalogue_token.json'))
  #catalogue_token = JSON.parse(File.read('config/catalogue_token.json'))
  #=> Check if token.expired?
  code = decode_token(catalogue_token, keycloak_pub_key)
  case code
    when 'OK'
      puts "Catalogue Access Token: OK"
      return
    else
      #=> Then GET new token
      puts "Catalogue Access Token: REFRESHING..."
      login_service(address, port)
  end
end

def decode_token(token, pub_key)
  # puts "TOKEN", token
  # puts "PUB", pub_key

  begin
    decoded_payload, decoded_header = JWT.decode token, pub_key, true, { :algorithm => 'RS256' }
    # puts "DECODED_HEADER: ", decoded_header
    # puts "DECODED_PAYLOAD: ", decoded_payload
    response = 'OK'
      # if expired token, refresh token
  rescue JWT::DecodeError
    response = 'DecodeError'
  rescue JWT::ExpiredSignature
    response = 'ExpiredSignature'
  rescue JWT::InvalidIssuerError
    response = 'InvalidIssuerError'
  rescue JWT::InvalidIatError
    response = 'InvalidIatError'
  end
end

