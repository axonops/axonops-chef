# Render tests for how the AxonOps java agent is wired into cassandra-env.sh
# (ASB-4712).
#
# Evaluates attributes/cassandra.rb into a plain hash so the real cookbook
# defaults are asserted, renders templates/default/cassandra-env.sh.erb against
# it, and checks that the defaults change nothing while non-/tmp values export
# TMPDIR and add the matching -D flags. Runs with plain rspec:
#
#   rspec --options /dev/null spec/unit/templates/cassandra_env_agent_spec.rb
#
require 'erb'

# Auto-vivifying hash so `default['a']['b']['c'] = x` works when the attributes
# file is instance_eval'd against it.
class AgentEnvAttributeCollector
  def initialize
    @data = Hash.new { |h, k| h[k] = AgentEnvAttributeCollector.new }
  end

  def [](key)
    @data[key]
  end

  def []=(key, value)
    @data[key] = value
  end

  def default
    self
  end

  def to_h
    @data.each_with_object({}) do |(k, v), out|
      out[k] = v.is_a?(AgentEnvAttributeCollector) ? v.to_h : v
    end
  end
end

class AgentEnvTemplateContext
  def initialize(node, variables)
    @node = node
    variables.each { |k, v| instance_variable_set("@#{k}", v) }
  end

  attr_reader :node

  def render(path)
    ERB.new(File.read(path), trim_mode: '-').result(binding)
  end
end

RSpec.describe 'cassandra-env.sh.erb AxonOps java agent' do
  let(:defaults) do
    collector = AgentEnvAttributeCollector.new
    collector.instance_eval(
      File.read(File.expand_path('../../../attributes/cassandra.rb', __dir__)),
      'attributes/cassandra.rb'
    )
    collector.to_h
  end

  let(:template) do
    File.expand_path('../../../templates/default/cassandra-env.sh.erb', __dir__)
  end

  # Same variables recipes/configure_cassandra.rb passes to the template.
  def render(version, jar)
    attrs = defaults['axonops']['cassandra'].merge('version' => version)
    variables = {
      heap_size: attrs['heap_size'],
      new_heap_size: attrs['new_heap_size'],
      log_dir: '/var/log/cassandra',
      jmx_port: attrs['jmx_port'],
      enable_jmx_authentication: attrs['jmx_authentication'],
      gc_log_dir: '/var/log/cassandra',
      java_major: 17,
      jemalloc_path: nil,
      axon_java_agent_jar: jar,
      java_tmp_dir: attrs['java_tmp_dir'],
      jna_tmp_dir: attrs['jna_tmp_dir'],
    }
    AgentEnvTemplateContext.new({ 'axonops' => { 'cassandra' => attrs } }, variables).render(template)
  end

  {
    '3.11.17' => 'axon-cassandra3.11-agent',
    '4.0.13' => 'axon-cassandra4.0-agent',
    '4.1.5' => 'axon-cassandra4.1-agent',
    '5.0.2' => 'axon-cassandra5.0-agent-jdk17',
  }.each do |version, jar|
    context "Cassandra #{version}" do
      let(:rendered) { render(version, jar) }

      it 'sources axonops-jvm.options when the agent ships it' do
        expect(rendered).to include('. /usr/share/axonops/axonops-jvm.options')
      end

      it 'guards on the options file existing' do
        expect(rendered).to include('if [ -f /usr/share/axonops/axonops-jvm.options ]; then')
      end

      it 'falls back to -javaagent for agents older than 1.1.0' do
        expect(rendered).to include("else\n  JVM_OPTS=\"$JVM_OPTS -javaagent:/usr/share/axonops/#{jar}.jar=/etc/axonops/axon-agent.yml\"")
      end

      it 'never applies both ways of loading the agent' do
        loaders = rendered.lines.count do |line|
          line.match?(%r{^\s*(\.|source)\s+/usr/share/axonops/axonops-jvm\.options}) ||
            line.match?(%r{-javaagent:/usr/share/axonops/axon-})
        end
        expect(loaders).to eq(2) # one per branch of the if/else, only one runs
      end
    end
  end

  context 'with no agent configured' do
    let(:rendered) { render('4.1.5', nil) }

    it 'mentions neither the options file nor the agent jar' do
      expect(rendered).not_to include('axonops-jvm.options')
      expect(rendered).not_to include('-javaagent:/usr/share/axonops/')
    end
  end
end
