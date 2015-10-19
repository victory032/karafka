require 'spec_helper'

RSpec.describe Karafka::Connection::Listener do
  let(:controller) do
    ClassBuilder.inherit(Karafka::BaseController) do
      self.group = rand
      self.topic = rand

      def perform
        self
      end
    end
  end

  subject { described_class.new(controller) }

  describe '#fetch' do
    let(:action) { double }
    [
      ZK::Exceptions::OperationTimeOut,
      Poseidon::Connection::ConnectionFailedError,
      Exception
    ].each do |error|
      let(:proxy) { double }

      context "when #{error} happens" do
        before do
          # Lets silence exceptions printing
          expect(Karafka.logger)
            .to receive(:error)
            .exactly(2).times
        end

        it 'should close the consumer and not raise error' do
          expect(subject)
            .to receive(:consumer)
            .and_raise(error.new)

          expect { subject.send(:fetch, action) }.not_to raise_error
        end
      end
    end

    context 'when no errors occur' do
      let(:consumer) { double }
      let(:_partition) { double }
      let(:messages_bulk) { [incoming_message] }
      let(:incoming_message) { double }

      it 'should yield for each incoming message' do
        expect(subject)
          .to receive(:consumer)
          .and_return(consumer)
          .at_least(:once)

        expect(consumer)
          .to receive(:fetch)
          .and_yield(_partition, messages_bulk)
        expect(action)
          .to receive(:call)
          .with(subject.controller, incoming_message)

        subject.send(:fetch, action)
      end
    end
  end

  describe '#consumer' do
    context 'when consumer is already created' do
      let(:consumer) { double }

      before do
        subject.instance_variable_set(:'@consumer', consumer)
      end

      it 'should just return it' do
        expect(Poseidon::ConsumerGroup)
          .to receive(:new)
          .never
        expect(subject.send(:consumer)).to eq consumer
      end
    end

    context 'when consumer is not yet created' do
      let(:consumer) { double }

      before do
        subject.instance_variable_set(:'@consumer', nil)
      end

      it 'should create an instance and return' do
        expect(Poseidon::ConsumerGroup)
          .to receive(:new)
          .with(
            controller.group.to_s,
            Karafka::App.config.kafka_hosts,
            Karafka::App.config.zookeeper_hosts,
            controller.topic.to_s
          )
          .and_return(consumer)

        expect(subject.send(:consumer)).to eq consumer
      end
    end
  end
end
