# Render tests for the snapshot client settings in opensearch.yml.erb.
#
#   rspec --options /dev/null spec/unit/templates/opensearch_snapshot_yml_spec.rb
#
require 'erb'
require 'json'
require 'yaml'
require_relative '../../../libraries/opensearch_snapshot'

class SnapshotYmlContext
  def render(variables)
    variables.each { |k, v| instance_variable_set("@#{k}", v) }
    path = File.expand_path('../../../templates/default/opensearch.yml.erb', __dir__)
    ERB.new(File.read(path), trim_mode: '-').result(binding)
  end
end

RSpec.describe 'opensearch.yml.erb snapshot settings' do
  let(:base_vars) do
    {
      cluster_name: 'axonops-cluster', node_name: 'n1-axonops', listen_host: '127.0.0.1', listen_port: 9200,
      path_data: '/var/lib/opensearch', path_logs: '/var/log/opensearch', security_plugin_enabled: false
    }
  end

  def render(settings)
    YAML.safe_load(SnapshotYmlContext.new.render(base_vars.merge(snapshot_settings: settings)))
  end

  it 'renders no client settings when snapshots are disabled' do
    config = render({})
    expect(config.keys.grep(/\A(s3|gcs)\./)).to be_empty
  end

  it 'renders S3 client settings with typed values' do
    config = render(
      's3.client.default.endpoint' => 'minio.example.com:9000',
      's3.client.default.path_style_access' => true,
      's3.client.default.max_retries' => 5
    )
    expect(config['s3.client.default.endpoint']).to eq('minio.example.com:9000')
    expect(config['s3.client.default.path_style_access']).to be true
    expect(config['s3.client.default.max_retries']).to eq(5)
  end

  it 'quotes values so YAML special characters stay strings' do
    config = render('gcs.client.default.endpoint' => 'https://gcs.example.com:443/#x')
    expect(config['gcs.client.default.endpoint']).to eq('https://gcs.example.com:443/#x')
  end

  it 'keeps the existing settings' do
    config = render('s3.client.default.region' => 'eu-west-1')
    expect(config['cluster.name']).to eq('axonops-cluster')
    expect(config['plugins.security.disabled']).to be true
  end

  it 'never carries attribute defaults that enable snapshots' do
    collector = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
    ctx = Object.new
    ctx.define_singleton_method(:default) { collector }
    ctx.define_singleton_method(:node) { collector }
    ctx.instance_eval(File.read(File.expand_path('../../../attributes/server.rb', __dir__)), 'attributes/server.rb')
    expect(collector['axonops']['server']['elastic']['snapshot']['enabled']).to be false
  end
end
