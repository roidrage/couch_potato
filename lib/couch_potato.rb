require 'couchrest'
require 'json'
require 'json/add/core'
require 'json/add/rails'

require 'ostruct'

JSON.create_id = 'ruby_class'

unless defined?(CouchPotato)
  module CouchPotato
    Config = Struct.new(:database_name, :validation_framework).new
    Config.validation_framework = :validatable # default to the validatable gem for validations

    # Returns a database instance which you can then use to create objects and query views. You have to set the CouchPotato::Config.database_name before this works.
    def self.database
      @@__database ||= Database.new(self.couchrest_database)
    end

    # Returns the underlying CouchRest database object if you want low level access to your CouchDB. You have to set the CouchPotato::Config.database_name before this works.
    def self.couchrest_database
      @@__couchrest_database ||= CouchRest.database(full_url_to_database)
    end
    
    def self.log_level=(level)
      @log_level = level
    end

    def self.log_level
      @log_level || :info
    end

    def self.logger
      @logger ||= Logger.new(STDOUT) 
    end
    
    def self.logger=(logger)
      @logger = logger
    end

    private

    def self.full_url_to_database
      raise('No Database configured. Set CouchPotato::Config.database_name') unless CouchPotato::Config.database_name
      if CouchPotato::Config.database_name.match(%r{https?://})
        CouchPotato::Config.database_name
      else
        "http://127.0.0.1:5984/#{CouchPotato::Config.database_name}"
      end
    end
  end
end

$LOAD_PATH << File.dirname(__FILE__)

require 'core_ext/object'
require 'core_ext/time'
require 'core_ext/date'
require 'core_ext/string'
require 'core_ext/symbol'
require 'couch_potato/validation'
require 'couch_potato/persistence'
require 'couch_potato/railtie' if defined?(Rails)
