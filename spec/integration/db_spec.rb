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
      Document.create(:field_1 => '2')
    end
    Document.all.count.should == 2
  end

  describe 'notifications' do
    before { @notification_center = NSNotificationCenter.defaultCenter }

    before do
      @notified = false
      @notified_docs = nil
      @observer = @notification_center.observe 'yapper:document:save' do |data|
        @notified = true
        @notified_docs = data.object
      end
    end

    after  { @notification_center.unobserve(@observer) }

    it 'notifies on creation' do
      Document.create(:field_1 => 'field_1')

      @notified.should == true
      @notified_docs.count.should == 1
      @notified_docs.first.field_1.should == 'field_1'
    end

    it 'notifies on updates' do
      doc = Document.create(:field_1 => 'field_1')
      doc.update_attributes(:field_1 => 'field_1_updated')

      @notified.should == true
      @notified_docs.count.should == 1
      @notified_docs.first.field_1.should == 'field_1_updated'
    end

    it 'notifies on destroy' do
      doc = Document.create(:field_1 => 'field_1')
      doc.destroy

      @notified.should == true
      @notified_docs.count.should == 1
      @notified_docs.first.destroyed.should == true
    end

    it 'queues updates that are part of a transaction' do
      Yapper::DB.instance.execute do
        doc = Document.create(:field_1 => 'field_1')

        @notified.should == false

        doc.update_attributes(:field_1 => 'field_1_updated')
      end

      @notified.should == true
      @notified_docs.count.should == 2
    end

    describe 'when persisting on a different thread' do
      before do
        @query_observer = @notification_center.observe 'yapper:document:save' do |data|
          Document.all.count
        end
      end

      after  { @notification_center.unobserve(@query_observer) }

      it "doesn't deadlock" do
        Dispatch::Queue.concurrent.sync { Document.create(:field_1 => 'field_1') }

        @notified.should == true
      end
    end
  end
end
