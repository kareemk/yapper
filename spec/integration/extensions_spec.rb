describe 'extensions' do
  describe 'Hash#to_canonical' do
    it 'generates the same hash regardless of hash order' do
      {a: 'a', b: 'b'}.to_canonical.should == {b: 'b', a: 'a'}.to_canonical
    end

    it 'generates the same hash with embedded hashses' do
      {a: 'a', b: { c: 'c'}}.to_canonical.should == {a: 'a', b: { c: 'c'}}.to_canonical
    end
    it 'generates the same hash with embedded arrays' do
      {a: 'a', b: { c: ['c', 'b']}}.to_canonical.should == {a: 'a', b: { c: ['b', 'c']}}.to_canonical
    end
  end
end
