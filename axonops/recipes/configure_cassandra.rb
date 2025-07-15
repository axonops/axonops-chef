#
# Cookbook:: axonops
# Recipe:: configure_cassandra
#
# Configures Apache Cassandra
#

# Get configuration
cassandra_user = node['cassandra']['user']
cassandra_group = node['cassandra']['group']
cassandra_home = "#{node['cassandra']['install_dir']}/cassandra"
data_root = node['cassandra']['data_root']

# Ensure configuration directory exists
directory "#{cassandra_home}/conf" do
  owner cassandra_user
  group cassandra_group
  mode '0755'
end

# Main cassandra.yaml configuration
template "#{cassandra_home}/conf/cassandra.yaml" do
  source 'cassandra.yaml.erb'
  owner cassandra_user
  group cassandra_group
  mode '0644'
  variables(
    cluster_name: node['cassandra']['cluster_name'],
    num_tokens: node['cassandra']['num_tokens'],
    data_file_directories: ["#{data_root}/data"],
    commitlog_directory: "#{data_root}/commitlog",
    saved_caches_directory: "#{data_root}/saved_caches",
    hints_directory: "#{data_root}/hints",
    cdc_raw_directory: "#{data_root}/cdc_raw",
    seeds: node['cassandra']['seeds'].join(','),
    listen_address: node['cassandra']['listen_address'],
    rpc_address: node['cassandra']['rpc_address'],
    broadcast_address: node['cassandra']['broadcast_address'],
    broadcast_rpc_address: node['cassandra']['broadcast_rpc_address'],
    native_transport_port: node['cassandra']['native_transport_port'],
    storage_port: node['cassandra']['storage_port'],
    ssl_storage_port: node['cassandra']['ssl_storage_port'],
    endpoint_snitch: node['cassandra']['endpoint_snitch'],
    authenticator: node['cassandra']['authenticator'],
    authorizer: node['cassandra']['authorizer'],
    concurrent_reads: node['cassandra']['concurrent_reads'],
    concurrent_writes: node['cassandra']['concurrent_writes'],
    concurrent_counter_writes: node['cassandra']['concurrent_counter_writes'],
    concurrent_materialized_view_writes: node['cassandra']['concurrent_materialized_view_writes'],
    disk_optimization_strategy: node['cassandra']['disk_optimization_strategy'],
    memtable_allocation_type: node['cassandra']['memtable_allocation_type'],
    memtable_cleanup_threshold: node['cassandra']['memtable_cleanup_threshold'],
    memtable_flush_writers: node['cassandra']['memtable_flush_writers'],
    compaction_throughput_mb_per_sec: node['cassandra']['compaction_throughput_mb_per_sec'],
    stream_throughput_outbound_megabits_per_sec: node['cassandra']['stream_throughput_outbound_megabits_per_sec'],
    inter_dc_stream_throughput_outbound_megabits_per_sec: node['cassandra']['inter_dc_stream_throughput_outbound_megabits_per_sec']
  )
  notifies :restart, 'service[cassandra]', :delayed
end

# JVM options configuration
jvm_heap_size = node['cassandra']['jvm']['heap_size']
jvm_new_size = node['cassandra']['jvm']['new_size']

# Cassandra 5.0 uses jvm-server.options
if node['cassandra']['version'].start_with?('5.')
  template "#{cassandra_home}/conf/jvm-server.options" do
    source 'cassandra-jvm-server.options.erb'
    owner cassandra_user
    group cassandra_group
    mode '0644'
    variables(
      heap_size: jvm_heap_size,
      new_size: jvm_new_size
    )
    notifies :restart, 'service[cassandra]', :delayed
  end
elsif node['cassandra']['version'].start_with?('4.')
  # Cassandra 4.x uses jvm-server.options and jvm11-server.options
  template "#{cassandra_home}/conf/jvm-server.options" do
    source 'cassandra-jvm-server.options.erb'
    owner cassandra_user
    group cassandra_group
    mode '0644'
    variables(
      heap_size: jvm_heap_size,
      new_size: jvm_new_size
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
      new_size: jvm_new_size,
      version: node['cassandra']['version']
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
    heap_size: node['cassandra']['heap_size'],
    new_heap_size: node['cassandra']['new_heap_size'],
    log_dir: node['cassandra']['directories']['logs'],
    jmx_port: node['cassandra']['jmx_port'],
    enable_jmx_authentication: node['cassandra']['jmx_authentication'],
    gc_log_dir: node['cassandra']['directories']['gc_logs']
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
    log_dir: node['cassandra']['directories']['logs'],
    log_level: node['cassandra']['log_level']
  )
  notifies :restart, 'service[cassandra]', :delayed
end

# Create rack properties file if using property file snitch
if node['cassandra']['endpoint_snitch'].include?('PropertyFileSnitch')
  template "#{cassandra_home}/conf/cassandra-rackdc.properties" do
    source 'cassandra-rackdc.properties.erb'
    owner cassandra_user
    group cassandra_group
    mode '0644'
    variables(
      datacenter: node['cassandra']['datacenter'],
      rack: node['cassandra']['rack']
    )
    notifies :restart, 'service[cassandra]', :delayed
  end
end

# Enable and start Cassandra service
service 'cassandra' do
  supports status: true, restart: true, reload: false
  action [:enable, :start]
end

# Wait for Cassandra to be ready
ruby_block 'wait-for-cassandra' do
  block do
    require 'socket'
    require 'timeout'
    
    host = node['cassandra']['listen_address']
    port = node['cassandra']['native_transport_port']
    
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
  only_if { node['cassandra']['wait_for_start'] }
end