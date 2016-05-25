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

  let(:vnf_descriptor) {Rack::Test::UploadedFile.new('./spec/fixtures/vnfd-example.json','application/json', true)}
  describe 'POST \'/vnfs\'' do
    context 'with correct parameters' do
      it 'Submit a vnfd' do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        post '/vnfs', vnf_descriptor, headers
        expect(last_response.status).to eq(201)
        vnfd_body = JSON.parse(last_response.body)
        $vnfd_id = (vnfd_body['uuid'])
      end
    end
  end

  let(:vnf_descriptor) {Rack::Test::UploadedFile.new('./spec/fixtures/vnfd-example.json','application/json', true)}
  describe 'POST \'/vnfs\'' do
    context 'Duplicated vnfd' do
      it 'Submit a duplicated vnfd' do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        post '/vnfs', vnf_descriptor, headers
        expect(last_response.status).to eq(400)
      end
    end
  end

  let(:vnf_bad_descriptor) {Rack::Test::UploadedFile.new('./spec/fixtures/vnfd-example-with-errors.json','application/json', true)}
  describe 'POST \'/vnfs-bad\'' do
    context 'with incorrect parameters' do
      it 'Submit an invalid vnfd' do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        post '/vnfs', vnf_descriptor, headers
        expect(last_response.status).to eq(400)
      end
    end
  end

  describe 'GET /vnfs' do
    context 'without (UU)ID given' do
      before do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        get '/vnfs', nil, headers
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end

  describe 'GET /vnfs/:uuid' do
    context 'with (UU)ID given' do
      before do
        headers = { 'CONTENT_TYPE' => 'application/json' }
        get '/vnfs/' + $vnfd_id.to_s, nil, headers
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end

  describe 'DELETE /vnfs/:uuid' do
    context 'with (UU)ID given' do
      before do
        delete '/vnfs/' + $vnfd_id.to_s
      end
      subject { last_response }
      its(:status) { is_expected.to eq 200 }
    end
  end
end
