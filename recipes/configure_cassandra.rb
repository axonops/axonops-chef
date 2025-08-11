#
# Cookbook:: axonops
# Recipe:: configure_cassandra
#
# Configures Apache Cassandra
#

# Get configuration
cassandra_user = node['axonops']['cassandra']['user']
cassandra_group = node['axonops']['cassandra']['group']
cassandra_home = "#{node['axonops']['cassandra']['install_dir']}/cassandra"
data_root = node['axonops']['cassandra']['data_root']

# Use server attributes if defined, otherwise use cassandra attributes
cluster_name = node['axonops']['server']['cassandra']['cluster_name'] || node['axonops']['cassandra']['cluster_name']
datacenter = node['axonops']['server']['cassandra']['dc'] || node['axonops']['cassandra']['dc']
rack = node['axonops']['server']['cassandra']['rack'] || node['axonops']['cassandra']['rack']

# Ensure configuration directory exists
directory "#{cassandra_home}/conf" do
  owner cassandra_user
  group cassandra_group
  mode '0755'
end

if node['axonops']['cassandra']['ssl']['self_signed']
  include_recipe 'axonops::cassandra_self_signed'
end

# Main cassandra.yaml configuration
template "#{cassandra_home}/conf/cassandra.yaml" do
  source 'cassandra.yaml.erb'
  owner cassandra_user
  group cassandra_group
  mode '0644'
  variables(
    cluster_name: cluster_name,
    num_tokens: node['axonops']['cassandra']['num_tokens'],
    data_file_directories: ["#{data_root}/data"],
    commitlog_directory: "#{data_root}/commitlog",
    saved_caches_directory: "#{data_root}/saved_caches",
    hints_directory: "#{data_root}/hints",
    cdc_raw_directory: "#{data_root}/cdc_raw",
    seeds: node['axonops']['cassandra']['seeds'].join(','),
    listen_address: node['axonops']['cassandra']['listen_address'],
    rpc_address: node['axonops']['cassandra']['rpc_address'],
    broadcast_address: node['axonops']['cassandra']['broadcast_address'],
    broadcast_rpc_address: node['axonops']['cassandra']['broadcast_rpc_address'],
    native_transport_port: node['axonops']['cassandra']['native_transport_port'],
    storage_port: node['axonops']['cassandra']['storage_port'],
    ssl_storage_port: node['axonops']['cassandra']['ssl_storage_port'],
    endpoint_snitch: node['axonops']['cassandra']['endpoint_snitch'],
    authenticator: node['axonops']['cassandra']['authenticator'],
    authorizer: node['axonops']['cassandra']['authorizer'],
    concurrent_reads: node['axonops']['cassandra']['concurrent_reads'],
    concurrent_writes: node['axonops']['cassandra']['concurrent_writes'],
    concurrent_counter_writes: node['axonops']['cassandra']['concurrent_counter_writes'],
    concurrent_materialized_view_writes: node['axonops']['cassandra']['concurrent_materialized_view_writes'],
    disk_optimization_strategy: node['axonops']['cassandra']['disk_optimization_strategy'],
    memtable_allocation_type: node['axonops']['cassandra']['memtable_allocation_type'],
    memtable_cleanup_threshold: node['axonops']['cassandra']['memtable_cleanup_threshold'],
    memtable_flush_writers: node['axonops']['cassandra']['memtable_flush_writers'],
    compaction_throughput_mb_per_sec: node['axonops']['cassandra']['compaction_throughput_mb_per_sec'],
    stream_throughput_outbound_megabits_per_sec: node['axonops']['cassandra']['stream_throughput_outbound_megabits_per_sec'],
    inter_dc_stream_throughput_outbound_megabits_per_sec: node['axonops']['cassandra']['inter_dc_stream_throughput_outbound_megabits_per_sec'],
    server_encryption_options: node['axonops']['cassandra']['server_encryption_options'],
    client_encryption_options: node['axonops']['cassandra']['client_encryption_options']
  )
  notifies :restart, 'service[cassandra]', :delayed
end

# JVM options configuration
jvm_heap_size = node['axonops']['cassandra']['heap_size']

# Cassandra 5.0 uses jvm-server.options
if node['axonops']['cassandra']['version'].start_with?('5.')
  template "#{cassandra_home}/conf/jvm-server.options" do
    source 'cassandra-jvm-server.options.erb'
    owner cassandra_user
    group cassandra_group
    mode '0644'
    variables(
      heap_size: jvm_heap_size,
    )
    notifies :restart, 'service[cassandra]', :delayed
  end
elsif node['axonops']['cassandra']['version'].start_with?('4.')
  # Cassandra 4.x uses jvm-server.options and jvm11-server.options
  template "#{cassandra_home}/conf/jvm-server.options" do
    source 'cassandra-jvm-server.options.erb'
    owner cassandra_user
    group cassandra_group
    mode '0644'
    variables(
      heap_size: jvm_heap_size,
    )
    notifies :restart, 'service[cassandra]', :delayed
  end

  template "#{cassandra_home}/conf/jvm11-server.options" do
    source 'cassandra-jvm11-server.options.erb'
    owner cassandra_user
    group cassandra_group
    mode '0644'
    notifies :restart, 'service[cassandra]', :delayed
  end
else
  # Cassandra 3.x uses jvm.options
  template "#{cassandra_home}/conf/jvm.options" do
    source 'cassandra-jvm.options.erb'
    owner cassandra_user
    group cassandra_group
    mode '0644'
    variables(
      heap_size: jvm_heap_size,
      version: node['axonops']['cassandra']['version']
    )
    notifies :restart, 'service[cassandra]', :delayed
  end
end

# Configure cassandra-env.sh
template "#{cassandra_home}/conf/cassandra-env.sh" do
  source 'cassandra-env.sh.erb'
  owner cassandra_user
  group cassandra_group
  mode '0755'
  variables(
    heap_size: node['axonops']['cassandra']['heap_size'],
    new_heap_size: node['axonops']['cassandra']['new_heap_size'],
    log_dir: node['axonops']['cassandra']['directories']['logs'],
    jmx_port: node['axonops']['cassandra']['jmx_port'],
    enable_jmx_authentication: node['axonops']['cassandra']['jmx_authentication'],
    gc_log_dir: node['axonops']['cassandra']['directories']['gc_logs']
  )
  notifies :restart, 'service[cassandra]', :delayed
end

# Configure logback.xml
template "#{cassandra_home}/conf/logback.xml" do
  source 'cassandra-logback.xml.erb'
  owner cassandra_user
  group cassandra_group
  mode '0644'
  variables(
    log_dir: node['axonops']['cassandra']['directories']['logs'],
    log_level: node['axonops']['cassandra']['log_level']
  )
  notifies :restart, 'service[cassandra]', :delayed
end

# Create rack properties file if using property file snitch
if node['axonops']['cassandra']['endpoint_snitch'].include?('PropertyFileSnitch')
  template "#{cassandra_home}/conf/cassandra-rackdc.properties" do
    source 'cassandra-rackdc.properties.erb'
    owner cassandra_user
    group cassandra_group
    mode '0644'
    variables(
      datacenter: datacenter,
      rack: rack
    )
    notifies :restart, 'service[cassandra]', :delayed
  end
end

file node['axonops']['cassandra']['jmx_password_file'] do
  content node['axonops']['cassandra']['jmx_password']
  owner 'cassandra'
  group 'cassandra'
  mode '0640'
  action :create
  only_if { node['axonops']['cassandra']['jmx_authentication'] }
end

# Create systemd service
template '/etc/systemd/system/cassandra.service' do
  source 'cassandra.service.erb'
  mode '0644'
  variables(
    cassandra_home: cassandra_home,
    cassandra_user: cassandra_user,
    cassandra_group: cassandra_group,
  )
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
  notifies :restart, 'service[cassandra]', :delayed
end

# Enable and start Cassandra service
service 'cassandra' do
  supports status: true, restart: true, reload: false
  action :enable if node['axonops']['cassandra']['start_on_boot']
  action :start
end

# Wait for Cassandra to be ready
ruby_block 'wait-for-cassandra' do
  block do
    require 'socket'
    require 'timeout'

    host = node['axonops']['cassandra']['listen_address']
    port = node['axonops']['cassandra']['native_transport_port']

    Chef::Log.info("Waiting for Cassandra to be ready on #{host}:#{port}...")

    begin
      Timeout.timeout(300) do
        loop do
          begin
            TCPSocket.new(host, port).close
            Chef::Log.info("Cassandra is ready!")
            break
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
            Chef::Log.debug("Cassandra not ready yet, retrying...")
            sleep 5
          end
        end
      end
    rescue Timeout::Error
      Chef::Log.warn("Timeout waiting for Cassandra to start")
    end
  end
  action :run
  only_if { node['axonops']['cassandra']['wait_for_start'] }
end
