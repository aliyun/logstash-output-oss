# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/oss"
require "logstash/codecs/plain"
require "logstash/event"

describe LogStash::Outputs::OSS do
  let(:options) {
    {
        "endpoint" => "oss-cn-zhangjiakou.aliyuncs.com",
        "bucket" => "bucket",
        "prefix" => "logstash/%{index}",
        "recover" => true,
        "access_key_id" => "access_key_id",
        "access_key_secret" => "access_key_secret",
        "encoding" => "none"
    }
  }

  describe 'invalid configurations' do
    it 'validate rotate' do
      oss = described_class.new(options.merge({ "size_rotate" => -1, "time_rotate" => -1 }))
      expect { oss.register }.to raise_error(LogStash::ConfigurationError)

      oss = described_class.new(options.merge({ "size_rotate" => -1 }))
      expect { oss.register }.to raise_error(LogStash::ConfigurationError)

      oss = described_class.new(options.merge({ "time_rotate" => -1 }))
      expect { oss.register }.to raise_error(LogStash::ConfigurationError)
    end


    it 'validate upload configurations' do
      oss = described_class.new(options.merge({ "upload_workers_count" => -1, "upload_queue_size" => -1 }))
      expect { oss.register }.to raise_error(LogStash::ConfigurationError)

      oss = described_class.new(options.merge({ "upload_workers_count" => -1 }))
      expect { oss.register }.to raise_error(LogStash::ConfigurationError)

      oss = described_class.new(options.merge({ "upload_queue_size" => -1 }))
      expect { oss.register }.to raise_error(LogStash::ConfigurationError)
    end

    it 'validate invalid temporary directory' do
      dir = 'a_' + Time.now.to_i.to_s
      file_name = dir + '/1.gz'
      system('mkdir -p ' + dir + ' && touch ' + file_name)
      oss = described_class.new(options.merge({ "temporary_directory" => file_name }))
      expect { oss.register }.to raise_error(LogStash::ConfigurationError)
      system('rm -rf ' + dir)
    end

    it 'validate invalid additional oss configurations' do
      oss = described_class.new(options.merge({ "additional_oss_settings" => { "max_connections_to_oss" => -1} }))
      expect { oss.register }.to raise_error(LogStash::ConfigurationError)
    end
  end
end