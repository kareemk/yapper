describe 'Yapper persisting documents with typed fields' do
  describe 'Time' do
    before do
      class Document
        include Yapper::Document

        field :time_field, :type => Time
      end
    end
    before { Yapper::DB.default.purge }
    after  { Object.send(:remove_const, 'Document') }

    it 'typecasts correctly' do
      time = Time.now
      Document.create(:time_field => time.to_s).time_field.should.be same_time_as(time)
    end

    # TODO Move to unit spec for Time extension
    it 'typecasts correctly with iso8601 dates' do
      Document.create(:time_field => "2013-04-27T17:56:37Z").time_field.should.be same_time_as(Time.parse('2013-04-27 17:56:37 +0000'))
    end
  end
end
