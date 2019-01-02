# encoding: utf-8

module LogStash
  module Outputs
    class OSS
      class GzipFile
        extend Forwardable

        def_delegators :@gzip_writer, :write, :close
        attr_reader :file, :gzip_writer

        def initialize(file)
          @file = file
          @gzip_writer = Zlib::GzipWriter.new(file)
        end

        def path
          @gzip_writer.to_io.path
        end

        def size
          if @gzip_writer.pos == 0
            0
          else
            @gzip_writer.flush
            @gzip_writer.to_io.size
          end
        end

        def fsync
          @gzip_writer.to_io.fsync
        end
      end
    end
  end
end
