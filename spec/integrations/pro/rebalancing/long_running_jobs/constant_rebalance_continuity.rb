# frozen_string_literal: true

# When we consume data and several times we loose and regain partition, there should be
# continuity in what messages we pick up even if rebalances happens multiple times. This should
# apply to using LRJ as well.
#
# We may re-fetch certain messages but none should be skipped

setup_karafka do |config|
  config.concurrency = 1
  config.license.token = pro_license_token
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    sleep 5

    messages.each do |message|
      DataCollector[:messages] << message

      return unless mark_as_consumed!(message)
    end
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
      long_running_job true
    end
  end
end

MESSAGES = Array.new(1_000) { SecureRandom.uuid }

# We need a second producer to trigger the rebalances
Thread.new do
  sleep(10)

  10.times do
    consumer = setup_rdkafka_consumer
    consumer.subscribe(DataCollector.topic)
    sleep(2)
    consumer.close
    sleep(1)
  end

  DataCollector[:rebalanced] << true
end

i = 0

start_karafka_and_wait_until do
  10.times do
    produce(DataCollector.topic, MESSAGES[i])
    i += 1
  end

  sleep(1)

  DataCollector[:rebalanced].size >= 1
end

previous = nil

# They need to be in order one batch after another
DataCollector[:messages].map(&:offset).uniq.each do |offset|
  unless previous
    previous = offset
    next
  end

  assert_equal previous + 1, offset

  previous = offset
end
