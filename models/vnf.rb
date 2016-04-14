class Vnfr
	include Mongoid::Document
	include Mongoid::Timestamps
	include Mongoid::Pagination
    include Mongoid::Attributes::Dynamic
	
	store_in collection: "vnf"	
end
