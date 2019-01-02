# encoding: utf-8

require 'rspec'
require_relative 'common'

describe 'recover integration tests', :integration => true do

  include_context 'plugin initialize'

  let(:configurations) { common_configurations.merge({}) }

  before do
    clean_bucket
  end

  it 'recover files from temporary directory' do
    generate_files(3)
    expect(oss.listObjects(bucket, prefix).getObjectSummaries().size).to eq(3)
  end

  it 'recover files from empty temporary directory' do
    generate_files(0)
    expect(oss.listObjects(bucket, prefix).getObjectSummaries().size).to eq(0)
  end

  after do
    clean_bucket
  end

  def generate_files(number_of_files)
    # generate files in temporary directory
    generator = LogStash::Outputs::OSS::FileGenerator.new(prefix, "gzip", temporary_directory)
    number_of_files.times do
      generator.current_file.write("Hello, world")
      generator.current_file.close
      generator.rotate
    end

    subject.register

    subject.close
  end
end