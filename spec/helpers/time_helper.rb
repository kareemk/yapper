def same_time_as(time)
  lambda { |obj| time.is_a?(Time) && obj.is_a?(Time) && (time - obj) < 1.0 }
end
