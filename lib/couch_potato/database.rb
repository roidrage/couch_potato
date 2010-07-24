require 'benchmark'

module CouchPotato
  class Database

    class ValidationsFailedError < ::StandardError; end

    def initialize(couchrest_database)
      @database = couchrest_database
      begin
        couchrest_database.info
      rescue RestClient::ResourceNotFound
        raise "Database '#{couchrest_database.name}' does not exist."
      end
    end

    # executes a view and return the results. you pass in a view spec
    # which is usually a result of a SomePersistentClass.some_view call.
    # also return the total_rows returned by CouchDB as an accessor on the results.
    #
    # Example:
    #
    #   class User
    #     include CouchPotato::Persistence
    #     property :age
    #     view :all, key: :age
    #   end
    #   db = CouchPotato.database
    #
    #   db.view(User.all) # => [user1, user2]
    #   db.view(User.all).total_rows # => 2
    #
    # You can pass the usual parameters you can pass to a couchdb view to the view:
    #
    #   db.view(User.all(limit: 5, startkey: 2, reduce: false))
    #
    # For your convenience when passing a hash with only a key parameter you can just pass in the value
    #
    #   db.view(User.all(key: 1)) == db.view(User.all(1))
    # 
    # Instead of passing a startkey and endkey you can pass in a key with a range:
    #
    #   db.view(User.all(key: 1..20)) == db.view(startkey: 1, endkey: 20) == db.view(User.all(1..20))
    #   
    # You can also pass in multiple keys:
    #
    #   db.view(User.all(keys: [1, 2, 3]))
    def view(spec)
      benchmark(spec) do
        results = CouchPotato::View::ViewQuery.new(
          database,
          spec.design_document,
          {spec.view_name => {
            :map => spec.map_function,
            :reduce => spec.reduce_function}
          },
          ({spec.list_name => spec.list_function} unless spec.list_name.nil?)
        ).query_view!(spec.view_parameters)
        processed_results = spec.process_results results
        processed_results.instance_eval "def total_rows; #{results['total_rows']}; end" if results['total_rows']
        processed_results.each do |document|
          document.database = self if document.respond_to?(:database=)
        end if processed_results.respond_to?(:each)
        processed_results
      end
    end

    # saves a document. returns true on success, false on failure
    def save_document(document, validate = true)
      return true unless document.dirty?
      if document.new?
        create_document(document, validate)
      else
        update_document(document, validate)
      end
    end
    alias_method :save, :save_document
    
    # saves a document, raises a CouchPotato::Database::ValidationsFailedError on failure
    def save_document!(document)
      save_document(document) || raise(ValidationsFailedError.new(document.errors.full_messages))
    end
    alias_method :save!, :save_document!

    def destroy_document(document)
      document.run_callbacks :before_destroy
      document._deleted = true
      database.delete_doc document.to_hash
      document.run_callbacks :after_destroy
      document._id = nil
      document._rev = nil
    end
    alias_method :destroy, :destroy_document

    # loads a document by its id
    def load_document(id)
      raise "Can't load a document without an id (got nil)" if id.nil?
      begin
        instance = database.get(id)
        instance.database = self
        instance
      rescue(RestClient::ResourceNotFound)
        nil
      end
    end
    alias_method :load, :load_document

    def inspect #:nodoc:
      "#<CouchPotato::Database>"
    end

    private

    def benchmark(spec, &block)
      if CouchPotato.logger.debug?
        results = nil
        runtime = Benchmark.realtime do
          results = block.call
        end * 1000
        log_entry = '[CouchPotato] view query: %s#%s (%.1fms)' % [spec.send(:klass).name, spec.view_name, runtime]
        CouchPotato.logger.debug(log_entry)
        results
      else
        yield
      end
    end

    def create_document(document, validate)
      document.database = self
      
      if validate
        document.errors.clear
        document.run_callbacks :before_validation_on_save
        document.run_callbacks :before_validation_on_create
        return false unless valid_document?(document)
      end
      
      document.run_callbacks :before_save
      document.run_callbacks :before_create
      res = database.save_doc document.to_hash
      document._rev = res['rev']
      document._id = res['id']
      document.run_callbacks :after_save
      document.run_callbacks :after_create
      true
    end

    def update_document(document, validate)
      if validate
        document.errors.clear
        document.run_callbacks :before_validation_on_save
        document.run_callbacks :before_validation_on_update
        return false unless valid_document?(document)
      end
      
      document.run_callbacks :before_save
      document.run_callbacks :before_update
      res = database.save_doc document.to_hash
      document._rev = res['rev']
      document.run_callbacks :after_save
      document.run_callbacks :after_update
      true
    end

    def valid_document?(document)
      errors = document.errors.errors.dup
      document.valid?
      errors.each_pair do |k, v|
        v.each {|message| document.errors.add(k, message)}
      end
      document.errors.empty?
    end
    
    def database
      @database
    end

  end
end
