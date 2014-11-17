class ProcessingError < RuntimeError
end

module Helpers
  private

  def self.fail(message)
    raise ProcessingError.new(message)
  end

  def fail(message)
    raise ProcessingError.new(message)
  end

  def say(message)
    puts message  unless $options.quiet
  end
end
