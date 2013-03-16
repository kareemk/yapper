module Nanoid::Document::Selection
  def find(id)
    search = NSFNanoSearch.searchWithStore(self.store)
    search.key = id

    error_ptr = Pointer.new(:id)
    result = search.searchObjectsWithReturnType(NSFReturnObjects, error:error_ptr).first
    raise NanoStoreError, error_ptr[0].description if error_ptr[0]

    result.last if result
  end
end
