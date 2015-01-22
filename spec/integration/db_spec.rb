describe 'db' do
  before do
    class Document
      include Yapper::Document

      field :field_1
      field :field_2
    end

    class AnotherDocument
      include Yapper::Document

      field :field_1
      field :field_2
    end
  end
  before { Yapper::DB.instance.purge }
  after { Object.send(:remove_const, 'Document') }
  after { Object.send(:remove_const, 'AnotherDocument') }

  it 'is thread safe' do
    threads = []
    threads << Thread.new { 10.times { Document.create(:field_1 => 'field') } }
    threads << Thread.new { 10.times { AnotherDocument.create(:field_1 => 'field')  } }
    threads << Thread.new { 10.times { Document.all.each { |d| d.update_attributes(:field_1 => 'bye') } } }
    threads << Thread.new { 10.times { AnotherDocument.all.each { |d| d.update_attributes(:field_1 => 'bye') } } }
    threads.each(&:join)

    Document.all.count.should == 10
    AnotherDocument.all.count.should == 10
  end

  it 'can nest transactions' do
    Yapper::DB.instance.execute do |txn|
      Document.create(:field_1 => '1')
      Yapper::DB.instance.execute do |txn|
        Document.create(:field_1 => '2')
      end
    end
    Document.all.count.should == 2
  end

  it 'has an alias on Yapper module for transactions' do
    Yapper.transaction do
      Document.create(:field_1 => '1')
      Document.create(:field_1 => '2')
    end
    Document.all.count.should == 2
  end
end
