# encoding: utf-8
module LogStash
  module Outputs
    class OSS
      class SizeBasedRotation
        attr_reader :size_rotate

        def initialize(size_rotate)
          if size_rotate <= 0
            raise LogStash::ConfigurationError, "Logstash OSS output has wrong configuration: size_rotate must be positive if strategy is `size`"
          end
          @size_rotate = size_rotate
        end

        def rotate?(file)
          file.size >= @size_rotate
        end

        def needs_periodic_check?
          false
        end
      end
    end
  end
end
