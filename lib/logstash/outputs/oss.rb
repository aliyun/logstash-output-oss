# encoding: utf-8
require "logstash/outputs/base"
require 'logstash-output-oss_jars'
require 'concurrent'

java_import "com.aliyun.oss.OSS"
java_import "com.aliyun.oss.OSSClientBuilder"
java_import "com.aliyun.oss.ClientBuilderConfiguration"

#
#  Logstash OSS Output Plugin
#
# Usage:
# In order to write output data to OSS, you should add configurations like below to logstash
# output {
#   oss {
#     "endpoint" => "OSS endpoint to connect to"              (required)
#     "bucket" => "Your bucket name"                          (required)
#     "access_key_id" => "Your access key id"                 (required)
#     "access_key_secret" => "Your access secret key"         (required)
#     "prefix" => "logstash/%{index}"                         (optional, default = "")
#     "recover" => true                                       (optional, default = true)
#     "rotation_strategy" => "size_and_time"                  (optional, default = "size_and_time")
#     "time_rotate" => 15                                     (optional, default = 15) - Minutes
#     "size_rotate" => 31457280                               (optional, default = 31457280) - Bytes
#     "encoding" => "none"                                    (optional, default = "none")
#     "additional_oss_settings" => {
#       "max_connections_to_oss" => 1024                      (optional, default = 1024)
#       "secure_connection_enabled" => false                  (optional, default = false)
#     }
#   }
# }
#
class LogStash::Outputs::OSS < LogStash::Outputs::Base
  require 'logstash/outputs/oss/rotations/hybrid_rotation'
  require 'logstash/outputs/oss/file_uploader'
  require 'logstash/outputs/oss/file_manager'
  require 'logstash/outputs/oss/version'

  ROTATE_CHECK_INTERVAL_IN_SECONDS = 15

  MAX_CONNECTIONS_TO_OSS_KEY = "max_connections_to_oss"

  SERVER_SIDE_ENCRYPTION_ALGORITHM_KEY = "server_side_encryption_algorithm"

  SECURE_CONNECTION_ENABLED_KEY = "secure_connection_enabled"

  config_name "oss"

  concurrency :shared

  default :codec, "line"

  # OSS bucket name
  config :bucket, :validate => :string, :required => true

  # OSS endpoint to connect
  config :endpoint, :validate => :string, :required => true

  # access key id
  config :access_key_id, :validate => :string, :required => true

  # access secret key
  config :access_key_secret, :validate => :string, :required => true

  # additional oss client configurations, valid keys are:
  # server_side_encryption_algorithm(server side encryption, only support AES256 now)
  # secure_connection_enabled(enable https or not)
  # max_connections_to_oss(max connections to oss)
  # TODO: add other oss configurations
  config :additional_oss_settings, :validate => :hash, :required => false

  # rotate this file if its size greater or equal than `size_rotate`
  config :size_rotate, :validate => :number, :default => 30 * 1024 * 1024

  # rotate this file if its life time greater or equal than `time_rotate`
  config :time_rotate, :validate => :number, :default => 15

  # if true, OSS plugin will recover files since last crash
  config :recover, :validate => :boolean, :default => true

  # temporary directory that used to cache event before upload to OSS
  config :temporary_directory, :validate => :string, :default => File.join(Dir.tmpdir, "logstash/oss")

  # prefix that added to generated file name
  # sample file name looks like
  # `prefix`/logstash.oss.{random-uuid}.{%Y-%m-%dT%H.%M}.part-{index}.{extension}
  # WARNING: this option support string interpolation, so it may create a lot of temporary local files
  config :prefix, :validate => :string, :default => ''

  # file rotation strategy
  config :rotation_strategy, :validate => %w(size time size_and_time), :default => "size_and_time"

  # concurrent number of upload threads
  config :upload_workers_count, :validate => :number, :default => (Concurrent.processor_count * 0.5).ceil

  # upload queue size
  config :upload_queue_size, :validate => :number, :default => 2 * (Concurrent.processor_count * 0.25).ceil

  # support plain and gzip compression before upload to OSS
  config :encoding, :validate => %w(none gzip), :default => "none"

  public
  def register
    # TODO: check if prefix is valid

    # check if temporary_directory is writable
    begin
      FileUtils.mkdir_p(@temporary_directory) unless Dir.exist?(@temporary_directory)
      ::File.writable?(@temporary_directory)
    rescue
      raise LogStash::ConfigurationError, "Logstash OSS Output Plugin can not write data to " + @temporary_directory
    end

    # check rotation configuration
    if @size_rotate.nil? and @time_rotate.nil? || @size_rotate <= 0 && @time_rotate <= 0
      raise LogStash::ConfigurationError, "Logstash OSS Output Plugin must have at least one of time_file or size_file set to a value greater than 0"
    end

    if @upload_workers_count <= 0 || @upload_queue_size <= 0
      raise LogStash::ConfigurationError,  "Logstash OSS Output Plugin must have both upload_workers_count and upload_queue_size are positive"
    end

    # create upload thread pool
    executor = Concurrent::ThreadPoolExecutor.new({ :min_threads => 1,
                                                    :max_threads => @upload_workers_count,
                                                    :max_queue => @upload_queue_size,
                                                    :fallback_policy => :caller_runs })

    # get file rotation strategy
    @rotation = rotation

    # initialize oss client
    @oss = initialize_oss_client

    # initialize file uploader
    @file_uploader = FileUploader.new(@oss, @bucket, @additional_oss_settings, @logger, executor)

    # initialize file manager
    @file_manager = FileManager.new(@logger, @encoding, @temporary_directory)

    # recover from crash
    recover_from_crash if @recover

    # start rotate check
    start_rotate_check if @rotation.needs_periodic_check?
  end # def register

  public
  def multi_receive_encoded(events_and_encoded)
    prefixes = Set.new
    events_and_encoded.each do |event, encoded|
      prefix = event.sprintf(@prefix)
      prefixes << prefix

      begin
        @file_manager.get_file_generator(prefix) { |generator| generator.current_file.write(encoded) }
      rescue Errno::ENOSPC => e
        @logger.error("Logstash OSS Output Plugin: No space left in temporary directory", :temporary_directory => @temporary_directory)
        raise e
      end
    end
    rotate(prefixes)
  end

  def close
    @logger.info("Logstash OSS Output Plugin is shutting down...")

    # stop rotate check
    stop_rotate_check if @rotation.needs_periodic_check?

    prefixes = @file_manager.prefixes
    prefixes.each do |prefix|
      @file_manager.get_file_generator(prefix) do |generator|
        file = generator.current_file
        file.close
        if file.size > 0
          # upload async
          @file_uploader.upload_async(file, :on_complete => method(:clean_temporary_file))
        end
      end
    end

    @file_manager.close

    # stop file uploader
    @file_uploader.close

    # stop oss client
    @oss.shutdown
  end

  private
  def initialize_oss_client
    clientConf = ClientBuilderConfiguration.new
    unless @additional_oss_settings.nil?
      if @additional_oss_settings.include?(SECURE_CONNECTION_ENABLED_KEY)
        clientConf.setProtocol(@additional_oss_settings[SECURE_CONNECTION_ENABLED_KEY] ?
          com.aliyun.oss.common.comm.Protocol::HTTPS : com.aliyun.oss.common.comm.Protocol::HTTP)
      end

      if @additional_oss_settings.include?(MAX_CONNECTIONS_TO_OSS_KEY)
        if @additional_oss_settings[MAX_CONNECTIONS_TO_OSS_KEY] <= 0
          raise LogStash::ConfigurationError, "Logstash OSS output plugin must have positive " + MAX_CONNECTIONS_TO_OSS_KEY
        end
        clientConf.setMaxConnections(@additional_oss_settings[MAX_CONNECTIONS_TO_OSS_KEY])
      else
        clientConf.setMaxConnections(1024)
      end
    end

    clientConf.setUserAgent(clientConf.getUserAgent() + ", Logstash-oss/" + Version.version)
    OSSClientBuilder.new().build(@endpoint, @access_key_id, @access_key_secret, clientConf)
  end

  private
  def rotation
    case @rotation_strategy
    when "size"
      SizeBasedRotation.new(size_rotate)
    when "time"
      TimeBasedRotation.new(time_rotate)
    when "size_and_time"
      HybridRotation.new(size_rotate, time_rotate)
    end
  end

  private
  def recover_from_crash
    @logger.info("Logstash OSS Output Plugin starts to recover from crash and uploading...")
    Dir.glob(::File.join(@temporary_directory, "**/*"))
      .select {|file| ::File.file?(file) }
      .each do |file|
        temporary_file = TemporaryFile.create_existing_file(file, @temporary_directory)
        if temporary_file.size > 0
          @file_uploader.upload_async(temporary_file, :on_complete => method(:clean_temporary_file))
        else
          clean_temporary_file(temporary_file)
        end
      end
  end

  private
  def rotate(prefixes)
    prefixes.each do |prefix|
      @file_manager.get_file_generator(prefix) do |file_generator|
        file = file_generator.current_file
        if @rotation.rotate?(file)
          @logger.info("Logstash OSS Output Plugin starts to rotate file",
                       :strategy => @rotation.class.name,
                       :key => file.key,
                       :path => file.path,
                       :size => file.size,
                       :thread => Thread.current.to_s)
          file.close
          if file.size > 0
            # upload async
            @file_uploader.upload_async(file, :on_complete => method(:clean_temporary_file))
          end
          file_generator.rotate
        end
      end
    end
  end

  private
  def clean_temporary_file(file)
    @logger.debug("Logstash OSS Output Plugin: starts to remove temporary file",
                 :file => file.path)
    file.delete!
  end

  private
  def start_rotate_check
    @rotate_check = Concurrent::TimerTask.new(:execution_interval => ROTATE_CHECK_INTERVAL_IN_SECONDS) do
      @logger.debug("Logstash OSS Output Plugin: starts rotation check")

      rotate(@file_manager.prefixes)
    end

    @rotate_check.execute
  end

  private
  def stop_rotate_check
    @rotate_check.shutdown
  end
end # class LogStash::Outputs::OSS