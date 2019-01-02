# encoding: utf-8
module LogStash
  module Outputs
    class OSS
      class TimeBasedRotation
        attr_reader :time_rotate

        def initialize(time_rotate)
          if time_rotate <= 0
            raise LogStash::ConfigurationError, "Logstash OSS output has wrong configuration: time_rotate must be positive if strategy is `time`"
          end
          @time_rotate = time_rotate * 60
        end

        def rotate?(file)
          file.size > 0 && (Time.now - file.ctime) >= @time_rotate
        end

        def needs_periodic_check?
          true
        end
      end
    end
  end
end