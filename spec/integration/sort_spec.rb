describe 'Nanoid sorting documents' do
  before do
    class SortDocument
      include Nanoid::Document

      field :text
      field :date
    end
  end
  after { Object.send(:remove_const, 'SortDocument') }
  after { Nanoid::DB.purge }

  describe 'with text field' do
    before do
      SortDocument.create(:text => 'apple')
      SortDocument.create(:text => 'squash')
      SortDocument.create(:text => 'carrot')
    end
    it 'can sort documents ascending' do
      SortDocument.asc(:text).collect(&:text).should == ['apple', 'carrot', 'squash']
    end

    it 'can sort documents descending' do
      SortDocument.desc(:text).collect(&:text).should == ['squash', 'carrot', 'apple']
    end
  end

  describe 'with date field' do
    before do
      SortDocument.create(:date => Time.utc(2013,1,1,10,00))
      SortDocument.create(:date => Time.utc(2013,1,1,9,00))
      SortDocument.create(:date => Time.utc(2013,1,1,14,00))
    end
    it 'can sort documents ascending' do
      SortDocument.asc(:date).collect(&:date).should == [Time.utc(2013,1,1,9,00), Time.utc(2013,1,1,10,00), Time.utc(2013,1,1,14,00)]
    end

    it 'can sort documents descending' do
      SortDocument.desc(:date).collect(&:date).should == [Time.utc(2013,1,1,14,00), Time.utc(2013,1,1,10,00), Time.utc(2013,1,1,9,00)]
    end
  end
end
