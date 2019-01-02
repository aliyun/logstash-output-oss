# encoding: utf-8

require 'rspec'
require_relative 'common'

describe 'encoding integration tests', :integration => true do
  include_context 'plugin initialize'

  let(:number_of_events) { 500 }
  let(:batch_size) { 125 }
  let(:event_encoded) { "Hello world\n" }
  let(:batch) do
    b = {}
    number_of_events.times do
      event = LogStash::Event.new({ "message" => event_encoded, "host" => "localhost", "index" => 1 })
      b[event] = "#{event_encoded}"
    end
    b
  end

  before do
    subject.register

    batch.each_slice(batch_size) do |smaller_batch|
      subject.multi_receive_encoded(smaller_batch)
      sleep(1)
    end

    subject.close
  end

  after do
    clean_bucket
  end

  ################### gzip encoding integration test ###################
  describe 'gzip encoding integration tests' do
    let(:configurations) {
      common_configurations.merge(
        {
          "encoding" => "gzip",
          "rotation_strategy" => "time",
          "time_rotate" => 0.01 # 0.01 * 60 = 0.6s
        }
      )
    }

    it 'compare file content(uncompressed) with original events' do
      # read lines from oss bucket
      copy_file_to_temporary_dir(temporary_directory)

      expect(Dir.glob(File.join(temporary_directory, prefix, "*.gz")).inject(0) { |sum, f| sum + Zlib::GzipReader.new(File.open(f)).readlines.size }).to eq(number_of_events)
    end

    it 'creates multiples files' do
      expect(oss.listObjects(bucket, prefix).getObjectSummaries().size).to be_between(3, 4)
    end
  end

  ################### plain encoding integration test ###################
  describe 'plain encoding integration test' do
    let(:configurations) {
      common_configurations.merge(
        {
          "encoding" => "none",
          "rotation_strategy" => "time",
          "time_rotate" => 0.01 # 0.01 * 60 = 0.6s
        }
      )
    }

    it 'compare file content with original events' do
      # read lines from oss bucket
      copy_file_to_temporary_dir(temporary_directory)

      expect(Dir.glob(File.join(temporary_directory, prefix, "*.data")).inject(0) { |sum, f| sum + File.open(f).readlines.size }).to eq(number_of_events)
    end

    it 'creates multiples files' do
      expect(oss.listObjects(bucket, prefix).getObjectSummaries().size).to be_between(3, 4)
    end
  end

  def copy_file_to_temporary_dir(temporary_directory)
    FileUtils.rm_rf(temporary_directory)
    FileUtils.mkdir_p(File.join(temporary_directory, prefix))
    oss.listObjects(bucket, prefix).getObjectSummaries().each do |objectSummary|
      request = GetObjectRequest.new(bucket, objectSummary.getKey())
      oss.getObject(request, java.io.File.new(File.join(temporary_directory, objectSummary.getKey())))
    end
  end
end