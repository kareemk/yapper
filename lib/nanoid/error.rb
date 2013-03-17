module Nanoid::Error
  class DB < StandardError; end

  def raise_if_error(error_ptr)
    raise DB, error_ptr[0].description if error_ptr[0]
  end
end

