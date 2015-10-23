require 'spec_helper'

RSpec.describe Karafka::Connection::QueueConsumer do
  let(:group) { rand.to_s }
  let(:topic) { rand.to_s }
  let(:controller) do
    double(
      group: group,
      topic: topic
    )
  end
  let(:max_wait_ms) { described_class::MAX_WAIT_MS }
  let(:socket_timeout_ms) { described_class::SOCKET_TIMEOUT_MS }
  connection_clear_errors = [
    Poseidon::Connection::ConnectionFailedError,
    Poseidon::Errors::ProtocolError,
    Poseidon::Errors::UnableToFetchMetadata,
    ZK::Exceptions::KeeperException,
    Zookeeper::Exceptions::ZookeeperException
  ]

  subject { described_class.new(controller) }

  describe 'preconditions' do
    it 'should have socket timeout bigger then wait timeout' do
      expect(max_wait_ms < socket_timeout_ms).to be true
    end
  end

  describe '.new' do
    it 'should just remember controller' do
      expect(subject.instance_variable_get(:@controller)).to eq controller
    end
  end

  describe '#fetch' do
    let(:target) { double }
    let(:options) { rand }
    let(:partition) { rand }
    let(:message_bulk) { double }

    context 'when everything is ok' do
      before do
        expect(subject)
          .to receive(:target)
          .and_return(target)

        expect(target)
          .to receive(:fetch)
          .with(options)
          .and_yield(partition, message_bulk)
          .and_return(true)

        expect(subject)
          .not_to receive(:close)

        expect(subject)
          .not_to receive(:sleep)
      end

      it 'should forward to target and fetch' do
        fetch = lambda do
          subject.fetch(options) do |rec_partition, rec_message_bulk|
            expect(rec_partition).to eq partition
            expect(rec_message_bulk).to eq message_bulk
          end
        end

        expect { fetch.call }.not_to raise_error
      end
    end

    context 'when supported exception is raised' do
      connection_clear_errors.each do |error|
        context "when #{error} is raised" do
          before do
            expect(subject)
              .to receive(:target)
              .and_raise(error)
          end

          it 'should try closing the connection' do
            expect(subject)
              .to receive(:close)

            block = -> {}

            expect { subject.fetch(options, &block) }.not_to raise_error
          end
        end
      end
    end

    context 'when partition cannot be claimed' do
      before do
        expect(subject)
          .to receive(:target)
          .and_return(target)

        expect(target)
          .to receive(:fetch)
          .with(options)
          .and_return(false)

        expect(subject)
          .to receive(:close)

        expect(subject)
          .to receive(:sleep)
          .with(described_class::CLAIM_SLEEP_TIME)
      end

      it 'should close the connection and wait' do
        fetch = lambda do
          subject.fetch(options)
        end

        expect { fetch.call }.not_to raise_error
      end
    end
  end

  describe '#target' do
    context 'when everything is ok' do
      before do
        expect(Poseidon::ConsumerGroup)
          .to receive(:new)
          .with(
            controller.group.to_s,
            ::Karafka::App.config.kafka_hosts,
            ::Karafka::App.config.zookeeper_hosts,
            controller.topic.to_s,
            socket_timeout_ms: described_class::SOCKET_TIMEOUT_MS,
            max_wait_ms: described_class::MAX_WAIT_MS
          )
      end

      it 'should create Poseidon::ConsumerGroup instance' do
        expect(subject)
          .not_to receive(:close)

        subject.send(:target)
      end
    end

    context 'when we cannot create Poseidon::ConsumerGroup' do
      connection_clear_errors.each do |error|
        context "when #{error} is raised" do
          before do
            expect(Poseidon::ConsumerGroup)
              .to receive(:new)
              .and_raise(error)
          end

          it 'should try to close it' do
            expect(subject)
              .to receive(:close)

            subject.send(:target)
          end
        end
      end
    end
  end

  describe '#close' do
    before do
      subject.instance_variable_set(:@target, target)
    end

    context 'when target is not existing' do
      let(:target) { nil }
      let(:method_target) { double }

      it 'should do nothing' do
        allow(subject)
          .to receive(:target)
          .and_return(method_target)

        expect(method_target)
          .not_to receive(:close)

        expect(method_target)
          .not_to receive(:reload)

        subject.send(:close)
      end
    end

    context 'when target is existing and we can close it' do
      let(:target) { double }

      it 'should just reload and close it' do
        expect(target)
          .to receive(:reload)

        expect(target)
          .to receive(:close)

        subject.send(:close)
      end
    end

    connection_clear_errors.each do |error|
      context "when we target is existing but closing fails due to #{error}" do
        let(:target) { double }

        before do
          expect(subject)
            .to receive(:target)
            .and_return(target)
            .exactly(2).times

          expect(target)
            .to receive(:reload)

          expect(target)
            .to receive(:close)
            .and_raise(error)
        end

        it 'should delete @target assignment so new target will be created' do
          subject.send(:close)
          expect(subject.instance_variable_get(:@target)).to eq nil
        end
      end
    end
  end
end
