describe 'Nanoid syncing documents' do
  extend WebStub::SpecHelpers

  before do
    class Document
      include Nanoid::Document
      include Nanoid::Sync

      field :field_1
      sync :to => '/api/documents', :auto => [:get, :save]

      def sync_as
        image = Nanoid::Sync::Data.new(:data => UIImagePNGRepresentation(UIImage.alloc.init),
                                       :fileName => 'file.png',
                                       :mimeType => 'image/png')
        {
          :field_1 => field_1,
          :image   => image
        }
      end
    end
  end
  before { Nanoid::Sync.base_url = 'http://example.com' }
  before { disable_network_access! }
  after  { enable_network_access! }
  after  { Nanoid::DB.purge }
  after  { Object.send(:remove_const, 'Document') }

  # TODO Webstub is not straighforward as body is not known at stub time
  # it 'on create' do
    # stub_request(:get, "http://example.com/api/documents").
      # with(:body => { document: { field_1: 'text' } }).
      # to_return(:json => { document: { field_1: 'text' } })

    # document = Document.create(:field_1 => 'text')

    # wait 2

    # document.reload
    # document._synced_at.should.not == nil
  # end
end
