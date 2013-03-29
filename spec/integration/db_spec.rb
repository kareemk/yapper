describe 'db' do
  before do
    class Document
      include Nanoid::Document

      field :field_1
      field :field_2
    end
  end
  after { Nanoid::DB.purge }
  after { Object.send(:remove_const, 'Document') }

  it 'can batch updates for better performance on CUD' do
    Nanoid::DB.batch(10) do
      3.times { Document.create(:field_1 => 'saved') }

      Document.where(:field_1 => 'saved').count.should == 0
    end
    Document.where(:field_1 => 'saved').count.should == 3
  end
end
