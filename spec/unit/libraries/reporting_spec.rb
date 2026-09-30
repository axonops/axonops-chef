# Pure-Ruby unit spec for the AxonOpsReporting library (Reports v2, ASB-4652).
#
#   rspec --options /dev/null spec/unit/libraries/reporting_spec.rb
#
require_relative '../../../libraries/reporting'

RSpec.describe AxonOpsReporting do
  describe '.server_supports_reporting_url?' do
    it 'is true for latest, nil and empty (newest release)' do
      expect(described_class.server_supports_reporting_url?('latest')).to be true
      expect(described_class.server_supports_reporting_url?(nil)).to be true
      expect(described_class.server_supports_reporting_url?('')).to be true
    end

    it 'is true from 2.0.39' do
      expect(described_class.server_supports_reporting_url?('2.0.39')).to be true
      expect(described_class.server_supports_reporting_url?('2.1.0')).to be true
    end

    it 'is false for 2.0.4 to 2.0.38' do
      expect(described_class.server_supports_reporting_url?('2.0.38')).to be false
      expect(described_class.server_supports_reporting_url?('2.0.4')).to be false
    end

    it 'ignores a Debian package revision' do
      expect(described_class.server_supports_reporting_url?('2.0.39-1')).to be true
      expect(described_class.server_supports_reporting_url?('2.0.5-1')).to be false
    end

    it 'is false for an unparseable version' do
      expect(described_class.server_supports_reporting_url?('not a version')).to be false
    end
  end

  describe '.package_version' do
    it 'returns nil for latest or empty' do
      expect(described_class.package_version('latest')).to be_nil
      expect(described_class.package_version('')).to be_nil
      expect(described_class.package_version(nil)).to be_nil
    end

    it 'returns a pinned version unchanged' do
      expect(described_class.package_version('1.2.3')).to eq('1.2.3')
    end
  end
end
