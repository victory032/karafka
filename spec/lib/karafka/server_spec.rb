require 'spec_helper'

RSpec.describe Karafka::Server do
  subject { described_class }

  describe '#run' do
    let(:runner) { Karafka::Fetcher.new }

    it 'runs in supervision, start consuming' do
      expect(Karafka::App).to receive(:run!)
      expect(Karafka::Fetcher).to receive(:new).and_return(runner)
      expect(runner).to receive(:fetch_loop)
      expect(Karafka::Process.instance).to receive(:supervise).and_yield
      expect(Karafka::Process.instance).to receive(:on_sigint)
      expect(Karafka::Process.instance).to receive(:on_sigquit)

      subject.run
    end

    it 'defines a proper action for sigint' do
      expect(Karafka::Process.instance).to receive(:supervise)
      expect(Karafka::Process.instance).to receive(:on_sigint).and_yield
      expect(Karafka::Process.instance).to receive(:on_sigquit)
      expect(Karafka::App).to receive(:stop!)
      expect(subject).to receive(:exit)

      subject.run
    end

    it 'defines a proper action for sigquit' do
      expect(Karafka::Process.instance).to receive(:supervise)
      expect(Karafka::Process.instance).to receive(:on_sigint)
      expect(Karafka::Process.instance).to receive(:on_sigquit).and_yield
      expect(Karafka::App).to receive(:stop!)
      expect(subject).to receive(:exit)

      subject.run
    end
  end
end
