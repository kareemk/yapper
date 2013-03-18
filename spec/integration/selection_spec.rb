describe 'Nanoid selecting documents' do
  before do
    class SelectionDocument
      include Nanoid::Document

      field :field1
      field :field2
    end

    @doc = SelectionDocument.create(:field1 => 'field1')
    SelectionDocument.create(:field1 => 'field1')
    SelectionDocument.create(:field1 => 'field2')
  end
  after { Object.send(:remove_const, 'SelectionDocument') }
  after { Nanoid::DB.purge }

  describe 'with #find' do
    it 'can select document' do
      SelectionDocument.find(@doc.id).field1.should == 'field1'
    end

    it 'returns nil when looking up a non-existant doc' do
      SelectionDocument.find('xxx').should == nil
    end
  end

  describe 'with #where' do
    it 'can select document by matching on a field' do
      SelectionDocument.where(:field1 => 'field1').each {|d| d.field1.should == 'field1'}
    end

    it 'returns nil when looking up a non-existant doc' do
      SelectionDocument.where(:field1 => 'xxx').length.should == 0
    end
  end
end
