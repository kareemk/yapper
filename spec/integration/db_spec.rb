describe 'multi-threaded' do
  it 'uses a different connection for each thread' do
    conn1 = nil
    conn2 = nil

    Thread.new { conn1 = Nanoid::DB.default_db(:memory) }.join
    Thread.new { conn2 = Nanoid::DB.default_db(:memory) }.join

   conn1.should.not == conn2
  end
end

describe 'persisting in memory' do
  before do
    class Document
      include Nanoid::Document

      field :field_1
      field :field_2
      store_in :memory
    end
  end
  after { Nanoid::DB.purge }
  after { Object.send(:remove_const, 'Document') }

  it 'can batch updates for better performance on CUD' do
    Document.create(:field_1 => 'saved')

    Document.where(:field_1 => 'saved').count.should == 1
  end
end

describe 'persisting in file' do
  before do
    class Document
      include Nanoid::Document

      field :field_1
      field :field_2
      store_in :file
    end
  end
  after { Nanoid::DB.purge }
  after { Object.send(:remove_const, 'Document') }

  it 'can batch updates for better performance on CUD' do
    Document.create(:field_1 => 'saved')

    Document.where(:field_1 => 'saved').count.should == 1
  end
end

describe 'persisting in temp' do
  before do
    class Document
      include Nanoid::Document

      field :field_1
      field :field_2
      store_in :temp
    end
  end
  after { Nanoid::DB.purge }
  after { Object.send(:remove_const, 'Document') }

  it 'can batch updates for better performance on CUD' do
    Document.create(:field_1 => 'saved')

    Document.where(:field_1 => 'saved').count.should == 1
  end
end
