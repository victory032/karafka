module Karafka
  # Params namespace encapsulating all the logic that is directly related to params handling
  module Params
    # Class-wrapper for hash with indifferent access with additional lazy loading feature
    # It provides lazy loading not only until the first usage, but also allows us to skip
    # using parser until we execute our logic inside worker. That way we can operate with
    # heavy-parsing data without slowing down the whole application. If we won't use
    # params in before_enqueue (or if we don't us before_enqueue at all), it will make
    # Karafka faster, because it will pass data as it is directly to Sidekiq
    class Params < HashWithIndifferentAccess
      class << self
        # We allow building instances only via the #build method
        private_class_method :new

        # @param message [Karafka::Connection::Message, Hash] message that we get out of Kafka
        #   in case of building params inside main Karafka process in
        #   Karafka::Connection::Consumer, or a hash when we retrieve data from Sidekiq
        # @param controller [Karafka::BaseController] Karafka's base controllers descendant
        #   instance that wants to use params
        # @return [Karafka::Params::Params] Karafka params object not yet used parser for
        #   retrieving data that we've got from Kafka
        # @example Build params instance from a hash
        #   Karafka::Params::Params.build({ key: 'value' }, DataController.new) #=> params object
        # @example Build params instance from a Karafka::Connection::Message object
        #   Karafka::Params::Params.build(message, IncomingController.new) #=> params object
        def build(message, controller)
          # Hash case happens inside workers
          if message.is_a?(Hash)
            defaults(controller).merge!(message)
          else
            # This happens inside Karafka::Connection::Consumer
            defaults(controller).merge!(
              parsed: false,
              received_at: Time.now,
              content: message.content
            )
          end
        end

        private

        # @param controller [Karafka::BaseController] Karafka's base controllers descendant
        #   instance that wants to use params
        # @return [Karafka::Params::Params] freshly initialized only with default values object
        #   that can be populated with incoming data
        def defaults(controller)
          # We initialize some default values that will be used both in Karafka main process and
          # inside workers
          new(
            controller: controller.class,
            worker: controller.worker,
            parser: controller.parser,
            topic: controller.topic,
            responder: controller.responder
          )
        end
      end

      # @return [Karafka::Params::Params] this will trigger parser execution. If we decide to
      #   retrieve data, parser will be executed to parse data. Output of parsing will be merged
      #   to the current object. This object will be also marked as already parsed, so we won't
      #   parse it again.
      def retrieve
        return self if self[:parsed]

        merge!(parse(delete(:content)))
      end

      # Overwritten merge! method - it behaves differently for keys that are the same in our hash
      #  and in a other_hash - it will not replace keys that are the same in our hash
      #  and in the other one
      # @param other_hash [Hash, HashWithIndifferentAccess] hash that we want to merge into current
      # @return [Karafka::Params::Params] our parameters hash with merged values
      # @example Merge with hash without same keys
      #   new(a: 1, b: 2).merge!(c: 3) #=> { a: 1, b: 2, c: 3 }
      # @example Merge with hash with same keys (symbol based)
      #   new(a: 1).merge!(a: 2) #=> { a: 1 }
      # @example Merge with hash with same keys (string based)
      #   new(a: 1).merge!('a' => 2) #=> { a: 1 }
      # @example Merge with hash with same keys (current string based)
      #   new('a' => 1).merge!(a: 2) #=> { a: 1 }
      def merge!(other_hash)
        super(other_hash) { |_key, base_value, _new_value| base_value }
      end

      private

      # @param content [String] Raw data that we want to parse using controller's parser
      # @note If something goes wrong, it will return raw data in a hash with a message key
      # @return [Hash] parsed data or a hash with message key containing raw data if something
      #   went wrong during parsing
      def parse(content)
        self[:parser].parse(content)
        # We catch both of them, because for default JSON - we use JSON parser directly
      rescue ::Karafka::Errors::ParserError, JSON::ParserError => e
        Karafka.monitor.notice_error(self.class, e)
        return { message: content }
      ensure
        self[:parsed] = true
      end
    end
  end
end
