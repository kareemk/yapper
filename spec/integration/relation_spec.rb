describe 'Yapper document 1:N relationship' do
  before do
    class ParentDocument
      include Yapper::Document

      field :field_1

      has_many :child_documents
    end
    class ChildDocument
      include Yapper::Document

      field :field_1
      field :field_2

      belongs_to :parent_document
    end
  end
  before { Yapper::DB.instance.purge }
  after  { ['ParentDocument', 'ChildDocument'].each { |klass| Object.send(:remove_const, klass) } }

  describe 'nested child attributes' do
    it 'can accept nested attributes' do
      @parent = ParentDocument.create(:field_1 => 'parent',
                                      :child_documents => [
                                        { :field_1 => 'child0' },
                                        { :field_1 => 'child1' }
                                      ])

      @parent.field_1.should == 'parent'
      @parent.child_documents.to_a.collect(&:field_1).should == ['child0', 'child1']
    end

    it 'can accept an nested attributes with ids' do
      children = 2.times.map { |i| { :id => BSON::ObjectId.generate, :field_1 => "child#{i}" } }
      @parent = ParentDocument.create(:field_1 => 'parent',
                                      :child_documents => children)

      children.each do |child|
        ChildDocument.find(child[:id]).should.not == nil
      end
    end

    it 'can accept array of initialized children' do
      children = 2.times.map { |i| ChildDocument.new(:field_1 => "child#{i}") }
      @parent = ParentDocument.create(:field_1 => 'parent',
                                      :child_documents => children)

      @parent.field_1.should == 'parent'
      @parent.child_documents.to_a.collect(&:field_1).should == ['child0', 'child1']
    end

    it 'can accept array of created children' do
      children = 2.times.map { |i| ChildDocument.create(:field_1 => "child#{i}") }
      @parent = ParentDocument.create(:field_1 => 'parent',
                                      :child_documents => children)

      @parent.field_1.should == 'parent'
      @parent.child_documents.to_a.collect(&:field_1).should == ['child0', 'child1']
    end

    it 'can update a child document via nested attributes' do
      children = 2.times.map { |i| { :id => BSON::ObjectId.generate,
                                      :field_1 => "child#{i}",
                                      :field_2 => 'value' } }
      @parent = ParentDocument.create(:field_1 => 'parent',
                                      :child_documents => children)
      @parent.update_attributes(:child_documents => [{ :id      => children[0][:id],
                                                       :field_1 => 'updated0' },
                                                     { :id      => children[1][:id],
                                                       :field_1 => 'updated1' }])

      children.each_with_index do |child, i|
        ChildDocument.find(child[:id]).field_1.should == "updated#{i}"
        ChildDocument.find(child[:id]).field_2.should == "value"
      end
    end

    describe 'nested parent attributes' do
      it 'can accept an nested attributes with ids' do
        parent = { :id => BSON::ObjectId.generate, :field_1 => "parent" }

        ChildDocument.create(:field_1 => 'child',
                             :parent_document => parent)

        ParentDocument.find(parent[:id]).should.not == nil
        ParentDocument.find(parent[:id]).field_1.should == 'parent'
      end

      it 'can update a child document via nested attributes' do
        @parent = ParentDocument.create(:field_1 => 'created')
        parent = { :id => @parent.id, :field_1 => 'updated' }

        ChildDocument.create(:field_1 => 'child',
                             :parent_document => parent)

        @parent.reload.field_1.should == 'updated'
      end
    end
  end

  it 'can set a parent to nil' do
    child = ChildDocument.create(:field_1 => 'child_field',
                                 :parent_document => nil)

    child.field_1.should == 'child_field'
  end

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
        @parent.child_documents.to_a.collect(&:id).each { |id| id.should.not == @last_id }
      end
    end
  end

  describe 'with a before_save callback on the child that references the parent document' do
    before do
      ChildDocument.class_eval do
        before_save :set_field_2

        def set_field_2
          self.field_2 = self.parent_document.id
        end
      end
    end

    it 'includes parent relation in the callback' do
      @parent = ParentDocument.create(:field_1 => 'parent',
                                      :child_documents => [{ :field_1 => "value" }])

      @parent.child_documents.first.field_2.should == @parent.id
    end
  end
end

describe 'Yapper document 1:N:1 relationship' do
  before do
    class Parent1
      include Yapper::Document

      field :field_1

      has_many :child_documents
    end
    class Parent2
      include Yapper::Document

      field :field_1

      has_many :child_documents
    end
    class ChildDocument
      include Yapper::Document

      field :field_1

      belongs_to :parent1
      belongs_to :parent2
    end
  end
  after { Yapper::DB.instance.purge }
  after { ['Parent1', 'Parent2', 'ChildDocument'].each { |klass| Object.send(:remove_const, klass) } }

  it 'can create child with many parents' do
    parent1 = Parent1.create(:field_1 => 'parent1')
    parent2 = Parent2.create(:field_1 => 'parent2')

    child = ChildDocument.create(:parent1 => parent1, :parent2 => parent2)

    child.parent1.field_1.should == 'parent1'
    child.parent2.field_1.should == 'parent2'
  end
end

describe 'Yapper dependent destroy' do
  before do
    class ParentDocument
      include Yapper::Document

      field :field_1

      has_many :child_documents
      has_many :child_dependent_documents, dependent: :destroy
    end
    class ChildDocument
      include Yapper::Document

      field :field_1

      belongs_to :parent_document
    end
    class ChildDependentDocument
      include Yapper::Document

      field :field_1

      belongs_to :parent_document
    end
  end
  after { Yapper::DB.instance.purge }
  after { ['ParentDocument', 'ChildDocument', 'ChildDependentDocument'].each { |klass| Object.send(:remove_const, klass) } }

  it 'destroys child documents when the parent is destroyed' do
    parent = ParentDocument.create(:field_1 => 'field_1')
    ChildDocument.create(:parent_document => parent)
    ChildDependentDocument.create(:parent_document => parent)

    ChildDocument.count.should == 1
    ChildDependentDocument.count.should == 1

    parent.destroy

    ChildDocument.count.should == 1
    ChildDependentDocument.count.should == 0
  end

  it 'destroys all child documents if all parentes are destroyed with #delete_all' do
    parent = ParentDocument.create(:field_1 => 'field_1')
    ChildDocument.create(:parent_document => parent)
    ChildDependentDocument.create(:parent_document => parent)

    ChildDocument.count.should == 1
    ChildDependentDocument.count.should == 1

    ParentDocument.delete_all

    ChildDocument.count.should == 1
    ChildDependentDocument.count.should == 0
  end
end
