describe 'Criteria' do
  before do
    class ViewDocument
      include Yapper::Document

      field :field1, :type => Integer
      field :field2, :type => String
    end
    class AnotherViewDocument
      include Yapper::Document

      field :field1, :type => String
    end
    class View
      include Yapper::View

      view(1) do
        group do |doc|
          if doc.class == ViewDocument
            'default'
          end
        end

        sort do |group, doc_1, doc_2|
          if group == 'default'
            doc_1.field1 <=> doc_2.field1
          end
        end
      end
    end
  end
  before { Yapper::DB.instance.purge }
  after { Object.send(:remove_const, 'ViewDocument') }
  after { Object.send(:remove_const, 'AnotherViewDocument') }
  after { Object.send(:remove_const, 'View') }

  describe 'when changing the view version' do
    it "reindexes the fields" do
      ViewDocument.create(:field1 => 1)
      ViewDocument.create(:field1 => 2)

      View['default', 0].field1.should == 1

      View.class_eval do
        view(2) do
          group do |doc|
            if doc.class == ViewDocument
              'another_group'
            end
          end

          sort do |group, doc_1, doc_2|
            if group == 'another_group'
              doc_2.field1 <=> doc_1.field1
            end
          end
        end
      end

      View['another_group', 0].field1.should == 2
    end
  end

  describe 'with modifications made to the dependent models' do
    it 'the view reflects the changes' do
      AnotherViewDocument.create(:field1 => 0)
      ViewDocument.create(:field1 => 3)
      ViewDocument.create(:field1 => 1)
      ViewDocument.create(:field1 => 2)

      View['default', 0].field1.should == 1
      View['default', 1].field1.should == 2
      View['default', 2].field1.should == 3
    end
  end
end
