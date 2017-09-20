# frozen_string_literal: true

RSpec.describe Karafka::Setup::Configurators::Celluloid do
  subject(:celluloid_configurator) { described_class.new(config) }

  let(:config) { double }

  specify { expect(described_class).to be < Karafka::Setup::Configurators::Base }

  describe '#setup' do
    let(:shutdown_timeout) { ::Karafka::App.config.celluloid.shutdown_timeout }

    it 'expect to assign Karafka logger to Celluloid and set a shutdown_timeout' do
      expect(Celluloid).to receive(:logger=).with(Karafka.logger)
      expect(Celluloid).to receive(:shutdown_timeout=).with(shutdown_timeout)

      celluloid_configurator.setup
    end
  end
end
