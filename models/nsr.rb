module BSON
  class ObjectId
    def to_json(*)
      to_s.to_json
    end
    def as_json(*)
      to_s.as_json
    end
  end
end

module Mongoid
  module Document
    def serializable_hash(options = nil)
      h = super(options)
      h['id'] = h.delete('_id') if(h.has_key?('_id'))
      h
    end
  end
end

class Nsr
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Attributes::Dynamic
	store_in collection: "nsr"
 	#Sonata schema NSD Fields
 	field :id, type: String
	field :name, type: String
	field :vendor, type: String
	field :version, type: String
	field :vnfds, type: String
	field :vnffgrd, type: Array
	field :lifecycle_event, type: Object
	field :vnf_dependency, type: Array
	field :monitoring_parameter, type: Array
	field :vld, type: Object
	field :sla, type: Array
	field :auto_scale_policy, type: Object
	field :connection_point, type: Array
	#nsr ETSI fields MAN001 6.2.2.1
	field :service_deployment_flavour, type: String
	field :vnfr, type: Array
	field :pnfr, type: Array
	field :descriptor_reference, type: String
	field :resource_reservation, type: Array
	field :runtime_policy_info, type: Array
	field :status, type: String
	field :notification, type: String
	field :lifecycle_event_history, type: Array
	field :audit_log, type: Array
	#Sonata's custom fields
	field :mapping_time, type: Time
	field :instantiation_start_time, type: Time
	field :instantiation_end_time, type: Time
	#future fields: Slicing and Recursiveness
end
