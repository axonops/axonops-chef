# Pure-Ruby unit spec for the AxonOpsCassandra library.
#
# Deliberately does NOT load ChefSpec/Berkshelf so it can run with a plain
# `rspec` against the library logic alone:
#
#   rspec spec/unit/libraries/cassandra_version_spec.rb
#
require_relative '../../../libraries/cassandra_version'

RSpec.describe AxonOpsCassandra do
  describe '.series' do
    it 'maps full versions to the supported series' do
      expect(described_class.series('3.11.17')).to eq('3.11')
      expect(described_class.series('4.1.5')).to eq('4.1')
      expect(described_class.series('5.0.5')).to eq('5.0')
      expect(described_class.series('5.0.8')).to eq('5.0')
    end

    it 'maps DSE 5.1 versions to the 5.1 series, not Apache 5.0' do
      expect(described_class.series('5.1.17')).to eq('5.1')
      expect(described_class.series('5.1.0')).to eq('5.1')
    end

    it 'raises on an unsupported version' do
      expect { described_class.series('2.2.0') }.to raise_error(ArgumentError)
      expect { described_class.series('6.0.0') }.to raise_error(ArgumentError)
    end
  end

  describe '.java_major' do
    it 'returns the Java major required by each series' do
      expect(described_class.java_major('3.11.17')).to eq(8)
      expect(described_class.java_major('4.1.5')).to eq(11)
      expect(described_class.java_major('5.0.5')).to eq(17)
      expect(described_class.java_major('5.1.17')).to eq(8)
    end
  end

  describe '.dse_installed?' do
    it 'is true when /etc/dse/cassandra/cassandra.yaml exists' do
      allow(::File).to receive(:exist?).and_return(false)
      allow(::File).to receive(:exist?).with('/etc/dse/cassandra/cassandra.yaml').and_return(true)
      allow(::Dir).to receive(:glob).with('/opt/dse').and_return([])
      expect(described_class.dse_installed?).to be(true)
    end

    it 'is true when /opt/dse exists' do
      allow(::File).to receive(:exist?).and_return(false)
      allow(::Dir).to receive(:glob).with('/opt/dse').and_return(['/opt/dse'])
      expect(described_class.dse_installed?).to be(true)
    end

    it 'is false when neither path exists' do
      allow(::File).to receive(:exist?).and_return(false)
      allow(::Dir).to receive(:glob).with('/opt/dse').and_return([])
      expect(described_class.dse_installed?).to be(false)
    end
  end

  describe '.dse_env_file' do
    it 'returns the explicit override unconditionally' do
      expect(described_class.dse_env_file('/custom/cassandra-env.sh', ['/opt/dse'])).to eq('/custom/cassandra-env.sh')
    end

    it 'falls back to the rpm/deb default when it exists' do
      allow(::File).to receive(:exist?).and_return(false)
      allow(::File).to receive(:exist?).with('/etc/dse/cassandra/cassandra-env.sh').and_return(true)
      expect(described_class.dse_env_file(nil, ['/opt/dse'])).to eq('/etc/dse/cassandra/cassandra-env.sh')
    end

    it 'searches the tar layout under resources/cassandra/conf when the rpm/deb default is absent' do
      allow(::File).to receive(:exist?).and_return(false)
      allow(::File).to receive(:exist?)
        .with('/opt/dse/resources/cassandra/conf/cassandra-env.sh').and_return(true)
      allow(::Dir).to receive(:glob).with('/opt/dse').and_return(['/opt/dse'])
      expect(described_class.dse_env_file(nil, ['/opt/dse'])).to eq('/opt/dse/resources/cassandra/conf/cassandra-env.sh')
    end

    it 'returns nil when nothing matches' do
      allow(::File).to receive(:exist?).and_return(false)
      allow(::Dir).to receive(:glob).with('/opt/dse').and_return([])
      expect(described_class.dse_env_file(nil, ['/opt/dse'])).to be_nil
    end
  end

  describe '.legacy_schema?' do
    it 'is true only for 3.11' do
      expect(described_class.legacy_schema?('3.11.17')).to be(true)
      expect(described_class.legacy_schema?('4.1.5')).to be(false)
      expect(described_class.legacy_schema?('5.0.5')).to be(false)
    end
  end

  describe '.template_dir' do
    it 'returns the version-specific template subdirectory' do
      expect(described_class.template_dir('3.11.17')).to eq('3.11')
      expect(described_class.template_dir('4.1.5')).to eq('4.1')
      expect(described_class.template_dir('5.0.5')).to eq('5.0')
    end
  end

  describe '.to_ms' do
    it 'converts duration strings to milliseconds' do
      expect(described_class.to_ms('2000ms')).to eq(2000)
      expect(described_class.to_ms('5000ms')).to eq(5000)
      expect(described_class.to_ms('5s')).to eq(5000)
      expect(described_class.to_ms('30m')).to eq(1_800_000)
      expect(described_class.to_ms('3h')).to eq(10_800_000)
      expect(described_class.to_ms('1d')).to eq(86_400_000)
    end

    it 'treats bare numbers as milliseconds' do
      expect(described_class.to_ms('250')).to eq(250)
    end
  end

  describe '.to_secs' do
    it 'converts duration strings to seconds' do
      expect(described_class.to_secs('14400s')).to eq(14_400)
      expect(described_class.to_secs('0s')).to eq(0)
      expect(described_class.to_secs('7200s')).to eq(7200)
      expect(described_class.to_secs('4h')).to eq(14_400)
      expect(described_class.to_secs('30s')).to eq(30)
    end
  end

  describe '.to_kib' do
    it 'converts size strings to kibibytes' do
      expect(described_class.to_kib('1024KiB')).to eq(1024)
      expect(described_class.to_kib('640KiB')).to eq(640)
      expect(described_class.to_kib('64KiB')).to eq(64)
      expect(described_class.to_kib('1MiB')).to eq(1024)
    end
  end

  describe '.to_mib' do
    it 'converts size strings to mebibytes' do
      expect(described_class.to_mib('128MiB')).to eq(128)
      expect(described_class.to_mib('32MiB')).to eq(32)
      expect(described_class.to_mib('512MiB')).to eq(512)
      expect(described_class.to_mib('10MiB')).to eq(10)
    end
  end

  describe '.mib_per_s_to_megabits' do
    it 'applies the Ansible 8x factor' do
      expect(described_class.mib_per_s_to_megabits('24MiB/s')).to eq(192)
      expect(described_class.mib_per_s_to_megabits('25MiB/s')).to eq(200)
    end
  end
end
