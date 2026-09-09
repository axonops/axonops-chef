# Render tests for the OpenSearch java.io.tmpdir drop-ins (issue #46).
#
# Evaluates attributes/server.rb into a plain hash (so the real cookbook
# default is asserted, not a hand-copied snapshot) and renders the two tmpdir
# templates against it. Runs with plain rspec — no ChefSpec/Berkshelf:
#
#   rspec --options /dev/null spec/unit/templates/opensearch_tmpdir_spec.rb
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

class TmpdirTemplateContext
  def render(path, variables)
    variables.each { |k, v| instance_variable_set("@#{k}", v) }
    ERB.new(File.read(path), trim_mode: '-').result(binding)
  end
end

RSpec.describe 'OpenSearch java.io.tmpdir drop-ins' do
  let(:defaults) do
    collector = AttributeCollector.new
    collector.instance_eval(
      File.read(File.expand_path('../../../attributes/server.rb', __dir__)),
      'attributes/server.rb'
    )
    collector.to_h
  end

  before do
    # instance_eval can't see `default` as a local, so expose it as a method.
    AttributeCollector.class_eval { def default; self; end }
    # attributes/server.rb reads node['ipaddress'] / node['fqdn'] / node['hostname'].
    AttributeCollector.class_eval { def node; self; end }
  end

  def render(template, java_tmp_dir)
    path = File.expand_path("../../../templates/default/#{template}", __dir__)
    TmpdirTemplateContext.new.render(path, java_tmp_dir: java_tmp_dir)
  end

  describe 'default attribute' do
    it 'points java_tmp_dir at an executable directory off /tmp' do
      expect(defaults['axonops']['server']['elastic']['java_tmp_dir'])
        .to eq('/var/lib/opensearch/tmp')
    end
  end

  describe 'opensearch-jvm-tmpdir.options.erb' do
    subject { render('opensearch-jvm-tmpdir.options.erb', '/var/lib/opensearch/tmp') }

    it 'sets -Djava.io.tmpdir to the configured directory' do
      expect(subject).to include('-Djava.io.tmpdir=/var/lib/opensearch/tmp')
    end

    it 'sets no other -D flag' do
      d_flags = subject.each_line.grep(/^-D/)
      expect(d_flags.length).to eq(1)
    end
  end

  describe 'opensearch-systemd-tmpdir.conf.erb' do
    subject { render('opensearch-systemd-tmpdir.conf.erb', '/var/lib/opensearch/tmp') }

    it 'exports OPENSEARCH_TMPDIR under a [Service] section' do
      expect(subject).to include('[Service]')
      expect(subject).to include('Environment=OPENSEARCH_TMPDIR=/var/lib/opensearch/tmp')
    end
  end
end
