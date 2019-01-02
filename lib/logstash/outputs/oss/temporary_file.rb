# encoding: utf-8

module LogStash
  module Outputs
    class OSS
      class TemporaryFile
        extend Forwardable

        def_delegators :@file, :path, :write, :close, :fsync

        attr_reader :file

        def initialize(file, object_key, temporary_path)
          @file = file
          @object_key = object_key
          @temporary_path = temporary_path
          @creation_time = Time.now
        end

        def ctime
          @creation_time
        end

        def temporary_path
          @temporary_path
        end

        def size
          begin
            @file.size
          rescue IOError
            ::File.size(path)
          end
        end

        def key
          @object_key.gsub(/^\//, "")
        end

        def delete!
          @file.close rescue IOError
          FileUtils.rm_r(@temporary_path, :secure => true)
        end

        def empty?
          size == 0
        end

        def self.create_existing_file(path, temporary_directory)
          # path is #{temporary_directory}/${uuid}/${prefix}/${key}
          elements = Pathname.new(path).relative_path_from(Pathname.new(temporary_directory)).to_s.split(::File::SEPARATOR)
          uuid = elements[0]
          object_key = ::File.join(elements.slice(1, elements.size - 1))
          TemporaryFile.new(::File.open(path, "r"), object_key, ::File.join(temporary_directory, uuid))
        end
      end
    end
  end
end