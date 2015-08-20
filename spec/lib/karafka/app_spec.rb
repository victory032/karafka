require 'spec_helper'

RSpec.describe Karafka::App do
  subject { described_class }

  describe '#run' do
    it 'should start consuming' do
      expect_any_instance_of(Karafka::Runner)
        .to receive(:run)

      subject.run
    end
  end

  describe '#config' do
    let(:config) { double }

    it 'should alias to Config' do
      expect(Karafka::Config)
        .to receive(:config)
        .and_return(config)

      expect(subject.config).to eq config
    end
  end

  describe '#setup' do
    it 'should delegate it to Config setup and execute after_setup' do
      expect(Karafka::Config)
        .to receive(:setup)
        .once

      expect(subject)
        .to receive(:after_setup)

      subject.setup
    end
  end

  describe '#after_setup' do
    let(:worker_timeout) { rand }
    let(:config) { double(worker_timeout: worker_timeout) }

    it 'should setup a workers timeout' do
      expect(Karafka::Worker)
        .to receive(:timeout=)
        .with(worker_timeout)

      expect(subject)
        .to receive(:config)
        .and_return(config)

      subject.send(:after_setup)
    end
  end

  describe '#root' do
    let(:root) { double }

    it 'should use Karafka.root' do
      expect(Karafka)
        .to receive(:root)
        .and_return(root)

      expect(subject.root).to eq root
    end
  end
end
