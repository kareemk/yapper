describe 'Yapper timestamps' do
  before do
    class Document
      include Yapper::Document
      include Yapper::Timestamps

      field :field_1
    end
  end
  before { Yapper::DB.default.purge }
  after { Object.send(:remove_const, 'Document') }

  describe 'when a document is created' do
    before { @document = Document.create(:field_1 => 'field_1') }

    it 'adds updated_at and created_at timestamps' do
      @document.created_at.should.be same_time_as(Time.now)
      @document.updated_at.should.be same_time_as(Time.now)
    end
  end

  describe 'when a document is updated' do
    before do
      @document = Document.create(:field_1 => '1')
      @created_at = @document.created_at
      @document.update_attributes(:field_1 => '2')
    end

    it 'only updates the updated_at field' do
      @document.created_at.should == @created_at
      @document.updated_at.should.be same_time_as(Time.now)
    end
  end
end
