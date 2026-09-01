# Render tests for the per-Java-version JVM options templates.
#
# Evaluates attributes/cassandra.rb into a plain hash (so the real cookbook
# defaults are what gets asserted, not a hand-copied snapshot), renders
# templates/default/cassandra-jvm{11,17}-server.options.erb against it, and
# checks the tuning flags that issue #43 pins down. Runs with plain rspec:
#
#   rspec --options /dev/null spec/unit/templates/cassandra_jvm_options_spec.rb
#
require 'erb'

# Auto-vivifying hash so `default['a']['b']['c'] = x` works when the attributes
# file is instance_eval'd against it.
class AttributeCollector
  def initialize
    @data = Hash.new { |h, k| h[k] = AttributeCollector.new }
  end

  def [](key)
    @data[key]
  end

  def []=(key, value)
    @data[key] = value
  end

  def to_h
    @data.each_with_object({}) do |(k, v), out|
      out[k] = v.is_a?(AttributeCollector) ? v.to_h : v
    end
  end
end

class JvmTemplateContext
  def initialize(node)
    @node = node
  end

  attr_reader :node

  def render(path)
    ERB.new(File.read(path), trim_mode: '-').result(binding)
  end
end

RSpec.describe 'JVM server options templates' do
  # Real defaults from attributes/cassandra.rb.
  let(:defaults) do
    collector = AttributeCollector.new
    collector.instance_eval(
      File.read(File.expand_path('../../../attributes/cassandra.rb', __dir__)),
      'attributes/cassandra.rb'
    )
    collector.to_h
  end

  # instance_eval can't see `default` as a local, so expose it as a method.
  before do
    AttributeCollector.class_eval do
      def default
        self
      end
    end
  end

  def render(template, overrides = {})
    attrs = defaults['axonops']['cassandra'].merge(overrides)
    path = File.expand_path("../../../templates/default/#{template}", __dir__)
    JvmTemplateContext.new({ 'axonops' => { 'cassandra' => attrs } }).render(path)
  end

  describe 'defaults' do
    it 'keeps the Shenandoah heuristic on adaptive' do
      expect(defaults['axonops']['cassandra']['gc_shenandoah_heuristics']).to eq('adaptive')
    end

    it 'does not enable transparent huge pages' do
      expect(defaults['axonops']['cassandra']['gc_use_transparent_huge_pages']).to be(false)
    end
  end

  %w(cassandra-jvm11-server.options.erb cassandra-jvm17-server.options.erb).each do |template|
    context template do
      let(:shenandoah) { render(template, 'gc_type' => 'Shenandoah') }

      it 'selects Shenandoah' do
        expect(shenandoah).to include('-XX:+UseShenandoahGC')
      end

      it 'uses the adaptive heuristic and never compact' do
        expect(shenandoah).to include('-XX:ShenandoahGCHeuristics=adaptive')
        expect(shenandoah).not_to include('ShenandoahGCHeuristics=compact')
      end

      it 'emits no fixed young generation size' do
        expect(shenandoah).not_to match(/^\s*-Xmn/)
      end

      it 'emits no transparent huge pages flag by default' do
        expect(shenandoah).not_to include('-XX:+UseTransparentHugePages')
      end
    end
  end

  context 'cassandra-jvm17-server.options.erb with THP re-enabled' do
    it 'emits the transparent huge pages flag' do
      rendered = render(
        'cassandra-jvm17-server.options.erb',
        'gc_type' => 'Shenandoah',
        'gc_use_transparent_huge_pages' => true
      )
      expect(rendered).to include('-XX:+UseTransparentHugePages')
    end
  end
end
