source 'https://rubygems.org'

gem 'addressable'
gem 'rake'
gem 'sinatra', '~> 1.4.3', require: 'sinatra/base'
gem 'sinatra-contrib', '~> 1.4.1', require: false
gem 'thin', '~>1.6'
gem 'json', '~>1.8'
# gem 'nokogiri', '~>1.6'
gem 'json-schema', '~>2.5'
gem 'rest-client', '~>1.8'
# gem 'rubysl-securerandom', '~> 2.0'
gem 'ci_reporter_rspec'
# gem 'logstash-logger'

group :development, :test do
  gem 'webmock'
  # gem 'rerun'
  gem 'rspec'
  gem 'rspec-mocks'
  gem 'rack-test', require: 'rack/test'
  gem 'rspec-its'
  # gem 'database_cleaner'
  # gem 'factory_girl'
  gem 'rubocop'
  gem 'rubocop-checkstyle_formatter', require: false
  # gem 'json_spec', '~>1.1.4'
  # gem 'database_cleaner'
  # gem 'mongoid-rspec', '~> 2.2.0'
end

group :doc do
  gem 'yard', '~>0.8'
end

# Database
gem 'mongoid', '~>4.0' # MongoDB driver
gem 'mongoid-pagination', '~>0.2' # Pagination library
gem 'mongoid-grid_fs', '~>2.2' # mongoid-grid_fs-2.2 - GridFS for store bin data
# gem 'sinatra-gkauth', '~>0.2.0', path: '../sinatra-gkauth-gem' # <- Disabled
