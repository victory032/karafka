# frozen_string_literal: true

# Karafka module namespace
module Karafka
  # Base consumer from which all Karafka consumers should inherit
  class BaseConsumer
    # @return [Karafka::Routing::Topic] topic to which a given consumer is subscribed
    attr_accessor :topic
    # @return [Karafka::Messages::Messages] current messages batch
    attr_accessor :messages
    # @return [Karafka::Connection::Client] kafka connection client
    attr_accessor :client
    # @return [Karafka::TimeTrackers::Pause] current topic partition pause tracker
    attr_accessor :pause_tracker
    # @return [Waterdrop::Producer] producer instance
    attr_accessor :producer

    # Executes the default consumer flow.
    #
    # @note We keep the seek offset tracking, and use it to compensate for async offset flushing
    #   that may not yet kick in when error occurs. That way we pause always on the last processed
    #   message.
    def on_consume
      Karafka.monitor.instrument('consumer.consumed', caller: self) do
        consume

        pause_tracker.reset

        # Mark as consumed only if manual offset management is not on
        return if topic.manual_offset_management

        # We use the non-blocking one here. If someone needs the blocking one, can implement it
        # with manual offset management
        mark_as_consumed(messages.last)
      end
    rescue StandardError => e
      Karafka.monitor.instrument(
        'error.occurred',
        error: e,
        caller: self,
        type: 'consumer.consume.error'
      )

      pause(@seek_offset || messages.first.offset)
    end

    # Trigger method for running on shutdown.
    #
    # @private
    def on_revoked
      Karafka.monitor.instrument('consumer.revoked', caller: self) do
        revoked
      end
    rescue StandardError => e
      Karafka.monitor.instrument(
        'error.occurred',
        error: e,
        caller: self,
        type: 'consumer.revoked.error'
      )
    end

    # Trigger method for running on shutdown.
    #
    # @private
    def on_shutdown
      Karafka.monitor.instrument('consumer.shutdown', caller: self) do
        shutdown
      end
    rescue StandardError => e
      Karafka.monitor.instrument(
        'error.occurred',
        error: e,
        caller: self,
        type: 'consumer.shutdown.error'
      )
    end

    # Can be used to run preparation code
    #
    # @private
    # @note This should not be used by the end users as it is part of the lifecycle of things but
    #   not as part of the public api. This can act as a hook when creating non-blocking
    #   consumers and doing other advanced stuff
    def on_prepared
      Karafka.monitor.instrument('consumer.prepared', caller: self) do
        prepared
      end
    rescue StandardError => e
      Karafka.monitor.instrument(
        'error.occurred',
        error: e,
        caller: self,
        type: 'consumer.prepared.error'
      )
    end

    private

    # Method that gets called in the blocking flow allowing to setup any type of resources or to
    # send additional commands to Kafka before the proper execution starts.
    def prepared; end

    # Method that will perform business logic and on data received from Kafka (it will consume
    #   the data)
    # @note This method needs bo be implemented in a subclass. We stub it here as a failover if
    #   someone forgets about it or makes on with typo
    def consume
      raise NotImplementedError, 'Implement this in a subclass'
    end

    # Method that will be executed when a given topic partition is revoked. You can use it for
    # some teardown procedures (closing file handler, etc).
    def revoked; end

    # Method that will be executed when the process is shutting down. You can use it for
    # some teardown procedures (closing file handler, etc).
    def shutdown; end

    # Marks message as consumed in an async way.
    #
    # @param message [Messages::Message] last successfully processed message.
    # @note We keep track of this offset in case we would mark as consumed and got error when
    #   processing another message. In case like this we do not pause on the message we've already
    #   processed but rather at the next one. This applies to both sync and async versions of this
    #   method.
    def mark_as_consumed(message)
      client.mark_as_consumed(message)
      @seek_offset = message.offset + 1
    end

    # Marks message as consumed in a sync way.
    #
    # @param message [Messages::Message] last successfully processed message.
    def mark_as_consumed!(message)
      client.mark_as_consumed!(message)
      @seek_offset = message.offset + 1
    end

    # Pauses processing on a given offset for the current topic partition
    #
    # After given partition is resumed, it will continue processing from the given offset
    # @param offset [Integer] offset from which we want to restart the processing
    # @param timeout [Integer, nil] how long in milliseconds do we want to pause or nil to use the
    #   default exponential pausing strategy defined for retries
    def pause(offset, timeout = nil)
      client.pause(
        messages.metadata.topic,
        messages.metadata.partition,
        offset
      )

      timeout ? pause_tracker.pause(timeout) : pause_tracker.pause
    end

    # Resumes processing of the current topic partition
    def resume
      client.resume(
        messages.metadata.topic,
        messages.metadata.partition
      )

      pause_tracker.expire
    end

    # Seeks in the context of current topic and partition
    #
    # @param offset [Integer] offset where we want to seek
    def seek(offset)
      client.seek(
        Karafka::Messages::Seek.new(
          messages.metadata.topic,
          messages.metadata.partition,
          offset
        )
      )
    end
  end
end
