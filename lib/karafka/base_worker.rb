require 'karafka'

Karafka::Loader.new.load!("#{Karafka.root}/app/controllers")

module Karafka
  # Worker wrapper for Sidekiq workers
  class BaseWorker < SidekiqGlass::Worker
    self.timeout = 300

    # @param params [Array] controller params and controller topic
    def execute(*params)
      event = Karafka::Connection::Event.new(params.last.to_sym, params.first)
      controller = Karafka::Routing::Router.new(event).descendant_controller

      controller.perform
    end

    # @param _params [Array] controller params and controller topic
    def after_failure(*_params)
    end
  end
end
