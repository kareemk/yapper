describe 'multi-threaded' do
  before do
    class Document
      include Nanoid::Document

      field :field_1
      field :field_2
    end
  end
  after { Nanoid::DB.purge }
  after { Object.send(:remove_const, 'Document') }

  it 'behaves safely' do
    t1 = Thread.new { 10.times { Document.create(:field_1 => 'field') } }
    t2 = Thread.new { 10.times { Document.all.each { |d| d.update_attributes(:field_1 => 'bye') } } }

    t1.join
    t2.join
    Document.all.count.should == 10
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
