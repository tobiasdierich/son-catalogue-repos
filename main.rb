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

# Set environment
ENV['RACK_ENV'] ||= 'production'

require 'sinatra'
require 'sinatra/config_file'
require 'yaml'
require 'json-schema'
require 'open-uri'

# Require the bundler gem and then call Bundler.require to load in all gems
# listed in Gemfile.
require 'bundler'
Bundler.require :default, ENV['RACK_ENV'].to_sym

require_relative 'models/init'
require_relative 'routes/init'
require_relative 'helpers/init'

configure do
  # Configuration for logging
  enable :logging
  Dir.mkdir("#{settings.root}/log") unless File.exist?("#{settings.root}/log")
  log_file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
  log_file.sync = true
  use Rack::CommonLogger, log_file

  # SECURITY FUNCTIONS CAN BE TEMPORARY DISABLED!
  # Configuration for Authentication and Authorization layer
  conf = YAML::load_file("#{settings.root}/config/adapter.yml")
  set :auth_address, conf['address']
  set :auth_port, conf['port']
  set :api_ver, conf['api_ver']
  set :pub_key_path, conf['public_key_path']
  set :reg_path, conf['registration_path']
  set :login_path, conf['login_path']
  set :authz_path, conf['authorization_path']
  set :access_token, nil

  # turn keycloak realm pub key into an actual openssl compat pub key.
  # keycloak_key = get_public_key(settings.auth_address, settings.auth_port, settings.api_ver, settings.pub_key_path)
  # keycloak_key, errors = parse_json(keycloak_key)
  # puts keycloak_key['public-key']
  # @s = "-----BEGIN PUBLIC KEY-----\n"
  # @s += keycloak_key['public-key'].scan(/.{1,64}/).join("\n")
  # @s += "\n-----END PUBLIC KEY-----\n"
  # @key = OpenSSL::PKey::RSA.new @s
  # set :keycloak_pub_key, @key
  # puts "Keycloak public key: ", settings.keycloak_pub_key

  # register_service(settings.auth_address, settings.auth_port, settings.api_ver, settings.reg_path)
  # access_token = login_service(settings.auth_address, settings.auth_port, settings.api_ver, settings.login_path)
  # if access_token
  #   set :access_token, access_token
  # end
end

before do
  logger.level = Logger::DEBUG
  # SECURITY CHECKS ARE TEMPORARY DISABLED!
  # status = decode_token(settings.keycloak_pub_key, settings.access_token)
  # login_service(settings.auth_address, settings.auth_port, settings.api_ver, settings.login_path) unless status

  # Get authorization token
  #if request.env["HTTP_AUTHORIZATION"] != nil
    #puts "AUTH HEADER", request.env["HTTP_AUTHORIZATION"]
    #provided_token = request.env["HTTP_AUTHORIZATION"].split(' ').last
    #unless provided_token
      #error = {"ERROR" => "Access token is not provided"}
      #halt 400, error.to_json
    #else
      #puts "CHECK provided_token IN GATEKEEPER??"
    #end
  #else
    #error = {"ERROR" => "Unauthorized"}
    #halt 401, error.to_json
  #end
end

# Configurations for Services Repository
class SonataNsRepository < Sinatra::Application
  register Sinatra::ConfigFile
  # Load configurations
  config_file 'config/config.yml'
  Mongoid.load!('config/mongoid.yml')
end

# Configurations for Functions Repository
class SonataVnfRepository < Sinatra::Application
  register Sinatra::ConfigFile
  # TODO: Enable option to load extra config files for mongo
  # Load configurations
  config_file 'config/config.yml'
  Mongoid.load!('config/mongoid.yml')
end

# Configurations for Catalogues
class SonataCatalogue < Sinatra::Application
  register Sinatra::ConfigFile
  # Load configurations
  config_file 'config/config.yml'
  Mongoid.load!('config/mongoid.yml')
  # use Rack::CommonLogger,
  # LogStashLogger.new(host: settings.logstash_host, port: settings.logstash_port)
end
