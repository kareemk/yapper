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
        self.field_1 = 'before_save'
      end

      def do_another_before_save
        self.field_2 = 'before_save'
      end

      def do_after_save
        self.field_1 = 'after_save'
      end

      def do_another_after_save
        self.field_2 = 'after_save'
      end
    end
  end
  after { Object.send(:remove_const, 'CallbackDocument') }

  describe 'creating documents' do
    it 'before and after callbacks are fired' do
      doc = CallbackDocument.create(:field_1 => 'field1',
                                    :field_2 => 'field2')

      doc.field_1.should == 'after_save'
      doc.field_2.should == 'after_save'
      doc.reload
      doc.field_1.should == 'before_save'
      doc.field_2.should == 'before_save'
    end
  end

  describe 'updating documents' do
    before do
      @doc = CallbackDocument.create(:field_1 => 'field1')
      @doc.reload
    end

    it 'before and after callbacks are fired' do
      @doc.field_1 = 'field1_updated'
      @doc.save

      @doc.field_1.should == 'after_save'
      @doc.field_2.should == 'after_save'
      @doc.reload
      @doc.field_1.should == 'before_save'
      @doc.field_2.should == 'before_save'
    end
  end
end
