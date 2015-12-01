module Karafka
  # App class
  class App
    class << self
      # This method is used to load all dynamically created/generated parts of Karafka framework
      # It needs to be executed before we run the application
      # @note If you have standard app.rb file in your application, you don't need to care about
      #   this method at all (it is already invoked there)
      def bootstrap
        initialize!
        # This is tricky part to explain ;) but we will try
        # Each Karafka controller can have its own worker that will process in background
        # (or not if you really, really wish to). If you define them explicitly on a
        # controller level, they will be built automatically on first usage (lazy loaded)
        # Unfortunatelly Sidekiq (and other background processing engines) need to have workers
        # loaded, because when they do something like const_get(worker_name), they will get nil
        # instead of proper worker class
        Karafka::Routing::Mapper.controllers
        Karafka::Routing::Mapper.workers
      end

      # Method which runs app
      def run
        process.on_sigint(&method(:on_shutdown))
        process.on_sigquit(&method(:on_shutdown))
        process.supervise(&method(:on_supervised_run))
      end

      # Sets up the whole configuration
      # @param [Block] block configuration block
      def setup(&block)
        Config.setup(&block)

        after_setup
      end

      # @return [Karafka::Config] config instance
      def config
        Config.config
      end

      Status.instance_methods(false).each do |delegated|
        define_method(delegated) do
          Status.instance.public_send(delegated)
        end
      end

      # Methods that should be delegated to Karafka module
      %i(
        root env logger monitor
      ).each do |delegated|
        define_method(delegated) do
          Karafka.public_send(delegated)
        end
      end

      private

      # @return [Karafka::Process] process wrapper instance used to catch system signal calls
      def process
        Karafka::Process.instance
      end

      # What code should be executed in supervised run (what should be supervised)
      def on_supervised_run
        Karafka::Runner.new.run
        run!
        sleep
      end

      # That should happen when we decide to close Karafka instance
      def on_shutdown
        stop!
        exit
      end

      # Everything that should be initialized after the setup
      def after_setup
        Celluloid.logger = Karafka.logger
        configure_sidekiq_client
        configure_sidekiq_server
      end

      # Configure sidekiq client
      def configure_sidekiq_client
        Sidekiq.configure_client do |sidekiq_config|
          sidekiq_config.redis = config.redis.merge(
            size: config.concurrency
          )
        end
      end

      # Configure sidekiq setorrver
      def configure_sidekiq_server
        Sidekiq.configure_server do |sidekiq_config|
          # We don't set size for the server - this will be set automatically based
          # on the Sidekiq concurrency level (Sidekiq not Karafkas)
          sidekiq_config.redis = config.redis
        end
      end
    end
  end
end
