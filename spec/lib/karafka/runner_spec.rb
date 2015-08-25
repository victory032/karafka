require 'spec_helper'

RSpec.describe Karafka::Runner do
  subject { described_class.new }

  describe '#new' do
    it 'should have a consumer instance created' do
      expect(subject.instance_variable_get(:'@consumer')).to be_a Karafka::Connection::Consumer
    end
  end

  describe '#run' do
    it 'should start fetching and just sleep (rest will happen in celluloid actors)' do
      expect(subject)
        .to receive(:sleep)

      expect(subject)
        .to receive(:fetch)

      subject.run
    end
  end

  describe '#fetch' do
    let(:consumer) { double }

    context 'when everything is ok' do
      it 'should just fetch from the consumer and not log anything' do
        expect(Karafka.logger)
          .not_to receive(:fatal)

        subject.instance_variable_set(:'@consumer', consumer)

        expect(consumer)
          .to receive(:fetch)

        subject.send(:fetch)
      end
    end

    context 'when we have a fatal error' do
      it 'should log this error' do
        expect(consumer)
          .to receive(:fetch)
          .and_raise(StandardError)

        subject.instance_variable_set(:'@consumer', consumer)

        expect(Karafka.logger)
          .to receive(:fatal)

        expect { subject.send(:fetch) }.not_to raise_error
      end
    end
  end
end
