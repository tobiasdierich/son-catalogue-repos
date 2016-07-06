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
