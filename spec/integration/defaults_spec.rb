describe 'Yapper document defaults' do
  describe "when using a value as a default" do
    before do
      class DefaultsDocument
        include Yapper::Document

        field :field_1, :default => false
      end
    end
    before { Yapper::DB.instance.purge }
    after  { Object.send(:remove_const, 'DefaultsDocument') }

    it "sets the default" do
      DefaultsDocument.create

      DefaultsDocument.all.first.field_1.should == false
    end
  end

  describe "when using a proc as a default" do
    before do
      class DefaultsDocument
        include Yapper::Document

        field :field_1, :default => proc { 10 }
      end
    end
    before { Yapper::DB.instance.purge }
    after  { Object.send(:remove_const, 'DefaultsDocument') }

    it "sets the default" do
      DefaultsDocument.create

      DefaultsDocument.all.first.field_1.should == 10
    end
  end
end
