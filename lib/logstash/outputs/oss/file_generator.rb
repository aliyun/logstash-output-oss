# encoding: utf-8

require 'uuid'
require 'logstash/outputs/oss/gzip_file'
require 'logstash/outputs/oss/temporary_file'

module LogStash
  module Outputs
    class OSS
      class FileGenerator
        FILE_MODE = "a"
        STRFTIME = "%Y-%m-%dT%H.%M"

        attr_accessor :index, :prefix, :encoding, :temporary_directory, :current_file

        # `prefix`/logstash.oss.{random-uuid}.{%Y-%m-%dT%H.%M}.part-{index}.{extension}
        def initialize(prefix, encoding, temporary_directory)
          @index = 0
          @prefix = prefix
          # gzip or plain
          @encoding = encoding
          # temporary directory to save temporary file before upload to OSS
          @temporary_directory = temporary_directory

          @lock = Mutex.new

          rotate
        end

        def rotate
          @current_file = create_file
          @index += 1
          @current_file
        end

        def with_lock
          @lock.synchronize do
            yield self
          end
        end

        def extension
          @encoding == "gzip" ? "gz" : "data"
        end

        def gzip?
          @encoding == "gzip"
        end

        private
        def create_file
          uuid = SecureRandom.uuid
          file_name = "ls.oss.#{uuid}.#{Time.now.strftime(STRFTIME)}.part-#{index}.#{extension}"
          object_key = ::File.join(prefix, file_name)
          local_path = ::File.join(temporary_directory, uuid)

          FileUtils.mkdir_p(::File.join(local_path, prefix))
          file = if gzip?
                   GzipFile.new(::File.open(::File.join(local_path, object_key), FILE_MODE))
                 else
                   ::File.open(::File.join(local_path, object_key), FILE_MODE)
                 end

          TemporaryFile.new(file, object_key, local_path)
        end

        unless SecureRandom.respond_to?(:uuid)
          module SecureRandom
            def self.uuid
              ary = random_bytes(16).unpack("NnnnnN")
              ary[2] = (ary[2] & 0x0fff) | 0x4000
              ary[3] = (ary[3] & 0x3fff) | 0x8000
              "%08x-%04x-%04x-%04x-%04x%08x" % ary
            end
          end
        end
      end
    end
  end
end