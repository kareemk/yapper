describe 'Nanoid store and find documents' do
  before do
    class Document
      include Nanoid::Document

      field :field1
      field :field2
    end
  end

  it 'persists fields using #new then #save' do
    doc = Document.new
    new.field_1 = 'field1'
    new.field_2 = 'field2'
    doc.save

    doc.find(new.id)
    doc.field_1.should == 'field1'
    doc.field_1.should == 'field2'
  end

  it 'persists fields using #create' do
  end
end
