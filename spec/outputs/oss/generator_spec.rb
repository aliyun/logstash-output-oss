# encoding: utf-8

require 'rspec'
require "logstash/devutils/rspec/spec_helper"
require 'logstash/outputs/oss'
require 'logstash/logging/logger'

describe 'file generator unit tests' do

  let (:temporary_directory) { Stud::Temporary.pathname }
  let (:prefix) { "logstash" }

  describe 'gzip encoding generator' do

    it 'gzip' do
      generator = LogStash::Outputs::OSS::FileGenerator.new(prefix, "gzip", temporary_directory)

      # part-0, ends with part-0.gz
      elements = generator.current_file.path.to_s.split(::File::SEPARATOR)
      file_name = elements.at(elements.size - 1)
      expect(file_name.match(/ls.oss.*.part-0.gz/).to_s).to eq(file_name)

      generator.rotate

      # part-1, ends with part-1.gz
      generator.current_file
      elements = generator.current_file.path.to_s.split(::File::SEPARATOR)
      file_name = elements.at(elements.size - 1)
      expect(file_name.match(/ls.oss.*.part-1.gz/).to_s).to eq(file_name)

      generator.rotate

      # part-2, ends with part-2.gz
      generator.current_file
      elements = generator.current_file.path.to_s.split(::File::SEPARATOR)
      file_name = elements.at(elements.size - 1)
      expect(file_name.match(/ls.oss.*.part-2.gz/).to_s).to eq(file_name)
    end
  end

  describe 'plain encoding generator' do

    it 'plain' do
      generator = LogStash::Outputs::OSS::FileGenerator.new(prefix, "none", temporary_directory)
      # part-0, ends with part-0.data
      elements = generator.current_file.path.to_s.split(::File::SEPARATOR)
      file_name = elements.at(elements.size - 1)
      expect(file_name.match(/ls.oss.*.part-0.data/).to_s).to eq(file_name)

      generator.rotate

      # part-1, ends with part-1.data
      generator.current_file
      elements = generator.current_file.path.to_s.split(::File::SEPARATOR)
      file_name = elements.at(elements.size - 1)
      expect(file_name.match(/ls.oss.*.part-1.data/).to_s).to eq(file_name)

      generator.rotate

      # part-2, ends with part-2.data
      generator.current_file
      elements = generator.current_file.path.to_s.split(::File::SEPARATOR)
      file_name = elements.at(elements.size - 1)
      expect(file_name.match(/ls.oss.*.part-2.data/).to_s).to eq(file_name)
    end
  end
end