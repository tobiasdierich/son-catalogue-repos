require 'yard'
require 'rspec/core/rake_task'
require 'ci/reporter/rake/rspec'
require './main'

task :default => ['ci:all']

desc 'Start the service'
task :start do
  puts 'SON REPOSITORY STARTING...'
  conf = File.expand_path('config.ru', File.dirname(__FILE__))
  conf2 = File.expand_path('config/config.yml', File.dirname(__FILE__))
  exec("thin -C #{conf2} -R #{conf} --debug start")
end

desc 'Run Unit Tests'
RSpec::Core::RakeTask.new :specs do |task|
  task.pattern = Dir['spec/**/*_spec.rb']
end

YARD::Rake::YardocTask.new do |t|
  t.files = ['main.rb', 'helpers/*.rb', 'routes/*.rb']
end

namespace :ci do
  task all: ['ci:setup:rspec', 'specs']
end

namespace :db do
  task :load_config do
    require './main'
  end
end
