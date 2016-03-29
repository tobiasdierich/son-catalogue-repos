root = ::File.dirname(__FILE__)
require ::File.join(root, 'main')
#require 'sinatra/gk_auth' # <- Disabled

map('/records/nsr') {run SonataNsRepository.new}
map('/records/vnfr') {run SonataVnfRepository.new}
map('/catalogues') {run SonataCatalogue.new}
map('/') {run Sonata.new}
