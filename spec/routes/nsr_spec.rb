require_relative '../spec_helper'
require 'webmock/rspec'
require 'json'
require 'securerandom'
require 'pp'
require 'rspec/its'

RSpec.describe SonataNsRepository do

  def app
    @app ||= SonataNsRepository
  end

  describe 'GET \'/\'' do
    before do
      stub_request(:get, 'localhost:5000').to_return(status: 200, body: '---\n- uri: \"/\"\n  method: GET\n  purpose: REST API Structure and Capability Discovery\n- uri: \"/records/nsr/\"\n  method: GET\n  purpose: REST API Structure and Capability Discovery nsr\n- uri: \"/records/vnfr/\"\n  method: GET\n  purpose: REST API Structure and Capability Discovery vnfr\n- uri: \"/catalogues/\"\n  method: GET\n  purpose: REST API Structure and Capability Discovery catalogues\n')
      get '/'
    end
    subject { last_response }
    its(:status) { is_expected.to eq 200 }
  end

  let(:ns_instance_record) {Rack::Test::UploadedFile.new('./spec/fixtures/nsr-example.json','application/json', true)}
  describe 'POST \'/ns-instances\'' do
    context 'with correct parameters' do
      it 'Submit an nsr' do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        post '/ns-instances', ns_instance_record, headers
        expect(last_response).to be_ok
      end
    end
  end

  let(:ns_instance_record) {Rack::Test::UploadedFile.new('./spec/fixtures/nsr-example.json','application/json', true)}
  describe 'POST \'/ns-instances\'' do
    context 'Duplicated nsr' do
      it 'Submit a duplicated nsr' do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        post '/ns-instances', ns_instance_record, headers
        expect(last_response.status).to eq(409)
      end
    end
  end

  let(:ns_instance_bad_record) {Rack::Test::UploadedFile.new('./spec/fixtures/nsr-example-with-errors.json','application/json', true)}
  describe 'POST \'/ns-instances-bad\'' do
    context 'with incorrect parameters' do
      it 'Submit an invalid nsr' do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        post '/ns-instances', ns_instance_bad_record, headers
        expect(last_response.status).to eq(422)
      end
    end
  end

  describe 'GET /ns-instances' do
    context 'without (UU)ID given' do
      before do
        get '/ns-instances'
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end

  describe 'GET /ns-instances/:uuid' do
    context 'with (UU)ID given' do
      before do
        get '/ns-instances/32adeb1e-d981-16ec-dc44-e288e80067a1'
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end

  describe 'DELETE /ns-instances/:uuid' do
    context 'with (UU)ID given' do
      before do
        delete '/ns-instances/32adeb1e-d981-16ec-dc44-e288e80067a1'
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end
end
