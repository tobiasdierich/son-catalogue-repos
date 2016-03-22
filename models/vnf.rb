class Vnfr
	include Mongoid::Document
	include Mongoid::Timestamps
	include Mongoid::Pagination
		
	store_in collection: "vnf"
	field :vnfr, type: Hash
	
end
