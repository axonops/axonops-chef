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

# Determine the Cassandra series and whether it uses the legacy (3.11)
# cassandra.yaml schema. Cassandra 3.11 uses integer *_in_ms / *_in_mb keys,
# Thrift/RPC keys and megabit streaming throughput, rendered from a dedicated
# templates/default/3.11/cassandra.yaml.erb. 4.1/5.0 use the modern schema.
cassandra_version = node['axonops']['cassandra']['version']

# Use server attributes if defined, otherwise use cassandra attributes
cluster_name = node['axonops']['server']['cassandra']['cluster_name'] || node['axonops']['cassandra']['cluster_name']
datacenter = node['axonops']['server']['cassandra']['dc'] || node['axonops']['cassandra']['dc']
rack = node['axonops']['server']['cassandra']['rack'] || node['axonops']['cassandra']['rack']

cassandra_conf_dir = node['axonops']['cassandra']['conf_dir'] || "#{cassandra_home}/conf"

# Ensure configuration directory exists
directory cassandra_conf_dir do
  owner cassandra_user
  group cassandra_group
  mode '0755'
end

if node['axonops']['cassandra']['ssl']['self_signed']
  include_recipe 'axonops::cassandra_self_signed'
end

template "#{cassandra_conf_dir}/cassandra.yaml" do
  source "#{AxonOpsCassandra.template_dir(cassandra_version)}/cassandra.yaml.erb"
  owner cassandra_user
  group cassandra_group
  mode '0644'
  
  template_vars = node['axonops']['cassandra'].to_h.dup
  template_vars['cluster_name'] = cluster_name
  template_vars['dc'] = datacenter
  template_vars['rack'] = rack
  template_vars['data_file_directories'] = ["#{data_root}/data"]
  template_vars['commitlog_directory'] = "#{data_root}/commitlog"
  template_vars['saved_caches_directory'] = "#{data_root}/saved_caches"
  template_vars['hints_directory'] = "#{data_root}/hints"
  template_vars['cdc_raw_directory'] = "#{data_root}/cdc_raw"
  template_vars['seeds'] = node['axonops']['cassandra']['seeds'].join(',')
  template_vars['cassandra_version'] = cassandra_version
  
  variables(template_vars)
  notifies(node['axonops']['cassandra']['start_on_install'] ? :restart : :nothing, 'service[cassandra]', :delayed)
end

# JVM options configuration
jvm_heap_size = node['axonops']['cassandra']['heap_size']
if jvm_heap_size.nil? || jvm_heap_size.empty?
  # node['memory']['total'] is in KB.
  # Convert KB to GB by dividing by (1024 * 1024)
  total_memory_gb = node['memory']['total'].to_i / (1024 * 1024)

  # Calculate 1/3 of the total memory.
  calculated_heap_gb = total_memory_gb / 3

  # Set the heap size with a maximum of 30G.
  jvm_heap_size = if calculated_heap_gb > 30
                    '30G'
                  else
                    "#{calculated_heap_gb}G"
                  end
end

# Cassandra 5.0 uses jvm-server.options
if node['axonops']['cassandra']['version'].start_with?('5.')
  template "#{cassandra_conf_dir}/jvm-server.options" do
    source 'cassandra-jvm-server.options.erb'
    owner cassandra_user
    group cassandra_group
    mode '0644'
    variables(
      heap_size: jvm_heap_size
    )
    notifies(node['axonops']['cassandra']['start_on_install'] ? :restart : :nothing, 'service[cassandra]', :delayed)
  end
  template "#{cassandra_conf_dir}/jvm17-server.options" do
    source 'cassandra-jvm17-server.options.erb'
    owner cassandra_user
    group cassandra_group
    mode '0644'
    notifies(node['axonops']['cassandra']['start_on_install'] ? :restart : :nothing, 'service[cassandra]', :delayed)
  end
elsif node['axonops']['cassandra']['version'].start_with?('4.')
  # Cassandra 4.x uses jvm-server.options and jvm11-server.options
  template "#{cassandra_conf_dir}/jvm-server.options" do
    source 'cassandra-jvm-server.options.erb'
    owner cassandra_user
    group cassandra_group
    mode '0644'
    variables(
      heap_size: jvm_heap_size
    )
    notifies(node['axonops']['cassandra']['start_on_install'] ? :restart : :nothing, 'service[cassandra]', :delayed)
  end

  template "#{cassandra_conf_dir}/jvm11-server.options" do
    source 'cassandra-jvm11-server.options.erb'
    owner cassandra_user
    group cassandra_group
    mode '0644'
    notifies(node['axonops']['cassandra']['start_on_install'] ? :restart : :nothing, 'service[cassandra]', :delayed)
  end
else
  # Cassandra 3.x uses jvm.options
  template "#{cassandra_conf_dir}/jvm.options" do
    source 'cassandra-jvm.options.erb'
    owner cassandra_user
    group cassandra_group
    mode '0644'
    variables(
      heap_size: jvm_heap_size,
      version: node['axonops']['cassandra']['version']
    )
    notifies(node['axonops']['cassandra']['start_on_install'] ? :restart : :nothing, 'service[cassandra]', :delayed)
  end
end

# Configure cassandra-env.sh
template "#{cassandra_conf_dir}/cassandra-env.sh" do
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
    gc_log_dir: node['axonops']['cassandra']['directories']['gc_logs'],
    java_major: AxonOpsCassandra.java_major(cassandra_version),
    jemalloc_path: node.run_state['cassandra_jemalloc_path'],
    axon_java_agent_jar: if node['axonops']['agent']['enabled'] && node['axonops']['cassandra']['edition'] != 'dse'
                            AxonOpsCassandra.java_agent_package(cassandra_version)
                          end
  )
  notifies(node['axonops']['cassandra']['start_on_install'] ? :restart : :nothing, 'service[cassandra]', :delayed)
end

# Configure logback.xml
template "#{cassandra_conf_dir}/logback.xml" do
  source 'cassandra-logback.xml.erb'
  owner cassandra_user
  group cassandra_group
  mode '0644'
  variables(
    log_dir: node['axonops']['cassandra']['directories']['logs'],
    log_level: node['axonops']['cassandra']['log_level']
  )
  notifies(node['axonops']['cassandra']['start_on_install'] ? :restart : :nothing, 'service[cassandra]', :delayed)
end

# Create rack properties file if using property file snitch
if node['axonops']['cassandra']['endpoint_snitch'].include?('PropertyFileSnitch')
  template "#{cassandra_conf_dir}/cassandra-rackdc.properties" do
    source 'cassandra-rackdc.properties.erb'
    owner cassandra_user
    group cassandra_group
    mode '0644'
    variables(
      datacenter: datacenter,
      rack: rack
    )
    notifies(node['axonops']['cassandra']['start_on_install'] ? :restart : :nothing, 'service[cassandra]', :delayed)
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

# Create systemd service. Tar installs only — recipes/cassandra.rb's own
# systemd_unit resource used to duplicate this (same path, different
# content, whichever ran last won), and for pkg installs the package's own
# init/systemd integration is authoritative; writing a unit here would
# shadow it with the wrong ExecStart/paths.
if node['axonops']['cassandra']['install_format'] == 'tar'
  template '/etc/systemd/system/cassandra.service' do
    source 'cassandra.service.erb'
    mode '0644'
    variables(
      cassandra_home: cassandra_home,
      cassandra_user: cassandra_user,
      cassandra_group: cassandra_group,
      cassandra_log_dir: node['axonops']['cassandra']['log_dir']
    )
    notifies :run, 'execute[systemctl-daemon-reload]', :immediately
    notifies(node['axonops']['cassandra']['start_on_install'] ? :restart : :nothing, 'service[cassandra]', :delayed)
  end
end

# Enable and, unless start_on_install is disabled, start Cassandra service
service 'cassandra' do
  supports status: true, restart: true, reload: false
  action :enable if node['axonops']['cassandra']['start_on_boot']
  action :start if node['axonops']['cassandra']['start_on_install']
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
            Chef::Log.info('Cassandra is ready!')
            break
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
            Chef::Log.debug('Cassandra not ready yet, retrying...')
            sleep 5
          end
        end
      end
    rescue Timeout::Error
      Chef::Log.warn('Timeout waiting for Cassandra to start')
    end
  end
  action :run
  only_if do
    node['axonops']['cassandra']['wait_for_start'] &&
      node['axonops']['cassandra']['start_on_install']
  end
end
