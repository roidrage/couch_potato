require 'spec_helper'

describe CouchPotato::View::ModelViewSpec, 'map_function' do
  it "should include conditions" do
    spec = CouchPotato::View::ModelViewSpec.new Object, 'all', {:conditions => 'doc.closed = true'}, {}
    spec.map_function.should include('if(doc.ruby_class && doc.ruby_class == \'Object\' && (doc.closed = true))')
  end
  
  it "should not include conditions when they are nil" do
    spec = CouchPotato::View::ModelViewSpec.new Object, 'all', {}, {}
    spec.map_function.should include('if(doc.ruby_class && doc.ruby_class == \'Object\')')
  end
end

describe CouchPotato::View::ModelViewSpec, "processing results" do
  context "for a reduce view" do
    before(:each) do
      @spec = CouchPotato::View::ModelViewSpec.new(Object, 'all', {}, {:reduce => true})
    end

    it "should return the first reduce result when only one row was returned" do
      @spec.process_results({'rows' => [{'value' => '2'}]}).should == '2'
    end

    it "should return all rows when more then one was returned" do
      @spec.process_results('rows' => [{'key' => '1234', 'value' => 1}, {'key' => '2345', 'value' => 2}]).should ==
        [{'key' => '1234', 'value' => 1}, {'key' => '2345', 'value' => 2}]
    end
  end

  context "for a view returning documents" do
    before(:each) do
      @spec = CouchPotato::View::ModelViewSpec.new(Object, 'all', {}, {:reduce => false})
    end
    
    it "should return the documents" do
      @spec.process_results({'rows' => [{'doc' => {'_id' => '12345'}}, {'doc' => {'_id' => '23456'}}]}).should ==
        [{'_id' => '12345'}, {'_id' => '23456'}]
    end
  end
end
