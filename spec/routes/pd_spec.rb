##
## Copyright 2015-2017 i2CAT Foundation
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##   http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.

require_relative '../spec_helper'
require 'webmock/rspec'
require 'json'
require 'securerandom'
require 'pp'
require 'rspec/its'

RSpec.describe SonataCatalogue do

  def app
    @app ||= SonataCatalogue
  end

  describe 'GET \'/\'' do
    before do
      stub_request(:get, 'localhost:5000').to_return(status: 200)
      get '/'
    end
    subject { last_response }
    its(:status) { is_expected.to eq 200 }
  end

  let(:package_descriptor) {Rack::Test::UploadedFile.new('./spec/fixtures/pd-example.json','application/json', true)}
  describe 'POST \'/packages\'' do
    context 'with correct parameters' do
      it 'Submit a pd' do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        post '/packages', package_descriptor, headers
        expect(last_response.status).to eq(201)
        pd_body = JSON.parse(last_response.body)
        $pd_id = (pd_body['uuid'])
      end
    end
  end

  let(:package_descriptor) {Rack::Test::UploadedFile.new('./spec/fixtures/pd-example.json','application/json', true)}
  describe 'POST \'/packages\'' do
    context 'Duplicated pd' do
      it 'Submit a duplicated pd' do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        post '/packages', package_descriptor, headers
        expect(last_response.status).to eq(200)
      end
    end
  end

  let(:package_bad_descriptor) {Rack::Test::UploadedFile.new('./spec/fixtures/pd-example-with-errors.json','application/json', true)}
  describe 'POST \'/packages-bad\'' do
    context 'with incorrect parameters' do
      it 'Submit an invalid pd' do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        post '/packages', package_bad_descriptor, headers
        expect(last_response.status).to eq(400)
      end
    end
  end

  describe 'GET /packages' do
    context 'without (UU)ID given' do
      before do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        get '/packages', nil, headers
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end

  describe 'GET /packages/:uuid' do
    context 'with (UU)ID given' do
      before do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        get '/packages/' + $pd_id.to_s, nil, headers
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end

  describe 'DELETE /packages/:uuid' do
    context 'with (UU)ID given' do
      before do
        delete '/packages/' + $pd_id.to_s
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end
end
