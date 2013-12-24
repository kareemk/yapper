describe 'Nanoid callbacks' do
  before do
    class CallbackDocument
      include Nanoid::Document

      field :field_1
      field :field_2

      before_save :do_before_save
      before_save :do_another_before_save
      after_save  :do_after_save
      after_save  :do_another_after_save

      private

      def do_before_save
        $before_save_1 = true
      end

      def do_another_before_save
        $before_save_2 = true
      end

      def do_after_save
        $after_save_1 = true
      end

      def do_another_after_save
        $after_save_2 = true
      end
    end
  end
  after { Nanoid::DB.purge }
  after { Object.send(:remove_const, 'CallbackDocument') }

  describe 'creating documents' do
    it 'before and after callbacks are fired' do
      CallbackDocument.create(:field_1 => 'field1',
                              :field_2 => 'field2')

      $before_save_1.should == true
      $before_save_2.should == true
      $after_save_1.should == true
      $after_save_2.should == true
    end
  end

  describe 'updating documents' do
    before do
      @doc = CallbackDocument.create(:field_1 => 'field1')
      $before_save_1 = false
      $before_save_2 = false
      $after_save_1 = false
      $after_save_2 = false
    end

    it 'before and after callbacks are fired' do
      @doc.field_1 = 'field1_updated'
      @doc.save

      $before_save_1.should == true
      $before_save_2.should == true
      $after_save_1.should == true
      $after_save_2.should == true
    end
  end

  describe 'on failure' do
    before do
      class CallbackDocument
        after_save  :fail

        def fail
          raise "fail"
        end
      end
    end

    it 'rollsback the entire update' do
      lambda {
        CallbackDocument.create(:field_1 => 'field1')
      }.should.raise

      CallbackDocument.all.count.should == 0
    end
  end
end
