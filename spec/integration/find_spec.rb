describe '#find' do
  before do
    class SelectionDocument
      include Yapper::Document

      field :field1
      field :field2
    end
    class AnotherSelectionDocument
      include Yapper::Document

      field :field1
      field :field2
    end
  end
  before { Yapper::DB.instance.purge }
  after { Object.send(:remove_const, 'SelectionDocument') }
  after { Object.send(:remove_const, 'AnotherSelectionDocument') }

  describe 'with no documents created' do
    it 'returns nil when looking up a document' do
      SelectionDocument.find('xxx').should == nil
    end
  end

  describe 'with a few documents created with string fields' do
    before do
      @doc = SelectionDocument.create(:field1 => 'field1_value', :field2 => 'field2_value')
      SelectionDocument.create(:field1 => 'field1_value', :field2 => 'field2_value')
      SelectionDocument.create(:field1 => 'field1_value', :field2 => 'field2_other_value')
      SelectionDocument.create(:field1 => 'field1_other_value', :field2 => 'field2_other_value')
      AnotherSelectionDocument.create(:field1 => 'field1_value', :field2 => 'field2_value')
    end

    it 'can find a document' do
      SelectionDocument.find(@doc.id).field1.should == 'field1_value'
    end

    it 'has no changes when selecting a document' do
      SelectionDocument.find(@doc.id).changes.should == {}
    end

    it 'returns nil when looking up a non-existant doc' do
      SelectionDocument.find('xxx').should == nil
    end

    it 'returns nil when looking up nil' do
      SelectionDocument.find(nil).should == nil
    end
  end
end
