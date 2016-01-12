require 'spec_helper'

RSpec.describe Karafka::Cli do
  subject { described_class.new }

  describe '#install' do
    it 'expect to create proper dirs and copy template files' do
      described_class::INSTALL_DIRS.each do |dir|
        expect(FileUtils)
          .to receive(:mkdir_p)
          .with(Karafka.root.join(dir))
      end

      described_class::INSTALL_FILES_MAP.each do |source, target|
        expect(File)
          .to receive(:exist?)
          .with(target)
          .and_return(false)

        expect(FileUtils)
          .to receive(:cp_r)
          .with(
            Karafka.core_root.join("templates/#{source}"),
            target
          )
      end

      subject.install
    end
  end
end
