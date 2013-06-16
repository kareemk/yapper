describe 'Nanoid selecting documents' do
  before do
    class SelectionDocument
      include Nanoid::Document

      field :field1
      field :field2
    end
    class AnotherSelectionDocument
      include Nanoid::Document

      field :field1
      field :field2
    end
  end
  after { Object.send(:remove_const, 'SelectionDocument') }
  after { Object.send(:remove_const, 'AnotherSelectionDocument') }
  after { Nanoid::DB.purge }

  describe 'with no documents created' do
    it 'returns nil when looking up a document' do
      SelectionDocument.find('xxx').should == nil
    end
  end

  describe 'with a few documents created with string fields' do
    before do
      @doc = SelectionDocument.create(:field1 => 'field1_value', :field2 => 'field2_value')
      SelectionDocument.create(:field1 => 'field1_value', :field2 => 'field2_value')
      SelectionDocument.create(:field1 => 'field1_value', :field2 => 'field2_other_value')
      SelectionDocument.create(:field1 => 'field1_other_value', :field2 => 'field2_other_value')
      AnotherSelectionDocument.create(:field1 => 'field1_value', :field2 => 'field2_value')
    end

    describe 'with #find' do
      it 'can select document' do
        SelectionDocument.find(@doc.id).field1.should == 'field1_value'
      end

      it 'has no changes when selecting a document' do
        SelectionDocument.find(@doc.id).changes.should == {}
      end

      it 'returns nil when looking up a non-existant doc' do
        SelectionDocument.find('xxx').should == nil
      end

      it 'returns nil when looking up nil' do
        SelectionDocument.find(nil).should == nil
      end
    end

    describe 'with #where' do
      it 'only selects documents of its on type' do
        SelectionDocument.where(:field1 => 'field1_value').each { |d| d._type.should == 'SelectionDocument' }
      end

      it 'can select document by matching on a field' do
        SelectionDocument.where(:field1 => 'field1_value').each { |d| d.field1.should == 'field1_value' }
      end

      it 'returns nil when looking up a non-existant doc' do
        SelectionDocument.where(:field1 => 'xxx').count.should == 0
      end

      it 'can select docments matching on multiple fields' do
        SelectionDocument.where(:field1 => 'field1_value', :field2 => 'field2_value').each do |doc|
          doc.field1.should == 'field1_value'
          doc.field2.should == 'field2_value'
        end
      end
    end

    describe 'with #all' do
      it 'selects all documents' do
        SelectionDocument.all.count.should == 4
        SelectionDocument.all.first.class.should == SelectionDocument
      end
    end
  end
end
