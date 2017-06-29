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

require_relative '../spec_helper'
require 'webmock/rspec'
require 'json'
require 'securerandom'
require 'pp'
require 'rspec/its'
require 'yaml'

RSpec.describe CatalogueV1 do

  def app
    @app ||= CatalogueV1
  end

  describe 'GET \'/\'' do
    before do
      stub_request(:get, 'localhost:5000').to_return(status: 200)
      get '/'
    end
    subject { last_response }
    its(:status) { is_expected.to eq 200 }
  end

  describe 'GET /son-packages' do
    context 'without (UU)ID given' do
      before do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        get '/son-packages', nil, headers
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end
end

RSpec.describe CatalogueV2 do

  def app
    @app ||= CatalogueV2
  end

  describe 'GET \'/\'' do
    before do
      stub_request(:get, 'localhost:5000').to_return(status: 200)
      get '/'
    end
    subject { last_response }
    its(:status) { is_expected.to eq 200 }
  end

  describe 'GET /api/v2/son-packages' do
    context 'without (UU)ID given' do
      before do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        get '/son-packages', nil, headers
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end

  # Posts two different sonata packages, first one contains as vnfds firewall-vnfd,
  #    iperf-vnfd and tcpdump-vnfd; second one contains only tcpdump-vnfd
  #    according to next test that tries to delete the first one, tcpdump-vnfd should
  #    not be deleted according to intelligent delete feature
  describe 'POST /api/v2/son-packages' do
    context 'post packages simulating gatekeeper operation (posting all descriptors)' do
      before do
        filenames = [ 'samples/dependencies_mapping/sonata-demo.son',
                      'samples/dependencies_mapping/sonata-demo-2.son' ]
        $pd_uuids = []
        filenames.each do |filename|
          headers = { 'CONTENT_TYPE' => 'application/zip',
                      'HTTP_CONTENT_DISPOSITION' => "attachment; filename=#{filename}" }
          response = post '/son-packages', File.binread(filename), headers
          $sonp_uuids = JSON.parse(response.body)
          content = xtract_sonp(filename)
          content[:vnfds].each do |vnfd|
            postvnf = post '/vnfs',
                           vnfd,
                           { 'CONTENT_TYPE' => 'application/x-yaml' }
          end
          content[:nsds].each do |nsd|
            postnsd = post '/network-services',
                           nsd,
                           { 'CONTENT_TYPE' => 'application/x-yaml' }
          end
          postpd = post '/packages',
                         content[:manifest],
                         { 'CONTENT_TYPE' => 'application/x-yaml' }
          $pd_uuids << YAML.load(postpd.body)['uuid']
        end
      end
      subject { last_response }
      its(:status) { is_expected.to eq 201 }
    end
  end

  # Tries to delete first package posted in previous test resulting
  #    in the deletion of
  #    {"deleted":
  #    {"vnfds":[{"vendor":"eu.sonata-nfv","version":"0.3","name":"firewall-vnf"},
  #    {"vendor":"eu.sonata-nfv","version":"0.2","name":"iperf-vnf"}],
  #    "nsds":[{"vendor":"eu.sonata-nfv.service-descriptor","version":"0.2.1","name":"sonata-demo"}]}}
  # But preventing tcpdump-vnfd deletion because second package posted before has a dependency on it
  describe 'DELETE /api/v2/packages' do
    context 'deleting pds' do
      before do
        delete_response = delete '/packages/' + $pd_uuids[0]
        puts delete_response.body
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end

  # Deletes the second package posted
  describe 'DELETE /api/v2/packages' do
    context 'deleting pds' do
      before do
        delete_response = delete '/packages/' + $pd_uuids[1]
        puts delete_response.body
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end


end
