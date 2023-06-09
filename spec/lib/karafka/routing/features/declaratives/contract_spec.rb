# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      declaratives: {
        active: true,
        partitions: 1,
        replication_factor: 2,
        details: {}
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when active flag is not true' do
    before { config[:declaratives][:active] = false }

    it { expect(check).to be_success }
  end

  context 'when there are not enough partitions' do
    before { config[:declaratives][:partitions] = 0 }

    it { expect(check).not_to be_success }
  end

  context 'when details are not a hash' do
    before { config[:declaratives][:details] = 0 }

    it { expect(check).not_to be_success }
  end

  context 'when details are a hash with non-symbol keys' do
    before { config[:declaratives][:details] = { 'test' => 1 } }

    it { expect(check).not_to be_success }
  end
end
