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

namespace :init do
  require 'fileutils'
  desc "Fill Catalogues with default sonata-demo package contents"
  task :load_samples, :server do |_t, args|
    case args[:server]
      when "development"
        server = "sp.int"
      when "integration"
        server = "sp.int3"
      else
        puts "Invalid argument"
        halt
    end

    firewall_sample = "samples/sonata-demo/function-descriptor/firewall-vnfd.yml"
    iperf_sample = "samples/sonata-demo/function-descriptor/iperf-vnfd.yml"
    tcpdump_sample = "samples/sonata-demo/function-descriptor/tcpdump-vnfd.yml"
    nsd_sample = "samples/sonata-demo/service-descriptor/sonata-demo.yml"
    pd_sample = "samples/sonata-demo/package-descriptor/sonata-demo.yml"

    sh "curl -X POST -H \"Content-Type: application/x-yaml\" --data-binary @#{ firewall_sample } --connect-timeout 30 http://#{ server }.sonata-nfv.eu:4002/catalogues/vnfs"
    sh "curl -X POST -H \"Content-Type: application/x-yaml\" --data-binary @#{ iperf_sample } --connect-timeout 30 http://#{ server }.sonata-nfv.eu:4002/catalogues/vnfs"
    sh "curl -X POST -H \"Content-Type: application/x-yaml\" --data-binary @#{ tcpdump_sample } --connect-timeout 30 http://#{ server }.sonata-nfv.eu:4002/catalogues/vnfs"
    sh "curl -X POST -H \"Content-Type: application/x-yaml\" --data-binary @#{ nsd_sample } --connect-timeout 30 http://#{ server }.sonata-nfv.eu:4002/catalogues/network-services"
    sh "curl -X POST -H \"Content-Type: application/x-yaml\" --data-binary @#{ pd_sample } --connect-timeout 30 http://#{ server }.sonata-nfv.eu:4002/catalogues/packages"
  end

end
