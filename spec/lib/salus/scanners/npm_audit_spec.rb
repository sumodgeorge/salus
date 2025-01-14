require_relative '../../../spec_helper.rb'

describe Salus::Scanners::NPMAudit do
  describe '#should_run?' do
    it 'should return false in the absence of package.json and friends' do
      repo = Salus::Repo.new('spec/fixtures/blank_repository')
      expect(repo.package_lock_json_present?).to eq(false)

      scanner = Salus::Scanners::NPMAudit.new(repository: repo, config: {})
      expect(scanner.should_run?).to eq(false)
    end

    it 'should return true if package.json is present' do
      repo = Salus::Repo.new('spec/fixtures/npm_audit/success')
      expect(repo.package_lock_json_present?).to eq(true)

      scanner = Salus::Scanners::NPMAudit.new(repository: repo, config: {})
      expect(scanner.should_run?).to eq(true)
    end
  end

  describe '#version_valid?' do
    context 'scanner version is valid' do
      it 'should return true' do
        repo = Salus::Repo.new("dir")
        scanner = Salus::Scanners::NPMAudit.new(repository: repo, config: {})
        expect(scanner.version).to be_a_valid_version
      end
    end
  end

  describe '#supported_languages' do
    context 'should return supported languages' do
      it 'should return javascript' do
        langs = Salus::Scanners::NPMAudit.supported_languages
        expect(langs).to eq(['javascript'])
      end
    end
  end
end
