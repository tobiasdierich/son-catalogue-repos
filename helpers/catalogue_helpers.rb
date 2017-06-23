# coding: utf-8
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
  require 'json'
  require 'yaml'
  require 'digest/md5'
  require 'jwt'
  require 'zip'
  require 'pathname'

  # Read config settings from config file
  # @return [String, Integer] the address and port of the API
  def read_config
    begin
      config = YAML.load_file('config/config.yml')
      puts config['address']
      puts config['port']
    rescue YAML::LoadError => e
      # If config file is not found or valid, return with errors
      logger.error "read config error: #{e}"
    end

    return config['address'], config['port']
  end

  # Checks if a JSON message is valid
  # @param [JSON] message some JSON message
  # @return [Hash, nil] if the parsed message is a valid JSON
  # @return [Hash, String] if the parsed message is an invalid JSON
  def parse_json(message)
    # Check JSON message format
    begin
      parsed_message = JSON.parse(message) # parse json message
    rescue JSON::ParserError => e
      # If JSON not valid, return with errors
      logger.error "JSON parsing: #{e}"
      return message, e.to_s + "\n"
    end

    return parsed_message, nil
  end

  # Checks if a YAML message is valid
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
      logger.error "YAML parsing: #{e}"
      return message, e.to_s + "\n"
    end

    return parsed_message, nil
  end

  # Translates a message from YAML to JSON
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
      logger.error 'Error parsing from YAML to JSON'
    end

    #puts 'Parsing DONE', output_json
    output_json
  end

  # Translates a message from JSON to YAML
  # @param [JSON] input_json some JSON message
  # @return [Hash, nil] if the input message is a valid JSON
  # @return [Hash, String] if the input message is an invalid JSON
  def json_to_yaml(input_json)
    require 'json'
    require 'yaml'

    begin
      output_yml = YAML.dump(JSON.parse(input_json))
    rescue
      logger.error 'Error parsing from JSON to YAML'
    end

    output_yml
  end

  def apply_limit_and_offset(input, offset= nil, limit= nil)
    @result = input
    @result = offset ? input.drop(offset.to_i) : @result
    @result = limit ? @result.first(limit.to_i) : @result
  end

  # Builds an HTTP link for pagination
  # @param [Integer] offset link offset
  # @param [Integer] limit link limit position
  def build_http_link_ns(offset, limit)
    link = ''
    # Next link
    next_offset = offset + 1
    next_nss = Ns.paginate(page: next_offset, limit: limit)

    address, port = read_config

    begin
      link << '<' + address.to_s + ':' + port.to_s + '/catalogues/network-services?offset=' + next_offset.to_s +
          '&limit=' + limit.to_s + '>; rel="next"' unless next_nss.empty?
    rescue
      logger.error 'Error Establishing a Database Connection'
    end

    unless offset == 1
      # Previous link
      previous_offset = offset - 1
      previous_nss = Ns.paginate(page: previous_offset, limit: limit)
      unless previous_nss.empty?
        link << ', ' unless next_nss.empty?
        link << '<' + address.to_s + ':' + port.to_s + '/catalogues/network-services?offset=' + previous_offset.to_s +
            '&limit=' + limit.to_s + '>; rel="last"'
      end
    end
    link
  end

  # Builds an HTTP pagination link header
  # @param [Integer] offset the pagination offset requested
  # @param [Integer] limit the pagination limit requested
  # @return [String] the built link to use in header
  def build_http_link_vnf(offset, limit)
    link = ''
    # Next link
    next_offset = offset + 1
    next_vnfs = Vnf.paginate(page: next_offset, limit: limit)

    address, port = read_config

    link << '<' + address.to_s + ':' + port.to_s + '/catalogues/vnfs?offset=' + next_offset.to_s + '&limit=' +
        limit.to_s + '>; rel="next"' unless next_vnfs.empty?

    unless offset == 1
      # Previous link
      previous_offset = offset - 1
      previous_vnfs = Vnf.paginate(page: previous_offset, limit: limit)
      unless previous_vnfs.empty?
        link << ', ' unless next_vnfs.empty?
        link << '<' + address.to_s + ':' + port.to_s + '/catalogues/vnfs?offset=' + previous_offset.to_s +
            '&limit=' + limit.to_s + '>; rel="last"'
      end
    end
    link
  end

  # Extension of build_http_link
  def build_http_link_ns_name(offset, limit, name)
    link = ''
    # Next link
    next_offset = offset + 1
    next_nss = Ns.paginate(page: next_offset, limit: limit)
    address, port = read_config

    begin
      link << '<' + address.to_s + ':' + port.to_s + '/catalogues/network-services/name/' + name.to_s +
          '?offset=' + next_offset.to_s + '&limit=' + limit.to_s + '>; rel="next"' unless next_nss.empty?
    rescue
      logger.error 'Error Establishing a Database Connection'
    end

    unless offset == 1
      # Previous link
      previous_offset = offset - 1
      previous_nss = Ns.paginate(page: previous_offset, limit: limit)
      unless previous_nss.empty?
        link << ', ' unless next_nss.empty?
        link << '<' + address.to_s + ':' + port.to_s + '/catalogues/network-services/name/' + name.to_s +
            '?offset=' + previous_offset.to_s + '&limit=' + limit.to_s + '>; rel="last"'
      end
    end
    link
  end

  def checksum(contents)
    result = Digest::MD5.hexdigest contents #File.read
    result
  end

  def keyed_hash(hash)
    Hash[hash.map { |(k, v)| [k.to_sym, v] }]
  end

  def add_descriptor_level(descriptor_type, parameters)
    new_parameters = {}
    meta_data = %w(offset limit _id uuid status signature md5 updated_at created_at)
    parameters.each { |k, v|
      if meta_data.include? k
        if k == 'uuid'
          new_parameters.store( '_id', v)
        else
          new_parameters.store( k, v)
        end
      else
        new_parameters.store((descriptor_type.to_s + '.' + k), v)
      end
    }
    parameters = keyed_hash(new_parameters)
  end

  class Pair
    attr_accessor :one, :two

    def initialize(one, two)
      @one = one
      @two = two
    end
  end

  # Method that returns an error code and a message in json format
  def json_error(code, message)
    msg = {'error' => message}
    logger.error msg.to_s
    halt code, {'Content-type' => 'application/json'}, msg.to_json
  end

  # Method that returns a code and a message in json format
  def json_return(code, message)
    msg = {'OK' => message}
    logger.info msg.to_s
    halt code, {'Content-type' => 'application/json'}, msg.to_json
  end

  def getcurb(url, headers={})
    Curl.get(url) do |req|
      req.headers = headers
    end
  end

  def postcurb(url, body)
    Curl.post(url, body) do |req|
      req.headers['Content-type'] = 'application/json'
      req.headers['Accept'] = 'application/json'
    end
  end

  # Check if it's a valid dependency mapping descriptor
  # @param [Hash] desc The descriptor
  # @return [Boolean] true if descriptor contains name-vendor-version info
  def valid_dep_mapping_descriptor?(desc)
    (desc['name'] && desc['vendor'] && desc['version'])
  end

  # Rebuild and evaluate the package in order to generate
  #     the dependencies mapping record name-vendor-version based;
  #     Supported sonata package descriptor files:
  #     https://github.com/sonata-nfv/son-schema/tree/master/package-descriptor
  #     also expected a directory 'service_descriptors' holding the nsds
  #     and a 'function_descriptos' folder containing the vnfds
  # @param [StringIO] sonpfile The sonata package file contents
  # @param [String] sonp_id The sonata package file id
  # @return [Hash] Document containing the dependencies mapping
  def son_package_dep_mapping(sonpfile, sonp_id)
    mapping = { pd: {}, nsds: [], vnfds: [], deps: [] }
    Zip::InputStream.open(sonpfile) do |io|
      while (entry = io.get_next_entry)
        dirname = Pathname(File.path(entry.name)).split.first.to_s
        if dirname.casecmp('META-INF') == 0
          if File.basename(entry.name).casecmp('MANIFEST.MF') == 0
            desc, errors = parse_yaml(io.read)
            if valid_dep_mapping_descriptor? desc
              mapping[:pd] = { vendor: desc['vendor'],
                               version: desc['version'],
                               name: desc['name'] }
              if !desc['package_dependencies'].nil?
                desc['package_dependencies'].each do |pdep|
                  if valid_dep_mapping_descriptor? pdep
                    mapping[:deps] << { vendor: pdep['vendor'],
                                        version: pdep['version'],
                                        name: pdep['name'] }
                  end
                end
              end
            end
          end
        elsif dirname.casecmp('SERVICE_DESCRIPTORS') == 0
          if !entry.name_is_directory?
            desc, errors = parse_yaml(io.read)
            if valid_dep_mapping_descriptor? desc
              mapping[:nsds] << { vendor: desc['vendor'],
                                  version: desc['version'],
                                  name: desc['name'] }
            end
          end
        elsif dirname.casecmp('FUNCTION_DESCRIPTORS') == 0
          if !entry.name_is_directory?
            desc, errors = parse_yaml(io.read)
            if valid_dep_mapping_descriptor? desc
              mapping[:vnfds] << { vendor: desc['vendor'],
                                   version: desc['version'],
                                   name: desc['name'] }
            end
          end
        end
      end
    end
    mapping_id = SecureRandom.uuid
    mapping['_id'] = mapping_id
    mapping['son_package_uuid'] = sonp_id
    mapping
  end

  # Method returning packages depending on a descriptor
  # @param [Symbol] desc_type descriptor type (:vnfds, :nsds, :deps)
  # @param [Hash] desc descriptor
  # @return [Dependencies_mapping] Documents
  def check_dependencies(desc_type, desc)
    name = desc[:name]
    version = desc[:version]
    vendor = desc[:vendor]
    dependent_packages = Dependencies_mapping.where(
      {desc_type => { '$elemMatch' => { name: name,
                                        vendor: vendor,
                                        version: version } } })
    return dependent_packages
  end

  # Method returning boolean depending if there's some instance of a descriptor
  # @param [Symbol] desc_type descriptor type (:vnfd, :nsd)
  # @param [Hash] descriptor descriptor
  # @return [Boolean] true/false
  def instantiated_descriptor?(desc_type, descriptor)
    if desc_type == :vnfd
      desc = Vnfd.where({ 'vnfd.name' => descriptor['name'],
                          'vnfd.vendor' => descriptor['vendor'],
                          'vnfd.version' => descriptor['version'] }).first
      instances = Vnfr.where({ 'descriptor_reference' => desc['_id'] }).count
    elsif desc_type == :nsd
      desc = Nsd.where({ 'nsd.name' => descriptor['name'],
                         'nsd.vendor' => descriptor['vendor'],
                         'nsd.version' => descriptor['version'] }).first
      instances = Nsr.where({ 'descriptor_reference' => desc['_id'] }).count
    end
    if instances > 0
      return true
    end
    return false
  end

  # Method returning Hash containing Vnfds and Nsds that can safely be deleted
  #     with no dependencies on other packages
  # @param [Pkgd] package package model instance
  # @return [Hash] vnfds and nsds arrays
  def intelligent_delete_nodeps(package)
    vnfds = []
    nsds = []
    begin
      pdep_mapping = Dependencies_mapping.find_by({ 'pd.name' => package.pd['name'],
                                                    'pd.version' => package.pd['version'],
                                                    'pd.vendor' => package.pd['vendor'] })
    rescue Mongoid::Errors::DocumentNotFound => e
      logger.error 'Dependencies not found: ' + e.message
      # If no document found, avoid to delete descriptors blindly
      return { vnfds: [], nsds: [] }
    end
    pdep_mapping.vnfds.each do |vnfd|
      if check_dependencies(:vnfds, vnfd).length > 1
        logger.info 'VNFD ' + vnfd[:name] + ' has more than one dependency'
      else
        vnfds << vnfd unless instantiated_descriptor?(:vnfd, vnfd)
      end
    end
    pdep_mapping.nsds.each do |nsd|
      if check_dependencies(:nsds, nsd).length > 1
        logger.info 'NSD ' + nsd[:name] + ' has more than one dependency'
      else
        nsds << nsd unless instantiated_descriptor?(:nsd, nsd)
      end
    end
    { vnfds: vnfds, nsds: nsds }
  end

  # Method deleting vnfds from name, vendor, version
  # @param [Array] vnfds array of hashes
  # @return [Array] Not found array
  def delete_vnfds(vnfds)
    not_found = []
    vnfds.each do |vnfd_td|
      descriptor = Vnfd.where({ 'vnfd.name' => vnfd_td['name'],
                                'vnfd.vendor' => vnfd_td['vendor'],
                                'vnfd.version' => vnfd_td['version'] }).first
      if descriptor.nil?
        logger.error 'VNFD Descriptor not found'
        not_found << vnfd_td
      elsif descriptor['status'].casecmp('ACTIVE') == 0
        descriptor.update('status' => 'inactive')
      elsif descriptor['status'].casecmp('INACTIVE') == 0
        descriptor.destroy
      end
    end
    return not_found
  end

  # Method deleting nsds from name, vendor, version
  # @param [Array] vnfds vnfds array of hashes
  # @return [Array] Not found array
  def delete_nsds(nsds)
    not_found = []
    nsds.each do |nsd_td|
      descriptor = Nsd.where({ 'nsd.name' => nsd_td['name'],
                               'nsd.vendor' => nsd_td['vendor'],
                               'nsd.version' => nsd_td['version'] }).first
      if descriptor.nil?
        logger.error 'NSD Descriptor not found ' + nsd_td.to_s
        not_found << nsd_td
      elsif descriptor['status'].casecmp('ACTIVE') == 0
        descriptor.update('status' => 'inactive')
      elsif descriptor['status'].casecmp('INACTIVE') == 0
        descriptor.destroy
      end
    end
    return not_found
  end

  # Method deleting pd from name, vendor, version
  # @param [Hash] package model hash
  # @return [void]
  def delete_pd(descriptor)
    if descriptor['status'].casecmp('ACTIVE') == 0
      descriptor.update('status' => 'inactive')
    elsif descriptor['status'].casecmp('INACTIVE') == 0
      descriptor.destroy
    end
  end

  # Method which lists all available interfaces
  # @return [Array] an array of hashes containing all interfaces
  def interfaces_list
    [
      {
        'uri' => '/catalogues',
        'method' => 'GET',
        'purpose' => 'REST API Structure and Capability Discovery'
      },
      {
        'uri' => '/catalogues/network-services',
        'method' => 'GET',
        'purpose' => 'List all NSs or specific NS',
        'special' => 'Use version=last to retrieve NSs last version'
      },
      {
        'uri' => '/catalogues/network-services/{id}',
        'method' => 'GET',
        'purpose' => 'List a specific NS by its uuid'
      },
      {
        'uri' => '/catalogues/network-services',
        'method' => 'POST',
        'purpose' => 'Store a new NS'
      },
      {
        'uri' => '/catalogues/network-services',
        'method' => 'PUT',
        'purpose' => 'Update a stored NS specified by vendor, name, version'
      },
      {
        'uri' => '/catalogues/network-services/{id}',
        'method' => 'PUT',
        'purpose' => 'Update a stored NS by its uuid',
        'special' => 'Use status=[inactive, active, delete] to update NSD status'
      },
      {
        'uri' => '/catalogues/network-services',
        'method' => 'DELETE',
        'purpose' => 'Delete a specific NS specified by vendor, name, version'
      },
      {
        'uri' => '/catalogues/network-services/{id}',
        'method' => 'DELETE',
        'purpose' => 'Delete a specific NS by its uuid'
      },
      {
        'uri' => '/catalogues/vnfs',
        'method' => 'GET',
        'purpose' => 'List all VNFs or specific VNF',
        'special' => 'Use version=last to retrieve VNFs last version'
      },
      {
        'uri' => '/catalogues/vnfs/{id}',
        'method' => 'GET',
        'purpose' => 'List a specific VNF by its uuid'
      },
      {
        'uri' => '/catalogues/vnfs',
        'method' => 'POST',
        'purpose' => 'Store a new VNF'
      },
      {
        'uri' => '/catalogues/vnfs',
        'method' => 'PUT',
        'purpose' => 'Update a stored VNF specified by vendor, name, version'
      },
      {
        'uri' => '/catalogues/vnfs/{id}',
        'method' => 'PUT',
        'purpose' => 'Update a stored VNF by its uuid',
        'special' => 'Use status=[inactive, active, delete] to update VNFD status'
      },
      {
        'uri' => '/catalogues/vnfs',
        'method' => 'DELETE',
        'purpose' => 'Delete a specific VNF specified by vendor, name, version'
      },
      {
        'uri' => '/catalogues/vnfs/{id}',
        'method' => 'DELETE',
        'purpose' => 'Delete a specific VNF by its uuid'
      },
      {
        'uri' => '/catalogues/packages',
        'method' => 'GET',
        'purpose' => 'List all Packages or specific Package',
        'special' => 'Use version=last to retrieve Packages last version'
      },
      {
        'uri' => '/catalogues/packages/{id}',
        'method' => 'GET',
        'purpose' => 'List a specific Package by its uuid'
      },
      {
        'uri' => '/catalogues/packages',
        'method' => 'POST',
        'purpose' => 'Store a new Package'
      },
      {
        'uri' => '/catalogues/packages',
        'method' => 'PUT',
        'purpose' => 'Update a stored Package specified by vendor, name, version'
      },
      {
        'uri' => '/catalogues/packages/{id}',
        'method' => 'PUT',
        'purpose' => 'Update a stored Package by its uuid',
        'special' => 'Use status=[inactive, active, delete] to update PD status'
      },
      {
        'uri' => '/catalogues/packages',
        'method' => 'DELETE',
        'purpose' => 'Delete a specific Package specified by vendor, name, version'
      },
      {
        'uri' => '/catalogues/packages/{id}',
        'method' => 'DELETE',
        'purpose' => 'Delete a specific Package by its uuid'
      },
      {
        'uri' => '/catalogues/son-packages',
        'method' => 'GET',
        'purpose' => 'List all son-packages or specific son-package'
      },
      {
        'uri' => '/catalogues/son-packages',
        'method' => 'POST',
        'purpose' => 'Store a new son-package'
      },
      {
        'uri' => '/catalogues/son-packages/{id}',
        'method' => 'GET',
        'purpose' => 'List a specific son-package by its uuid'
      },
      {
        'uri' => '/catalogues/son-packages/{id}',
        'method' => 'DELETE',
        'purpose' => 'Remove a son-package'
      }
    ]
  end

  private
  def query_string
    request.env['QUERY_STRING'].nil? ? '' : request.env['QUERY_STRING'].to_s
  end

  def request_url
    request.env['rack.url_scheme'] + '://' + request.env['HTTP_HOST'] + request.env['REQUEST_PATH']
  end
end
