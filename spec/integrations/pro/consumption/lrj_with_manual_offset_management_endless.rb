# frozen_string_literal: true

# When using manual offset management and not marking any messages we should end up in an
# endless loop with same first message.
# Does not make much sense but we test this scenario anyhow

setup_karafka do |config|
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.license.token = pro_license_token
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    DataCollector[0] << messages.first.raw_payload
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
      long_running_job true
      manual_offset_management true
    end
  end
end

payloads = Array.new(20) { SecureRandom.uuid }

payloads.each { |payload| produce(DataCollector.topic, payload) }

start_karafka_and_wait_until do
  DataCollector[0].size >= 20
end

# We should get only the first message from which we started
assert_equal 1, DataCollector[0].uniq.size
assert_equal payloads[0], DataCollector[0].uniq.last

# Now when w pick up the work again, it should start from the first message
consumer = setup_rdkafka_consumer

consumer.subscribe(DataCollector.topic)

consumer.each do |message|
  DataCollector[1] << message.payload

  break
end

assert_equal payloads[0], DataCollector[1].first

consumer.close
