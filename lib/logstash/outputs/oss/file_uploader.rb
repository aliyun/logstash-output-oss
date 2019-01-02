# encoding: utf-8
require 'java'
java_import 'com.aliyun.oss.model.ObjectMetadata'
java_import 'java.io.FileInputStream'

module LogStash
  module Outputs
    class OSS
      class FileUploader
        TIME_BEFORE_RETRY_SECONDS = 3

        attr_reader :oss, :bucket, :additional_oss_settings, :logger

        def initialize(oss, bucket, additional_oss_settings, logger, thread_pool)
          @oss = oss
          @bucket = bucket
          @additional_oss_settings = additional_oss_settings
          @logger = logger
          @thread_pool = thread_pool
        end

        def upload_async(file, options = {})
          @thread_pool.post do
            LogStash::Util.set_thread_name("Logstash OSS Output Plugin: output uploader, file: #{file.path}")
            upload(file, options)
          end
        end

        def upload(file, options = {})
          meta = ObjectMetadata.new
          meta.setContentLength(file.size)
          unless @additional_oss_settings.nil?
            if @additional_oss_settings.include?(LogStash::Outputs::OSS::SERVER_SIDE_ENCRYPTION_ALGORITHM_KEY)
              unless @additional_oss_settings[LogStash::Outputs::OSS::SERVER_SIDE_ENCRYPTION_ALGORITHM_KEY].empty?
                meta.setServerSideEncryption(@additional_oss_settings[LogStash::Outputs::OSS::SERVER_SIDE_ENCRYPTION_ALGORITHM_KEY])
              end
            end
          end

          stream = nil
          begin
            stream = FileInputStream.new(file.path)
            oss.putObject(@bucket, file.key, stream, meta)
          rescue Errno::ENOENT => e
            logger.error("Logstash OSS Output Plugin: file to be uploaded doesn't exist!", :exception => e.class, :message => e.message, :path => file.path, :backtrace => e.backtrace)
          rescue => e
            @logger.error("Logstash OSS Output Plugin: uploading failed, retrying.", :exception => e.class, :message => e.message, :path => file.path, :backtrace => e.backtrace)
            sleep TIME_BEFORE_RETRY_SECONDS
            retry
          ensure
            unless stream.nil?
              stream.close
            end
          end

          options[:on_complete].call(file) unless options[:on_complete].nil?
          rescue => e
            logger.error("Logstash OSS Output Plugin: an error occurred in the `on_complete` uploader", :exception => e.class, :message => e.message, :path => file.path, :backtrace => e.backtrace)
            raise e
        end

        def close
          @thread_pool.shutdown
          @thread_pool.wait_for_termination(nil)
        end
      end
    end
  end
end