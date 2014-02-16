motion_require 'document.rb'

module Yapper::Timestamps
  extend MotionSupport::Concern

  included do
    field :updated_at, :type => Time
    field :created_at, :type => Time

    before_save :set_timestamps
  end

  def set_timestamps
    now = Time.now
    self.created_at = now if created_at.nil?
    self.updated_at = now
  end
end
