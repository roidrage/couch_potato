# this is for rails only

require File.expand_path(File.dirname(__FILE__) + '/../lib/couch_potato')
CouchPotato.logger = Rails.logger
CouchPotato.logger.info "** couch_potato: initialized from #{__FILE__}"
