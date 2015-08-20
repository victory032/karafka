module Karafka
  # App class
  class App
    class << self
      attr_writer :logger

      # Method which runs app
      def run
        logger.info('Starting Karafka framework')
        logger.info("Kafka hosts: #{config.kafka_hosts}")
        logger.info("Zookeeper hosts: #{config.zookeeper_hosts}")
        Karafka::Runner.new.run
      end

      # @return [Logger] logger that we want to use
      def logger
        @logger ||= ::Karafka::Logger.build
      end

      # @return [Karafka::Config] config instance
      def config
        Config.config
      end

      # Sets up the whole configuration
      # @param [Block] block configuration block
      def setup(&block)
        Config.setup(&block)

        after_setup
      end

      # Methods that should be delegated to Karafka module
      %i(
        root env
      ).each do |delegated|
        define_method(delegated) do
          Karafka.public_send(delegated)
        end
      end

      private

      # Everything that should be initialized after the setup
      def after_setup
        Karafka::Worker.timeout = config.worker_timeout
      end
    end
  end
end
