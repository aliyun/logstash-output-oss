# encoding: utf-8

require 'logstash/devutils/rspec/spec_helper'
require 'logstash/logging/logger'
require 'logstash/outputs/oss'
require 'stud/temporary'
java_import 'com.aliyun.oss.model.GetObjectRequest'

# This file contains the common logic used by integration tests
shared_context "plugin initialize" do
  let(:endpoint) { ENV['OSS_ENDPOINT'] }
  let(:bucket) { ENV['OSS_BUCKET'] }
  let(:access_key_id) { ENV['OSS_ACCESS_KEY'] }
  let(:access_key_secret) { ENV['OSS_SECRET_KEY'] }
  let(:prefix) { "logstash" }
  let(:temporary_directory) { Stud::Temporary.pathname }

  let(:common_configurations) do
    {
      "endpoint" => endpoint,
      "bucket" => bucket,
      "access_key_id" => access_key_id,
      "access_key_secret" => access_key_secret,
      "prefix" => prefix,
      "size_rotate" => 1024,
      "time_rotate" => 60,
      "temporary_directory" => temporary_directory,
    }
  end

  LogStash::Logging::Logger::configure_logging("debug") if ENV["DEBUG"]

  let(:oss) { OSSClientBuilder.new().build(endpoint, access_key_id, access_key_secret) }
  subject { LogStash::Outputs::OSS.new(configurations) }
end

# remove object with `prefix`
def clean_bucket
  oss.listObjects(bucket, prefix).getObjectSummaries().each do |objectSummary|
    oss.deleteObject(bucket, objectSummary.getKey())
  end
end