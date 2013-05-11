describe 'Nanoid document 1:N relationship' do
  before do
    class ParentDocument
      include Nanoid::Document

      field :field_1

      has_many :child_documents
    end
    class ChildDocument
      include Nanoid::Document

      field :field_1

      belongs_to :parent_document
    end
  end
  after { Nanoid::DB.purge }
  after { ['ParentDocument', 'ChildDocument'].each { |klass| Object.send(:remove_const, klass) } }

  describe 'with a parent with many children' do
    before do
      @parent = ParentDocument.create(:field_1 => 'parent')
      3.times { ChildDocument.create(:parent_document => @parent) }
    end

    it 'the child can access the parent' do
      @parent.reload

      @parent.child_documents.count.should == 3
      @parent.child_documents.each { |doc| doc.class.should == ChildDocument }
    end

    it 'the parent can access the child' do
      ChildDocument.all.each { |doc| doc.parent_document.id.should == @parent.id }
    end

    describe 'when a child is destroyed' do
      before do
        @last_id = ChildDocument.all.last.id
        ChildDocument.all.last.destroy
      end

      it 'the child is removed from the parent' do
        @parent.reload

        @parent.child_documents.count.should == 2
        @parent.child_documents.collect(&:id).each { |id| id.should.not == @last_id }
      end
    end
  end

end
