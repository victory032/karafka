# frozen_string_literal: true

# When dead letter queue is used and we first message out of all is broken, things should behave
# like for any other broken message

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.license.token = pro_license_token
end

create_topic(name: DT.topics[0])
create_topic(name: DT.topics[1])

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.offset.zero?

      DT[:offsets] << message.offset

      mark_as_consumed message
    end
  end
end

class DlqConsumer < Karafka::Pro::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << [message.offset, message.raw_payload]
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 2)
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

Karafka.monitor.subscribe('error.occurred') do |event|
  next unless event[:type] == 'consumer.consume.error'

  DT[:errors] << 1
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:offsets].uniq.count >= 99 &&
    DT[:broken].size >= 1
end

# first error and two errors on retries prior to moving on
assert_equal 3, DT[:errors].count

# we should not have the message that was failing
assert_equal (0..99).to_a - [0], DT[:offsets]

assert_equal 1, DT[:broken].size
# This message will get new offset (first)
assert_equal DT[:broken][0][0], 0
assert_equal DT[:broken][0][1], elements[0]
