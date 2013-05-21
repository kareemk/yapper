describe 'multi-threaded' do
  before do
    class Document
      include Nanoid::Document

      field :field_1
      field :field_2
    end
    class AnotherDocument
      include Nanoid::Document

      field :field_1
      field :field_2
    end
  end
  after { Nanoid::DB.purge }
  after { Object.send(:remove_const, 'Document') }
  after { Object.send(:remove_const, 'AnotherDocument') }

  it 'behaves safely' do
    threads = []
    threads << Thread.new { 10.times { Document.create(:field_1 => 'field') } }
    threads << Thread.new { 10.times { AnotherDocument.create(:field_1 => 'field') } }
    threads << Thread.new { 10.times { Document.all.each { |d| d.update_attributes(:field_1 => 'bye') } } }
    threads << Thread.new { 10.times { AnotherDocument.all.each { |d| d.update_attributes(:field_1 => 'bye') } } }
    threads.each(&:join)

    # AnotherDocument.all.count.should == 10
    Document.all.count.should == 10
  end
end
