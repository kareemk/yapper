describe 'Search' do
  before do
    class SearchDocument
      include Yapper::Document

      field :field1, :type => String
      field :field2, :type => Integer
      field :field3, :type => String
      field :field4, :type => Boolean

      search_index :field1, :field2, :field4
    end
    class AnotherSearchDocument
      include Yapper::Document

      field :field1, :type => String
      field :field2

      search_index :field1
    end
  end
  before { Yapper::DB.instance.purge }
  after { Object.send(:remove_const, 'SearchDocument') }
  after { Object.send(:remove_const, 'AnotherSearchDocument') }

  describe 'when changing the search definition' do
    it "reindexes the fields" do
      SearchDocument.create(:field1 => 'field1', :field3 => 'field3')

      SearchDocument.search('field3').should == []

      SearchDocument.class_eval do
        search_index :field3
      end

      SearchDocument.search('field3:field3').count.should == 1
    end
  end

  # it 'does not allow indexing a Time field'

  describe 'with no documents created' do
    it 'returns []' do
      SearchDocument.search('xxx').to_a.should == []
    end
  end

  describe 'with documents created' do
    before do
      @now = Time.now
      SearchDocument.create(:field1 => 'field1value', :field2 => 2)
      SearchDocument.create(:field1 => 'field1value', :field2 => 3)
      SearchDocument.create(:field1 => 'field1value', :field2 => 4)
      SearchDocument.create(:field1 => 'othervaluefield1', :field2 => 1)
      SearchDocument.create(:field4 => true)
      AnotherSearchDocument.create(:field1 => 'field1value', :field2 => 2)
    end

    it 'can search by string' do
      SearchDocument.search("field1:field1value").count.should == 3
    end

    it 'can search by integer' do
      SearchDocument.search("field2:#{2}").count.should == 1
    end

    it 'can search by boolean' do
      SearchDocument.search('field4:true').count.should == 1
      SearchDocument.search('field5:false').count.should == 0
    end

    it 'returns [] when looking up a non-existant doc' do
      SearchDocument.search('field1:xxx').to_a.should == []
    end

    it 'can select docments matching on multiple fields' do
      SearchDocument.search("field1:field1value field2:2").to_a.count.should == 1
    end

    describe 'when documents are updated' do
      before do
        SearchDocument.search("field1:field1value").each { |doc| doc.update_attributes(:field1 => 'field1valueupdated', :field2 => 10) }
      end

      it 'searches by the updated values' do
        SearchDocument.search("field1:field1value").count.should == 0
        SearchDocument.search("field1:field1valueupdated field2:10").count.should == 3
      end
    end
  end

  describe 'when a document is created without all fields being set' do
    before do
      SearchDocument.create(:field1 => 'field1value')
    end

    it 'searches by the field' do
      SearchDocument.search("field1:field1value").count.should == 1
    end

    describe 'when the document is updated to set a field that was not set before' do
      before do
        SearchDocument.search("field1:field1value").first.update_attributes(:field2 => 10)
      end

      it 'searches by the updated field' do
        SearchDocument.search("field2:10").count.should == 1
      end
    end
  end
end
