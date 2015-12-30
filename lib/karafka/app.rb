module Karafka
  # App class
  class App
    class << self
      # Method which runs app
      def run
        bind_on_sigint
        bind_on_sigquit
        start_supervised
      end

      # Sets up the whole configuration
      # @param [Block] block configuration block
      def setup(&block)
        Config.setup(&block)
        # Once everything is configured we can bootstrap the whole framework
        bootstrap
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

      # This method is used to load all dynamically created/generated parts of Karafka framework
      # It needs to be executed before we run the application
      # @note This method is private because we bootstrap everything after configuration
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

      # @return [Karafka::Process] process wrapper instance used to catch system signal calls
      def process
        Karafka::Process.instance
      end

      # What should happen when we decide to quit with sigint
      def bind_on_sigint
        process.on_sigint do
          stop!
          exit
        end
      end

      # What should happen when we decide to quit with sigquit
      def bind_on_sigquit
        process.on_sigquit do
          stop!
          exit
        end
      end

      # Starts Karafka with a supervision
      def start_supervised
        process.supervise do
          Karafka::Runner.new.run
          run!
          sleep
        end
      end
    end
  end
end
