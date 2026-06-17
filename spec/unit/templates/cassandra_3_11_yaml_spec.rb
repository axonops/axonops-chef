# Render test for the legacy Cassandra 3.11 cassandra.yaml template.
#
# Renders templates/default/3.11/cassandra.yaml.erb with a stubbed node and the
# same variables() the configure_cassandra recipe passes, then asserts the
# output is valid YAML using the legacy 3.11 schema. Runs with plain rspec:
#
#   rspec --options /dev/null spec/unit/templates/cassandra_3_11_yaml_spec.rb
#
require 'erb'
require 'yaml'
require_relative '../../../libraries/cassandra_version'

# Minimal render context mimicking Chef's template binding: node() accessor plus
# the variables() hash exposed as instance variables.
class TemplateContext
  def initialize(node, vars)
    @node = node
    vars.each { |k, v| instance_variable_set("@#{k}", v) }
  end

  attr_reader :node

  def render(path)
    ERB.new(File.read(path), trim_mode: '-').result(binding)
  end
end

RSpec.describe 'templates/default/3.11/cassandra.yaml.erb' do
  let(:template_path) do
    File.expand_path('../../../templates/default/3.11/cassandra.yaml.erb', __dir__)
  end

  # Representative subset of attributes/cassandra.rb defaults that the template
  # consumes (modern string-unit values to be converted to the 3.11 schema).
  let(:cassandra_attrs) do
    {
      'version' => '3.11.17',
      'hinted_handoff_enabled' => true,
      'max_hint_window' => '3h',
      'hinted_handoff_throttle' => '1024KiB',
      'max_hints_delivery_threads' => 2,
      'hints_flush_period' => '10000ms',
      'max_hints_file_size' => '128MiB',
      'batchlog_replay_throttle' => '1024KiB',
      'role_manager' => 'CassandraRoleManager',
      'roles_validity' => '2000ms',
      'roles_update_interval' => nil,
      'permissions_validity' => '2000ms',
      'permissions_update_interval' => nil,
      'credentials_validity' => '2000ms',
      'credentials_update_interval' => nil,
      'cdc_enabled' => false,
      'disk_failure_policy' => 'stop',
      'commit_failure_policy' => 'stop',
      'key_cache_size' => nil,
      'key_cache_save_period' => '14400s',
      'row_cache_size' => '0MiB',
      'row_cache_save_period' => '0s',
      'counter_cache_size' => nil,
      'counter_cache_save_period' => '7200s',
      'prepared_statements_cache_size' => nil,
      'commitlog_sync_period' => '10000ms',
      'commitlog_segment_size' => '32MiB',
      'concurrent_compactors' => nil,
      'memtable_allocation_type' => 'heap_buffers',
      'trickle_fsync' => true,
      'trickle_fsync_interval' => '10MiB',
      'listen_on_broadcast_address' => false,
      'rpc_port' => 9160,
      'incremental_backups' => false,
      'auto_snapshot' => true,
      'column_index_size' => '64KiB',
      'batch_size_warn_threshold' => '5KiB',
      'batch_size_fail_threshold' => '50KiB',
      'compaction_throughput_mb_per_sec' => 64,
      'sstable_preemptive_open_interval' => '50MiB',
      'read_request_timeout' => '5000ms',
      'range_request_timeout' => '10000ms',
      'write_request_timeout' => '2000ms',
      'counter_write_request_timeout' => '5000ms',
      'cas_contention_timeout' => '1000ms',
      'truncate_request_timeout' => '60000ms',
      'request_timeout' => '10000ms',
      'slow_query_log_timeout' => '500ms',
      'streaming_keep_alive_period' => '30s',
      'stream_throughput_outbound_megabits_per_sec' => 200,
      'inter_dc_stream_throughput_outbound_megabits_per_sec' => 200,
      'phi_convict_threshold' => nil,
      'dynamic_snitch_update_interval' => '100ms',
      'dynamic_snitch_reset_interval' => '600000ms',
      'dynamic_snitch_badness_threshold' => 0.1,
      'internode_compression' => 'dc',
      'tombstone_warn_threshold' => 1000,
      'tombstone_failure_threshold' => 100_000,
      'gc_warn_threshold' => '2000ms',
      'server_encryption_options' => { 'internode_encryption' => 'none' },
      'client_encryption_options' => { 'enabled' => false, 'optional' => true },
    }
  end

  let(:node) { { 'axonops' => { 'cassandra' => cassandra_attrs } } }

  let(:vars) do
    {
      cluster_name: 'TestCluster',
      num_tokens: 16,
      data_file_directories: ['/var/lib/cassandra/data'],
      commitlog_directory: '/var/lib/cassandra/commitlog',
      saved_caches_directory: '/var/lib/cassandra/saved_caches',
      hints_directory: '/var/lib/cassandra/hints',
      cdc_raw_directory: '/var/lib/cassandra/cdc_raw',
      seeds: '10.0.0.1,10.0.0.2',
      listen_address: '10.0.0.1',
      rpc_address: '10.0.0.1',
      broadcast_address: nil,
      broadcast_rpc_address: nil,
      native_transport_port: 9042,
      storage_port: 7000,
      ssl_storage_port: 7001,
      endpoint_snitch: 'GossipingPropertyFileSnitch',
      authenticator: 'PasswordAuthenticator',
      authorizer: 'CassandraAuthorizer',
      concurrent_reads: 32,
      concurrent_writes: 32,
      concurrent_counter_writes: 32,
      concurrent_materialized_view_writes: 32,
      memtable_cleanup_threshold: nil,
      memtable_flush_writers: 2,
    }
  end

  subject(:rendered) { TemplateContext.new(node, vars).render(template_path) }

  it 'renders valid YAML' do
    expect { YAML.safe_load(rendered) }.not_to raise_error
  end

  it 'uses the legacy 3.11 integer-unit schema, not the modern schema' do
    doc = YAML.safe_load(rendered)
    expect(doc['read_request_timeout_in_ms']).to eq(5000)
    expect(doc['write_request_timeout_in_ms']).to eq(2000)
    expect(doc['truncate_request_timeout_in_ms']).to eq(60_000)
    expect(doc['commitlog_segment_size_in_mb']).to eq(32)
    expect(doc['hinted_handoff_throttle_in_kb']).to eq(1024)
    expect(doc['key_cache_save_period']).to eq(14_400)
    expect(doc['counter_cache_save_period']).to eq(7200)
    expect(doc['max_hint_window_in_ms']).to eq(10_800_000)
    expect(doc['stream_throughput_outbound_megabits_per_sec']).to eq(200)
    # Modern-schema keys must not appear
    expect(doc).not_to have_key('sstable')
    expect(rendered).not_to include('selected_format')
    expect(rendered).not_to include('allocate_tokens_for_local_replication_factor')
  end

  it 'disables Thrift RPC and enables the native transport' do
    doc = YAML.safe_load(rendered)
    expect(doc['start_rpc']).to be(false)
    expect(doc['start_native_transport']).to be(true)
    expect(doc['rpc_port']).to eq(9160)
  end

  it 'wires the cluster identity and seeds through' do
    doc = YAML.safe_load(rendered)
    expect(doc['cluster_name']).to eq('TestCluster')
    expect(doc['num_tokens']).to eq(16)
    expect(doc['endpoint_snitch']).to eq('GossipingPropertyFileSnitch')
    expect(doc['seed_provider'].first['parameters'].first['seeds']).to eq('10.0.0.1,10.0.0.2')
  end
end
