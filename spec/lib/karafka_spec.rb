require 'spec_helper'

RSpec.describe Karafka do
  subject { described_class }

  describe '.gem_root' do
    context 'when we want to get gem root path' do
      let(:path) { Dir.pwd }
      it { expect(subject.gem_root.to_path).to eq path }
    end
  end

  describe '.root' do
    context 'when we want to get app root path' do
      before do
        expect(ENV).to receive(:[]).with('BUNDLE_GEMFILE').and_return('/')
      end

      it { expect(subject.root.to_path).to eq '/' }
    end
  end

  describe '#logger' do
    let(:logger) { double }
    let(:log) { double }
    let(:set_logger) { double }

    it 'returns NULL logger' do
      allow(Karafka.instance_variable_get(:@logger)) { nil }
      expect(Karafka.logger).to eq(Karafka::NullLogger)
    end

    it 'returns set logger' do
      allow(Karafka.instance_variable_get(:@logger)) { set_logger }
      expect(Karafka).to receive(:logger).and_return(set_logger)
      Karafka.logger
    end
  end
end
