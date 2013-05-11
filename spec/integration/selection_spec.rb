describe 'Nanoid selecting documents' do
  before do
    class SelectionDocument
      include Nanoid::Document

      field :field1
      field :field2
    end

  end
  after { Object.send(:remove_const, 'SelectionDocument') }
  after { Nanoid::DB.purge }

  describe 'with no documents created' do
    it 'returns nil when looking up a document' do
      SelectionDocument.find('xxx').should == nil
    end
  end

  describe 'with a few documents created' do
    before do
      @doc = SelectionDocument.create(:field1 => 'field1')
      SelectionDocument.create(:field1 => 'field1')
      SelectionDocument.create(:field1 => 'field2')
    end

    describe 'with #find' do
      it 'can select document' do
        SelectionDocument.find(@doc.id).field1.should == 'field1'
      end

      it 'returns nil when looking up a non-existant doc' do
        SelectionDocument.find('xxx').should == nil
      end

      it 'returns nil when looking up nil' do
        SelectionDocument.find(nil).should == nil
      end
    end

    describe 'with #where' do
      it 'can select document by matching on a field' do
        SelectionDocument.where(:field1 => 'field1').each {|d| d.field1.should == 'field1'}
      end

      it 'returns nil when looking up a non-existant doc' do
        SelectionDocument.where(:field1 => 'xxx').count.should == 0
      end
    end

    describe 'with #all' do
      it 'selects all documents' do
        SelectionDocument.all.count.should == 3
        SelectionDocument.all.first.class.should == SelectionDocument
      end
    end
  end
end
