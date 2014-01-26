describe '#all' do
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
    it 'returns []' do
      SelectionDocument.all.should == []
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

    it 'returns all documents' do
      SelectionDocument.all.count.should == 4
      SelectionDocument.all.all? { |doc| doc.class.should == SelectionDocument }
    end
  end
end
