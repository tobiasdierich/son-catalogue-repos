require_relative '../spec_helper'
require 'webmock/rspec'
require 'json'
require 'securerandom'
require 'pp'
require 'rspec/its'

RSpec.describe SonataVnfRepository do

  def app
    @app ||= SonataVnfRepository
  end

  describe 'GET \'/\'' do
    before do
      stub_request(:get, 'localhost:5000').to_return(status: 200, body: '---\n- uri: \"/\"\n  method: GET\n  purpose: REST API Structure and Capability Discovery\n- uri: \"/records/nsr/\"\n  method: GET\n  purpose: REST API Structure and Capability Discovery nsr\n- uri: \"/records/vnfr/\"\n  method: GET\n  purpose: REST API Structure and Capability Discovery vnfr\n- uri: \"/catalogues/\"\n  method: GET\n  purpose: REST API Structure and Capability Discovery catalogues\n')
      get '/'
    end
    subject { last_response }
    its(:status) { is_expected.to eq 200 }
  end

  let(:vnf_instance_record) {Rack::Test::UploadedFile.new('./spec/fixtures/vnfr-example.json','application/json', true)}
  describe 'POST \'/vnf-instances\'' do
    context 'with correct parameters' do
      it 'Submit an vnfr' do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        post '/vnf-instances', vnf_instance_record, headers
        expect(last_response).to be_ok
      end
    end
  end

  let(:vnf_instance_record) {Rack::Test::UploadedFile.new('./spec/fixtures/vnfr-example.json','application/json', true)}
  describe 'POST \'/vnf-instances\'' do
    context 'Duplicated vnfr' do
      it 'Submit a duplicated vnfr' do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        post '/vnf-instances', vnf_instance_record, headers
        expect(last_response.status).to eq(409)
      end
    end
  end

  let(:vnf_instance_bad_record) {Rack::Test::UploadedFile.new('./spec/fixtures/vnfr-example-with-errors.json','application/json', true)}
  describe 'POST \'/vnf-instances-bad\'' do
    context 'with incorrect parameters' do
      it 'Submit an invalid vnfr' do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        post '/vnf-instances', vnf_instance_bad_record, headers
        expect(last_response.status).to eq(422)
      end
    end
  end

  describe 'GET /vnf-instances' do
    context 'without (UU)ID given' do
      before do
        get '/vnf-instances'
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end

  describe 'GET /vnf-instances/:uuid' do
    context 'with (UU)ID given' do
      before do
        get '/vnf-instances/9e3d3b42-6372-2250-969d-53ae91bb5cfc'
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end

  describe 'DELETE /vnf-instances/:uuid' do
    context 'with (UU)ID given' do
      before do
        delete '/vnf-instances/9e3d3b42-6372-2250-969d-53ae91bb5cfc'
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end
end
