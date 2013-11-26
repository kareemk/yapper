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
      field :field_2

      belongs_to :parent_document
    end
  end
  after { Nanoid::DB.purge }
  after { ['ParentDocument', 'ChildDocument'].each { |klass| Object.send(:remove_const, klass) } }

  it 'can accept nested attributes' do
    @parent = ParentDocument.create(:field_1 => 'parent',
                                    :child_documents => [
                                      { :field_1 => 'child0' },
                                      { :field_1 => 'child1' }
                                    ])

    @parent.field_1.should == 'parent'
    @parent.child_documents.collect(&:field_1).tap do |field_1|
      field_1.include?('child0').should == true
      field_1.include?('child1').should == true
    end
  end

  it 'can accept array of initialized children' do
    children = []
    2.times { |i| children << ChildDocument.new(:field_1 => "child#{i}") }
    @parent = ParentDocument.create(:field_1 => 'parent',
                                    :child_documents => children)

    @parent.field_1.should == 'parent'
    @parent.child_documents.collect(&:field_1).tap do |field_1|
      field_1.include?('child0').should == true
      field_1.include?('child1').should == true
    end
  end

  it 'can accept array of created children' do
    children = []
    2.times { |i| children << ChildDocument.create(:field_1 => "child#{i}") }
    @parent = ParentDocument.create(:field_1 => 'parent',
                                    :child_documents => children)

    @parent.field_1.should == 'parent'
    @parent.child_documents.collect(&:field_1).tap do |field_1|
      field_1.include?('child0').should == true
      field_1.include?('child1').should == true
   end
  end

  it 'can accept an array of hashes' do
    children = []
    2.times { |i| children << { :field_1 => "child#{i}" } }
    @parent = ParentDocument.create(:field_1 => 'parent',
                                    :child_documents => children)

    @parent.child_documents.collect(&:field_1).tap do |field_1|
      field_1.include?('child0').should == true
      field_1.include?('child1').should == true
   end
  end

  it 'can accept an array of hashes with ids' do
    children = []
    2.times { |i| children << { :id => BSON::ObjectId.generate, :field_1 => "child#{i}" } }
    @parent = ParentDocument.create(:field_1 => 'parent',
                                    :child_documents => children)

    children.each do |child|
      ChildDocument.find(child[:id]).should.not == nil
    end
  end

  it 'can update a child document via an array of hashes' do
    children = []
    2.times { |i| children << { :id => BSON::ObjectId.generate,
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
        @parent.child_documents.collect(&:id).each { |id| id.should.not == @last_id }
      end
    end
  end
end

describe 'Nanoid document 1:N:1 relationship' do
  before do
    class Parent1
      include Nanoid::Document

      field :field_1

      has_many :child_documents
    end
    class Parent2
      include Nanoid::Document

      field :field_1

      has_many :child_documents
    end
    class ChildDocument
      include Nanoid::Document

      field :field_1

      belongs_to :parent1
      belongs_to :parent2
    end
  end
  after { Nanoid::DB.purge }
  after { ['Parent1', 'Parent2', 'ChildDocument'].each { |klass| Object.send(:remove_const, klass) } }

  it 'can create child with many parents' do
    parent1 = Parent1.create(:field_1 => 'parent1')
    parent2 = Parent2.create(:field_1 => 'parent2')

    child = ChildDocument.create(:parent1 => parent1, :parent2 => parent2)

    child.parent1.field_1.should == 'parent1'
    child.parent2.field_1.should == 'parent2'
  end
end
