describe 'Watches' do
  before do
    class WatchDocument
      include Yapper::Document

      field :field1
      field :field2
    end
  end
  before { Yapper::DB.instance.purge }
  after { Object.send(:remove_const, 'WatchDocument') }
  after { @watch.end }

  describe 'watching collection' do
    it 'for CUD only executes the block when the document exists' do
      @watched_changes = 0

      WatchDocument.create(:field1 => 'field1', :field2 => 'field2')

      @watched_changes.should == 0

      @watch = WatchDocument.watch do
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

            @watch.end

            WatchDocument.create(:field1 => 'field1', :field2 => 'field2')

            wait 0.1 do
              @watched_changes.should == 3
            end
          end
        end
      end
    end

    it 'if a doc is touched the block is executed' do
      @watched_changes = 0

      doc = WatchDocument.create(:field1 => 'field1', :field2 => 'field2')

      @watch = WatchDocument.watch do
        @watched_changes += 1
      end

      doc.touch

      wait 0.1 do
        @watched_changes.should == 1
      end
    end
  end

  describe "watching collection for a specifc document that doesn't exist yet" do
    it 'executes the block when the document is created' do
      @watched_changes = 0

      doc = WatchDocument.new

      @watch = WatchDocument.watch(doc.id) do
        @watched_changes += 1
      end

      WatchDocument.create(:field1 => 'field1', :field2 => 'field2')

      @watched_changes.should == 0

      doc.save

      wait 0.1 do
        @watched_changes.should == 1

        doc.update_attributes(:field1 => 'field1_updated')

        wait 0.1 do
          @watched_changes.should == 2

          @watch.end

          doc.update_attributes(:field1 => 'field1_updated_again')

          wait 0.1 do
            @watched_changes.should == 2
          end
        end
      end
    end
  end

  describe "watching document" do
    it 'for CUD only executes the block when the document exists' do
      doc = WatchDocument.create(:field1 => 'field1', :field2 => 'field2')

      @watched_changes = 0

      @watch = doc.watch do
        @watched_changes += 1
      end

      doc.update_attributes(:field1 => 'field1_updated')

      wait 0.1 do
        @watched_changes.should == 1

        @watch.end

        doc.update_attributes(:field1 => 'field1_updated1')

        wait 0.1 do
          @watched_changes.should == 1

          @watch = doc.watch do
            @watched_changes += 1
          end

          doc.destroy

          wait 0.1 do
            @watched_changes.should == 2
          end
        end
      end
    end
  end

  describe "watching view" do
    before do
      class WatchView
        include Yapper::View

        view(1) do
          group do |doc|
            if doc.class == WatchDocument
              doc.field1
            end
          end

          sort do |group, doc_1, doc_2|
            doc_1.field2 <=> doc_2.field2
          end
        end
      end
    end
    after { Object.send(:remove_const, 'WatchView') }

    context 'watching all groups' do
      it 'immediately has up-to-date mapping information' do
        WatchDocument.create(:field1 => 'group1', :field2 => '1')
        @watch = WatchView.watch(['group1', 'group2'])

        @watch.mapping.numberOfItemsInSection(0).should == 1
      end

      it 'for CUD passes all changes to the block' do
        @watched_changes = []

        doc = WatchDocument.create(:field1 => 'group1', :field2 => '1')
        WatchDocument.create(:field1 => 'group1', :field2 => '2')
        WatchDocument.create(:field1 => 'group2', :field2 => '3')
        WatchDocument.create(:field1 => 'group2', :field2 => '4')

        wait 0.1 do
          @watched_changes.should == []

          @watch = WatchView.watch(['group1', 'group2']) do |changes|
            @watched_changes << changes
          end

          doc.update_attributes(:field1 => 'group2')

          wait 0.1 do
            @watched_changes.count.should == 1

            changes = @watched_changes.first
            changes.sections.count.should == 0
            changes.rows.count.should == 1
            changes.rows.first.type.should == :move
            changes.rows.first.from.should == NSIndexPath.indexPathForRow(0, inSection: 0)
            changes.rows.first.to.should == NSIndexPath.indexPathForRow(0, inSection: 1)

            @watch.end

            doc.update_attributes(:field1 => 'field1_updated1')

            wait 0.1 do
              @watched_changes.count.should == 1
            end
          end
        end
      end
    end
  end
end

describe "Relation with child touching parent" do
  before do
    class ParentDocument
      include Yapper::Document

      field :field_1

      has_many :child_documents
    end
    class ChildDocument
      include Yapper::Document

      field :field_1

      belongs_to :parent_document, touch: true
    end
  end
  before { Yapper::DB.instance.purge }
  after { Object.send(:remove_const, 'ParentDocument') }
  after { Object.send(:remove_const, 'ChildDocument') }
  after { @watch.end }

  it "creating a child document executes parents watch block" do
    parent = ParentDocument.create(:field_1 => 'field_1')

    @watched_changes = 0

    @watch = parent.watch { @watched_changes += 1 }

    ChildDocument.create(:parent_document => parent)

    wait 0.1 do
      @watched_changes.should == 1
    end
  end

  it "updating a child document executes parents watch block" do
    parent = ParentDocument.create(:field_1 => 'field_1')
    child = ChildDocument.create(:parent_document => parent)

    @watched_changes = 0

    @watch = parent.watch { @watched_changes += 1 }

    child.update_attributes(:field_1 => 'field_1')

    wait 0.1 do
      @watched_changes.should == 1
    end
  end

  it "deleting a child document executes parents watch block" do
    parent = ParentDocument.create(:field_1 => 'field_1')
    child = ChildDocument.create(:parent_document => parent)

    @watched_changes = 0

    @watch = parent.watch { @watched_changes += 1 }

    child.destroy

    wait 0.1 do
      @watched_changes.should == 1
    end
  end
end
