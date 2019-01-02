# encoding: utf-8

module LogStash
  module Outputs
    class OSS
      class Version
        VERSION = "0.1.1"
        def self.version
          VERSION
        end
      end
    end
  end
end
