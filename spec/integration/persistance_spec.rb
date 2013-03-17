describe 'Nanoid persisting documents' do
  before do
    class Document
      include Nanoid::Document

      field :field_1
      field :field_2
    end
  end
  after { Nanoid::DB.purge }

  describe 'creating documents' do
    describe "when using #new then #save" do
      it 'persists the fields' do
        doc = Document.new
        doc.field_1 = 'field1'
        doc.field_2 = 'field2'
        doc.new_record?.should == true
        doc.save

        doc = Document.find(doc.id)
        doc.new_record?.should == false
        doc.field_1.should == 'field1'
        doc.field_2.should == 'field2'
      end
    end

    describe "when using #create" do
      it 'persists the fields' do
        doc = Document.create(:field_1 => 'field1',
                              :field_2 => 'field2')

        doc = Document.find(doc.id)
        doc.field_1.should == 'field1'
        doc.field_2.should == 'field2'
      end
    end
  end

  describe 'updating documents' do
    before do
      @doc = Document.create(:field_1 => 'field1')
    end

    describe "when updating fields and then #save" do
      it 'persists the fields' do
        @doc.field_1 = 'field1_updated'
        @doc.save

        doc = Document.find(@doc.id)
        doc.field_1.should == 'field1_updated'
      end
    end

    describe "when using #update_attributes" do
      it 'persists the fields' do
        @doc.update_attributes(:field_1 => 'field1_updated')

        doc = Document.find(@doc.id)
        doc.field_1.should == 'field1_updated'
      end
    end
  end
end
