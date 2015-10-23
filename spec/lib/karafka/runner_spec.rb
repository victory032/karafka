require 'spec_helper'

RSpec.describe Karafka::Runner do
  subject { described_class.new }

  describe '#run' do
    context 'when everything is ok' do
      let(:cluster) { Karafka::Connection::ActorCluster.new([]) }
      let(:clusters) { [cluster] }
      let(:consumer) { -> {} }
      let(:async_scope) { cluster }

      before do
        expect(subject)
          .to receive(:clusters)
          .and_return(clusters)

        expect(subject)
          .to receive(:consumer)
          .and_return(consumer)
      end

      it 'should start asynchronously fetch loop for each cluster' do
        expect(cluster)
          .to receive(:async)
          .and_return(async_scope)

        expect(async_scope)
          .to receive(:fetch_loop)
          .with(consumer)

        subject.run
      end
    end

    context 'when something goes wrong internaly' do
      let(:exception) { StandardError }

      before do
        expect(subject)
          .to receive(:clusters)
          .and_raise(exception)
      end

      it 'should stop the app and reraise' do
        expect(Karafka::App)
          .to receive(:stop!)

        expect(Karafka.logger)
          .to receive(:fatal)

        expect { subject.run }.to raise_error(exception)
      end
    end
  end

  describe '#clusters' do
    let(:controller) { double }
    let(:controllers) { [controller] }

    before do
      expect(Karafka::Routing::Mapper)
        .to receive(:controllers)
        .and_return(controllers)

      expect(subject)
        .to receive(:slice_size)
        .and_return(rand(1000) + 1)

      expect(Karafka::Connection::ActorCluster)
        .to receive(:new)
        .with(controllers)
    end

    it { expect(subject.send(:clusters)).to be_a Array }
  end

  describe '#consumer' do
    let(:subject) { described_class.new.send(:consumer) }

    it 'should be a proc' do
      expect(subject).to be_a Proc
    end

    context 'when we invoke a consumer block' do
      let(:message) { double }
      let(:controller) { double }

      it 'should consume the message' do
        expect_any_instance_of(Karafka::Connection::Consumer)
          .to receive(:consume)
          .with(controller, message)

        subject.call(controller, message)
      end
    end
  end

  describe '#slice_size' do
    subject { described_class.new.send(:slice_size) }

    let(:config) { double }

    before do
      expect(Karafka::Routing::Mapper)
        .to receive(:controllers)
        .and_return(Array.new(controllers_length))

      expect(Karafka::App)
        .to receive(:config)
        .and_return(config)

      expect(config)
        .to receive(:concurrency)
        .and_return(concurrency)
    end

    context 'when there are no controllers' do
      let(:controllers_length) { 0 }
      let(:concurrency) { 100 }

      it { expect(subject).to eq 1 }
    end

    context 'when we have less controllers than concurrency level' do
      let(:controllers_length) { 1 }
      let(:concurrency) { 20 }

      it { expect(subject).to eq 1 }
    end

    context 'when we have more controllers than concurrency level' do
      let(:controllers_length) { 110 }
      let(:concurrency) { 20 }

      it { expect(subject).to eq 5 }
    end

    context 'when we have the same amount of controllers and concurrency level' do
      let(:controllers_length) { 20 }
      let(:concurrency) { 20 }

      it { expect(subject).to eq 1 }
    end
  end
end
