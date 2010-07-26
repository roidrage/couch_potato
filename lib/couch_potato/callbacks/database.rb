module CouchPotato
  module Callbacks
    module Database
      def destroy_document(document)
        document.run_callbacks :before_destroy
        super 
        document.run_callbacks :after_destroy
      end

      def create_document(document, validate)
        if validate
          document.errors.clear
          document.run_callbacks :before_validation_on_save
          document.run_callbacks :before_validation_on_create
          return false unless valid_document?(document)
        end
        
        document.run_callbacks :before_save
        document.run_callbacks :before_create
        super
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
        super
        document.run_callbacks :after_save
        document.run_callbacks :after_update
        true
      end

      # saves a document, raises a CouchPotato::Database::ValidationsFailedError on failure
      def save_document!(document)
        save_document(document) || raise(ValidationsFailedError.new(document.errors.full_messages))
      end

      def valid_document?(document)
        errors = document.errors.errors.dup
        document.valid?
        errors.each_pair do |k, v|
          v.each {|message| document.errors.add(k, message)}
        end
        document.errors.empty?
      end
   
    end
  end
end
