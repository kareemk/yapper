describe '#watch' do
  before do
    class WatchDocument
      include Yapper::Document

      field :field1
      field :field2
    end
  end
  before { Yapper::DB.instance.purge }
  after { Object.send(:remove_const, 'WatchDocument') }

  describe 'watching collection' do
    it 'for CUD only executes the block when the document exists' do
      @watched_changes = 0

      WatchDocument.create(:field1 => 'field1', :field2 => 'field2')

      @watched_changes.should == 0

      watch = WatchDocument.watch do
        @watched_changes += 1
      end

      doc = WatchDocument.create(:field1 => 'field1', :field2 => 'field2')

      wait 0.1 do
        @watched_changes.should == 1

        doc.update_attributes(:field1 => 'field1_updated')

        wait 0.1 do
          @watched_changes.should == 2

          doc.destroy

          wait 0.1 do
            @watched_changes.should == 3

            watch.destroy

            WatchDocument.create(:field1 => 'field1', :field2 => 'field2')

            wait 0.1 do
              @watched_changes.should == 3
            end
          end
        end
      end
    end
  end
end
