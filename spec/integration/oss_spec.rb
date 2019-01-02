# encoding: utf-8

require 'rspec'
require_relative 'common'

describe 'integration tests', :integration => true do

  include_context 'plugin initialize'

  let(:number_of_events) { 400000 }
  let(:batch_size) { 400 }
  let(:event_encoded) { "Hello world\n" }
  let(:batch) do
    b = {}
    number_of_events.times do
      event = LogStash::Event.new({ "message" => event_encoded, "host" => "localhost", "index" => Random.rand(3) })
      b[event] = "#{event_encoded}"
    end
    b
  end

  let(:configurations) {
    common_configurations.merge(
      {
        "prefix" => "logstash/%{index}",
        "size_rotate" => 13631488, # 13MB
        "time_rotate" => 0.15 # 0.15 * 60 = 9s
      }
    )
  }

  before do
    subject.register
  end

  after do
    subject.close

    clean_bucket
  end

  it 'integration stress tests' do
    100.times do
      batch.each_slice(batch_size) { |smaller_batch| subject.multi_receive_encoded(smaller_batch) }
    end
  end
end