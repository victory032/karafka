# frozen_string_literal: true

# We should be able to prolong a manual pause that we did pause already and the times should add up

setup_karafka do |config|
  config.max_messages = 5
  config.pause_timeout = 2_000
  config.pause_max_timeout = 2_000
  config.pause_with_exponential_backoff = false
end

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector[:times] << Time.now.to_f

    pause(messages.last.offset + 1)

    sleep(1)

    pause(messages.last.offset + 1)
  end
end

draw_routes(Consumer)

20.times { |i| produce(DataCollector.topic, i.to_s) }

start_karafka_and_wait_until do
  DataCollector[:times].size >= 4
end

# If second pausing would not work, it would be less than 3
time1 = DataCollector[:times][1] - DataCollector[:times][0]
time2 = DataCollector[:times][3] - DataCollector[:times][2]

assert time1 >= 3, "#{time1} expected to be equal or more than 3 seconds"
assert time2 >= 3, "#{time2} expected to be equal or more than 3 seconds"
