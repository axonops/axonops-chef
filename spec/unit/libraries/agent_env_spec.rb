# Pure-Ruby unit spec for the AxonOpsAgentEnv library (ASB-4712).
#
# Deliberately does NOT load ChefSpec/Berkshelf so it can run with a plain
# `rspec` against the library logic alone:
#
#   rspec --options /dev/null spec/unit/libraries/agent_env_spec.rb
#
require_relative '../../../libraries/agent_env'

RSpec.describe AxonOpsAgentEnv do
  let(:package) { 'axon-cassandra4.1-agent-jdk11' }
  let(:legacy) { described_class.legacy_line(package) }
  let(:source) { described_class::SOURCE_LINE }

  def edit(content, options_file_present: true, prefer_options_file: true)
    described_class.edit_for(
      content,
      options_file_present: options_file_present,
      package: package,
      prefer_options_file: prefer_options_file
    )
  end

  describe 'a fresh install with agent 1.1.0 or newer' do
    it 'adds the options file' do
      expect(edit("JVM_OPTS=\"$JVM_OPTS -ea\"\n")).to eq([:insert, source])
    end

    it 'guards the inserted line on the options file existing' do
      expect(source).to eq('[ -f /usr/share/axonops/axonops-jvm.options ] && . /usr/share/axonops/axonops-jvm.options')
    end
  end

  describe 'an install already using the options file' do
    it 'changes nothing' do
      expect(edit("#{source}\n")).to eq([:none])
    end

    it 'changes nothing when the line uses the `source` builtin' do
      expect(edit("source /usr/share/axonops/axonops-jvm.options\n")).to eq([:none])
    end

    it 'changes nothing for an unguarded line written by an older cookbook' do
      expect(edit(". /usr/share/axonops/axonops-jvm.options\n")).to eq([:none])
    end
  end

  describe 'an existing install using the old -javaagent line' do
    it 'replaces the old line instead of adding a second one' do
      action, pattern, line = edit("#{legacy}\n")
      expect(action).to eq(:replace)
      expect(line).to eq(source)
      expect("#{legacy}\n").to match(pattern)
    end

    it 'replaces a legacy line naming a different agent package' do
      other = described_class.legacy_line('axon-cassandra3.11-agent')
      action, pattern, = edit("#{other}\n")
      expect(action).to eq(:replace)
      expect(other).to match(pattern)
    end

    it 'ignores a commented-out legacy line' do
      expect(edit("# #{legacy}\n")).to eq([:insert, source])
    end
  end

  describe 'a file that somehow carries both lines' do
    it 'comments the legacy line out and keeps the options file' do
      action, _pattern, line = edit("#{legacy}\n#{source}\n")
      expect(action).to eq(:replace)
      expect(line).to eq(described_class::DISABLED_LEGACY_LINE)
      expect(line).not_to include('-javaagent')
    end
  end

  describe 'an agent older than 1.1.0 (no options file on disk)' do
    it 'falls back to the -javaagent line' do
      expect(edit("\n", options_file_present: false)).to eq([:insert, legacy])
    end

    it 'leaves an existing -javaagent line alone' do
      expect(edit("#{legacy}\n", options_file_present: false)).to eq([:none])
    end

    it 'rewrites a line naming a jar the current package no longer ships' do
      stale = described_class.legacy_line('axon-cassandra4.1-agent-jdk8')
      action, pattern, line = edit("#{stale}\n", options_file_present: false)
      expect(action).to eq(:replace)
      expect(line).to eq(legacy)
      expect(stale).to match(pattern)
    end
  end

  describe 'DSE, whose agent packages ship no options file' do
    it 'uses the -javaagent line' do
      expect(edit("\n", prefer_options_file: false)).to eq([:insert, legacy])
    end

    it 'never adds a second line next to an existing one' do
      expect(edit("#{legacy}\n", prefer_options_file: false)).to eq([:none])
    end

    it 'rewrites the line in place after a DSE agent upgrade' do
      old_dse = described_class.legacy_line('axon-dse6.8-agent')
      action, pattern, line = described_class.edit_for(
        "#{old_dse}\n",
        options_file_present: false,
        package: 'axon-dse6.9-agent',
        prefer_options_file: false
      )
      expect(action).to eq(:replace)
      expect(line).to include('axon-dse6.9-agent.jar')
      expect(old_dse).to match(pattern)
    end
  end
end
