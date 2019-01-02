# encoding: utf-8

require "java"
require "concurrent"
require "concurrent/timer_task"
require "logstash/util"
require "logstash/outputs/oss/file_generator"

ConcurrentHashMap = java.util.concurrent.ConcurrentHashMap

module LogStash
  module Outputs
    class OSS
      class FileManager

        STALE_FILES_CHECK_INTERVAL_IN_SECONDS = 15 * 60

        def initialize(logger, encoding, temporary_directory)
          @logger = logger
          @encoding = encoding

          @temporary_directory = temporary_directory
          # map of generators
          # since `prefix` support string interpolation, so we will write many files at the same time
          @prefixed_generators = ConcurrentHashMap.new

          @file_generator_initialize = FileGeneratorInitializer.new(encoding, temporary_directory)

          start_stale_files_check
        end

        def get_file_generator(prefix)
          @prefixed_generators.computeIfAbsent(prefix, @file_generator_initialize).with_lock {|generator| yield generator}
        end

        def prefixes
          @prefixed_generators.keySet
        end

        private
        def remove_stale_files
          prefixes.each do |prefix|
            get_file_generator(prefix) do |file_generator|
              file = file_generator.current_file
              if file.size == 0 && Time.now - file.ctime > STALE_FILES_CHECK_INTERVAL_IN_SECONDS
                @logger.info("Logstash OSS Output Plugin starts to remove stale file",
                             :key => file.key,
                             :path => file.path,
                             :size => file.size,
                             :thread => Thread.current.to_s)
                @prefixed_generators.remove(prefix)
                file.delete!
              end
            end
          end
        end

        private
        def start_stale_files_check
          @stale_check = Concurrent::TimerTask.new(:execution_interval => STALE_FILES_CHECK_INTERVAL_IN_SECONDS) do
            @logger.info("Logstash OSS Output Plugin: start to check stale files")
            remove_stale_files
          end

          @stale_check.execute
        end

        public
        def close
          @stale_check.shutdown
        end

        class FileGeneratorInitializer
          include java.util.function.Function
          def initialize(encoding, temporary_directory)
            @encoding = encoding
            @temporary_directory = temporary_directory
          end

          def apply(prefix)
            FileGenerator.new(prefix, @encoding, @temporary_directory)
          end
        end
      end
    end
  end
end