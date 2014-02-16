describe '#when' do
  before do
    class SelectionDocument
      include Yapper::Document

      field :field1
      field :field2
    end
  end
  before { Yapper::DB.instance.purge }
  after { Object.send(:remove_const, 'SelectionDocument') }

  describe 'when a document does not exist' do
    it 'only executes the block when the document exists' do
      doc = SelectionDocument.new(:field1 => 'field1')
      found = false

      SelectionDocument.when(doc.id) do |_doc|
        found = true
      end

      found.should == false

      doc.save

      found.should == true
    end
  end
end
