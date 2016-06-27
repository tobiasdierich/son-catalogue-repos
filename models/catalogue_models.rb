# Convert BSON ID to String
module BSON
  class ObjectId
    def to_json(*args)
      to_s.to_json
    end

    def as_json(*args)
      to_s.as_json
    end
  end
end

class Ns
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Pagination
  include Mongoid::Attributes::Dynamic
  store_in collection: "nsd"

  # field :nsd, type: Hash
  field :vendor, type: String
  field :name, type: String
  field :version, type: String


  validates :vendor, :name, :version, :presence => true

end

class Vnf
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Pagination
  # include Mongoid::Versioning
  include Mongoid::Attributes::Dynamic
  store_in collection: "vnfd"

  field :vendor, type: String
  field :name, type: String
  field :version, type: String
  # field :vnf_manager, type: String # <- Not applicable yet
  # field :vnfd, type: Hash

  validates :vendor, :name, :version, :presence => true
end

class Package
  include Mongoid::Document
	include Mongoid::Timestamps
	include Mongoid::Pagination
	# include Mongoid::Versioning
	include Mongoid::Attributes::Dynamic
	store_in collection: "pd"

	field :vendor, type: String
	field :name, type: String
	field :version, type: String

	validates :vendor, :name, :version, :presence => true
end

# Class model for binary data storage on database
require 'mongoid/grid_fs'

class FileContainer
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Pagination
  store_in collection: "file_containers"

  field :grid_fs_id, type: String
  # field :grid_fs_vendor, type: String
  field :grid_fs_name, type: String
  # field :grid_fs_version, type: String
  field :hash, type: String

  # validates :zipp_vendor, :zipp_name, :zipp_version, :presence => true
end
