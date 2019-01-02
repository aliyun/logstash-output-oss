# encoding: utf-8

require 'rspec'
require 'logstash/devutils/rspec/spec_helper'
require 'logstash/logging/logger'
require 'logstash/outputs/oss'

describe 'rotation unit tests' do

  let (:temporary_directory) { Stud::Temporary.pathname }
  let (:prefix) { "logstash" }
  let (:encoding) { "none" }
  let(:event) { "Hello world\n" }

  it 'size based rotation unit tests' do
    size_based_rotation = LogStash::Outputs::OSS::SizeBasedRotation.new(1024)
    expect(size_based_rotation.needs_periodic_check?).to be(false)

    generator = LogStash::Outputs::OSS::FileGenerator.new(prefix, encoding, temporary_directory)

    generator.current_file.write(event)
    expect(size_based_rotation.rotate?(generator.current_file)).to be(false)

    1024.times do
      generator.current_file.write(event)
    end

    expect(size_based_rotation.rotate?(generator.current_file)).to be(true)

    generator.current_file.write(event)

    expect(size_based_rotation.rotate?(generator.current_file)).to be(true)
  end

  it 'time based rotation unit tests' do
    time_based_rotation = LogStash::Outputs::OSS::TimeBasedRotation.new(0.05)
    expect(time_based_rotation.needs_periodic_check?).to be(true)

    generator = LogStash::Outputs::OSS::FileGenerator.new(prefix, encoding, temporary_directory)

    generator.current_file.write(event)
    expect(time_based_rotation.rotate?(generator.current_file)).to be(false)

    sleep(1)

    expect(time_based_rotation.rotate?(generator.current_file)).to be(false)

    sleep(2)

    expect(time_based_rotation.rotate?(generator.current_file)).to be(true)
  end

  it 'hybrid rotation unit tests' do
    hybrid_rotation = LogStash::Outputs::OSS::HybridRotation.new(1024, 0.05)
    expect(hybrid_rotation.needs_periodic_check?).to be(true)

    generator = LogStash::Outputs::OSS::FileGenerator.new(prefix, encoding, temporary_directory)

    generator.current_file.write(event)

    expect(hybrid_rotation.rotate?(generator.current_file)).to be(false)

    1024.times do
      generator.current_file.write(event)
    end

    expect(hybrid_rotation.rotate?(generator.current_file)).to be(true)
  end
end