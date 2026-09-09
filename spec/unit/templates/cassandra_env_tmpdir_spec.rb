# Render tests for the java.io.tmpdir / jna.tmpdir / io.netty.native.workdir
# handling in cassandra-env.sh (issue #47).
#
# Evaluates attributes/cassandra.rb into a plain hash so the real cookbook
# defaults are asserted, renders templates/default/cassandra-env.sh.erb against
# it, and checks that the defaults change nothing while non-/tmp values export
# TMPDIR and add the matching -D flags. Runs with plain rspec:
#
#   rspec --options /dev/null spec/unit/templates/cassandra_env_tmpdir_spec.rb
#
require 'erb'

# Auto-vivifying hash so `default['a']['b']['c'] = x` works when the attributes
# file is instance_eval'd against it.
class EnvAttributeCollector
  def initialize
    @data = Hash.new { |h, k| h[k] = EnvAttributeCollector.new }
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
      out[k] = v.is_a?(EnvAttributeCollector) ? v.to_h : v
    end
  end
end

class EnvTemplateContext
  def initialize(node, variables)
    @node = node
    variables.each { |k, v| instance_variable_set("@#{k}", v) }
  end

  attr_reader :node

  def render(path)
    ERB.new(File.read(path), trim_mode: '-').result(binding)
  end
end

RSpec.describe 'cassandra-env.sh.erb temporary directories' do
  let(:defaults) do
    collector = EnvAttributeCollector.new
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
  def render(overrides = {})
    attrs = defaults['axonops']['cassandra']
    variables = {
      heap_size: attrs['heap_size'],
      new_heap_size: attrs['new_heap_size'],
      log_dir: '/var/log/cassandra',
      jmx_port: attrs['jmx_port'],
      enable_jmx_authentication: attrs['jmx_authentication'],
      gc_log_dir: '/var/log/cassandra',
      java_major: 17,
      jemalloc_path: nil,
      axon_java_agent_jar: nil,
      java_tmp_dir: attrs['java_tmp_dir'],
      jna_tmp_dir: attrs['jna_tmp_dir'],
    }.merge(overrides)
    EnvTemplateContext.new({ 'axonops' => { 'cassandra' => attrs } }, variables).render(template)
  end

  describe 'defaults' do
    it 'keeps both temporary directories on /tmp' do
      expect(defaults['axonops']['cassandra']['java_tmp_dir']).to eq('/tmp')
      expect(defaults['axonops']['cassandra']['jna_tmp_dir']).to eq('/tmp')
    end

    it 'renders no temporary-directory settings at all' do
      rendered = render
      expect(rendered).not_to include('TMPDIR')
      expect(rendered).not_to include('java.io.tmpdir')
      expect(rendered).not_to include('jna.tmpdir')
      expect(rendered).not_to include('io.netty.native.workdir')
    end

    it 'renders identically to an empty setting' do
      expect(render(java_tmp_dir: '', jna_tmp_dir: '')).to eq(render)
    end
  end

  describe 'with both directories moved off /tmp' do
    let(:rendered) do
      render(java_tmp_dir: '/var/lib/cassandra/tmp', jna_tmp_dir: '/var/lib/cassandra/tmp')
    end

    it 'exports TMPDIR' do
      expect(rendered).to include('export TMPDIR="/var/lib/cassandra/tmp"')
    end

    it 'sets java.io.tmpdir and io.netty.native.workdir' do
      expect(rendered).to include('-Djava.io.tmpdir=/var/lib/cassandra/tmp')
      expect(rendered).to include('-Dio.netty.native.workdir=/var/lib/cassandra/tmp')
    end

    it 'sets jna.tmpdir' do
      expect(rendered).to include('-Djna.tmpdir=/var/lib/cassandra/tmp')
    end

    it 'sets them before JVM_EXTRA_OPTS is appended' do
      expect(rendered.index('-Djava.io.tmpdir=')).to be < rendered.index('$JVM_EXTRA_OPTS')
    end
  end

  describe 'with only jna_tmp_dir moved off /tmp' do
    let(:rendered) { render(jna_tmp_dir: '/var/lib/cassandra/jna') }

    it 'sets jna.tmpdir' do
      expect(rendered).to include('-Djna.tmpdir=/var/lib/cassandra/jna')
    end

    it 'leaves TMPDIR and java.io.tmpdir alone' do
      expect(rendered).not_to include('TMPDIR')
      expect(rendered).not_to include('java.io.tmpdir')
      expect(rendered).not_to include('io.netty.native.workdir')
    end
  end
end
