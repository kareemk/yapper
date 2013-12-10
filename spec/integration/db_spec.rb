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
  after { Object.send(:remove_const, 'Document') }
  after { Object.send(:remove_const, 'AnotherDocument') }
  after { Nanoid::DB.purge }

  describe 'batching updates' do
    before do
      class Document
        before_save :inc_before_callback_counter
        after_save  :inc_after_callback_counter

        def inc_before_callback_counter
          $before_callback_counter += 1
        end

        def inc_after_callback_counter
          $after_callback_counter += 1
        end
      end
    end
    before { $before_callback_counter = 0 }
    before { $after_callback_counter = 0 }

    it 'postpones saves until completion of the block' do
      Nanoid::DB.default.batch do
        3.times { Document.create(:field_1 => 'saved') }

        Document.where(:field_1 => 'saved').count.should == 0
      end
      Document.where(:field_1 => 'saved').count.should == 3
    end

    it 'postpones after callbacks until completion of the block' do
      Nanoid::DB.default.batch do
        3.times { Document.create(:field_1 => 'saved') }

        $before_callback_counter.should == 3
        $after_callback_counter.should  == 0
      end

      $before_callback_counter.should == 3
      $after_callback_counter.should  == 3
    end
  end

  it 'behaves safely' do
    threads = []
    threads << Thread.new { 10.times { Document.create(:field_1 => 'field') } }
    threads << Thread.new { 10.times { AnotherDocument.create(:field_1 => 'field')  } }
    threads << Thread.new { 10.times { Document.all.each { |d| d.update_attributes(:field_1 => 'bye') } } }
    threads << Thread.new { 10.times { AnotherDocument.all.each { |d| d.update_attributes(:field_1 => 'bye') } } }
    threads.each(&:join)

    Document.all.count.should == 10
    AnotherDocument.all.count.should == 10
  end
end
