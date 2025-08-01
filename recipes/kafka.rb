#
# Cookbook:: axonops
# Recipe:: kafka
#
# Installs Apache Kafka from tarball
#

# Install Java first
include_recipe 'axonops::common'
include_recipe 'axonops::java'

# Define installation paths
kafka_version = node['axonops']['kafka']['version']
scala_version = node['axonops']['kafka']['scala_version']
kafka_install_dir = node['axonops']['kafka']['install_dir']
kafka_install_dir_versioned = "#{kafka_install_dir}-#{kafka_version}"
kafka_data_dir = node['axonops']['kafka']['data_dir']
kafka_log_dir = node['axonops']['kafka']['log_dir']
kafka_tmp_dir = node['axonops']['kafka']['tmp_dir']
kafka_user = node['axonops']['kafka']['user']
kafka_group = node['axonops']['kafka']['group']

# Create kafka user and group
group kafka_group do
  system true
  action :create
end

user kafka_user do
  group kafka_group
  system true
  shell '/bin/bash'
  home node['axonops']['kafka']['user_home']
  manage_home true
  action :create
end

# Set file descriptor limits
file '/etc/security/limits.d/kafka.conf' do
  content <<-EOF
#{kafka_user} soft nofile #{node['axonops']['kafka']['max_open_files']}
#{kafka_user} hard nofile #{node['axonops']['kafka']['max_open_files']}
#{kafka_user} soft nproc 65536
#{kafka_user} hard nproc 65536
  EOF
  mode '0644'
end

# Create required directories
[
  kafka_install_dir_versioned,
  kafka_data_dir,
  kafka_log_dir,
  kafka_tmp_dir,
  "#{kafka_install_dir}/ssl",
  node['axonops']['kafka']['connect']['plugin_path']
].each do |dir|
  directory dir do
    owner kafka_user
    group kafka_group
    mode '0755'
    recursive true
  end
end

# Download or copy Kafka tarball
if node['axonops']['offline_install']
  # Offline installation
  tarball_name = node['axonops']['packages']['kafka_tarball'] || "kafka_#{scala_version}-#{kafka_version}.tgz"
  tarball_path = ::File.join(node['axonops']['offline_packages_path'], tarball_name)

  unless ::File.exist?(tarball_path)
    raise("Offline Kafka tarball not found: #{tarball_path}")
  end

  tarball_source = tarball_path
else
  # Online installation
  tarball_url = node['axonops']['kafka']['tarball_url'] || "#{node['axonops']['kafka']['apache_mirror']}/kafka/#{kafka_version}/kafka_#{scala_version}-#{kafka_version}.tgz"
  
  remote_file "/tmp/kafka_#{scala_version}-#{kafka_version}.tgz" do
    source tarball_url
    checksum node['axonops']['kafka']['tarball_checksum'] if node['axonops']['kafka']['tarball_checksum']
    owner 'root'
    group 'root'
    mode '0644'
    action :create
  end

  tarball_source = "/tmp/kafka_#{scala_version}-#{kafka_version}.tgz"
end

execute 'extract-kafka-tarball' do
  command "tar -xzf #{tarball_source} -C #{kafka_install_dir_versioned} --strip-components=1"
  creates "#{kafka_install_dir_versioned}/bin/kafka-server-start.sh"
  not_if { ::File.exist?("#{kafka_install_dir_versioned}/bin/kafka-server-start.sh") }
end

link kafka_install_dir do
  to kafka_install_dir_versioned
  action :create
end

# Fix ownership after extraction
execute "fix-kafka-permissions" do
  command "chown -R #{kafka_user}:#{kafka_group} #{kafka_install_dir_versioned}"
  action :run
  only_if { ::File.exist?(kafka_install_dir_versioned) }
end

# Configure Kafka server.properties
template "#{kafka_install_dir}/config/server.properties" do
  source 'kafka-server.properties.erb'
  owner kafka_user
  group kafka_group
  mode '0640'
  variables(
    broker_id: node['axonops']['kafka']['broker_id'],
    port: node['axonops']['kafka']['port'],
    advertised_hostname: node['axonops']['kafka']['advertised_hostname'],
    listeners: node['axonops']['kafka']['listeners'],
    advertised_listeners: node['axonops']['kafka']['advertised_listeners'],
    listener_security_protocol_map: node['axonops']['kafka']['listener_security_protocol_map'],
    log_dirs: kafka_data_dir,
    num_network_threads: node['axonops']['kafka']['num_network_threads'],
    num_io_threads: node['axonops']['kafka']['num_io_threads'],
    socket_send_buffer_bytes: node['axonops']['kafka']['socket_send_buffer_bytes'],
    socket_receive_buffer_bytes: node['axonops']['kafka']['socket_receive_buffer_bytes'],
    socket_request_max_bytes: node['axonops']['kafka']['socket_request_max_bytes'],
    log_retention_hours: node['axonops']['kafka']['log_retention_hours'],
    log_segment_bytes: node['axonops']['kafka']['log_segment_bytes'],
    log_retention_check_interval_ms: node['axonops']['kafka']['log_retention_check_interval_ms'],
    zookeeper_connect: node['axonops']['kafka']['zookeeper_connect'],
    zookeeper_connection_timeout_ms: node['axonops']['kafka']['zookeeper_connection_timeout_ms'],
    num_partitions: node['axonops']['kafka']['num_partitions'],
    default_replication_factor: node['axonops']['kafka']['default_replication_factor'],
    min_insync_replicas: node['axonops']['kafka']['min_insync_replicas'],
    auto_create_topics_enable: node['axonops']['kafka']['auto_create_topics_enable'],
    delete_topic_enable: node['axonops']['kafka']['delete_topic_enable'],
    rack: node['axonops']['kafka']['rack'],
    kraft_mode: node['axonops']['kafka']['kraft_mode'],
    node_id: node['axonops']['kafka']['node_id'],
    controller_quorum_voters: node['axonops']['kafka']['controller_quorum_voters'],
    process_roles: node['axonops']['kafka']['process_roles'],
    ssl_enabled: node['axonops']['kafka']['ssl']['enabled'],
    ssl_keystore_location: node['axonops']['kafka']['ssl']['keystore_location'],
    ssl_keystore_password: node['axonops']['kafka']['ssl']['keystore_password'],
    ssl_key_password: node['axonops']['kafka']['ssl']['key_password'],
    ssl_truststore_location: node['axonops']['kafka']['ssl']['truststore_location'],
    ssl_truststore_password: node['axonops']['kafka']['ssl']['truststore_password'],
    ssl_client_auth: node['axonops']['kafka']['ssl']['client_auth'],
    ssl_enabled_protocols: node['axonops']['kafka']['ssl']['enabled_protocols'],
    sasl_enabled: node['axonops']['kafka']['sasl']['enabled'],
    sasl_mechanism: node['axonops']['kafka']['sasl']['mechanism'],
    sasl_interbroker_protocol: node['axonops']['kafka']['sasl']['interbroker_protocol']
  )
  notifies :restart, 'service[kafka]', :delayed
end

# Configure log4j.properties
template "#{kafka_install_dir}/config/log4j.properties" do
  source 'kafka-log4j.properties.erb'
  owner kafka_user
  group kafka_group
  mode '0640'
  variables(
    log_dir: kafka_log_dir,
    log_level: 'INFO'
  )
  notifies :restart, 'service[kafka]', :delayed
end

# Configure KRaft mode if enabled
if node['axonops']['kafka']['kraft_mode']
  # Generate cluster UUID for KRaft mode
  execute 'generate-kafka-cluster-uuid' do
    command "#{kafka_install_dir}/bin/kafka-storage.sh random-uuid > #{kafka_install_dir}/cluster.uuid"
    creates "#{kafka_install_dir}/cluster.uuid"
    user kafka_user
    group kafka_group
  end

  # Format storage for KRaft mode
  execute 'format-kafka-storage' do
    command "#{kafka_install_dir}/bin/kafka-storage.sh format -t $(cat #{kafka_install_dir}/cluster.uuid) -c #{kafka_install_dir}/config/server.properties"
    user kafka_user
    group kafka_group
    not_if { ::File.exist?("#{kafka_data_dir}/meta.properties") }
  end
end

# Set JAVA_HOME based on platform
if node['java']['install_from_package'] == false || node['axonops']['offline_install']
  java_home = node['java']['java_home']
elsif node['java']['zulu']
  java_home = node['java']['zulu_home'] || '/usr/lib/jvm/zulu-17-amd64'
else
  java_home = node['java']['openjdk_home'] || '/usr/lib/jvm/jre'
end

# Create systemd service
template '/etc/systemd/system/kafka.service' do
  source 'kafka.service.erb'
  mode '0644'
  variables(
    java_home: java_home,
    kafka_install_dir: kafka_install_dir,
    kafka_user: kafka_user,
    kafka_group: kafka_group,
    kafka_heap_size: node['axonops']['kafka']['heap_size'],
    kafka_jvm_performance_opts: node['axonops']['kafka']['jvm_performance_opts'],
    kafka_log_dir: kafka_log_dir,
    kafka_tmp_dir: kafka_tmp_dir
  )
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
  notifies :restart, 'service[kafka]', :delayed
end

# Reload systemd
execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Enable and start Kafka
service 'kafka' do
  service_name node['axonops']['kafka']['service_name']
  supports status: true, restart: true
  action [:enable, :start] if node['axonops']['kafka']['autostart']
end

# Wait for Kafka to be ready
ruby_block 'wait-for-kafka' do
  block do
    require 'socket'
    require 'timeout'
    
    retries = 30
    port = node['axonops']['kafka']['port']
    
    retries.times do
      begin
        Timeout::timeout(2) do
          s = TCPSocket.new('localhost', port)
          s.close
          break
        end
      rescue Errno::ECONNREFUSED, Timeout::Error
        sleep 2
      end
    end
  end
  action :run
  only_if { node['axonops']['kafka']['autostart'] }
end

# Configure Kafka Connect if enabled
if node['axonops']['kafka']['connect']['enabled']
  template "#{kafka_install_dir}/config/connect-distributed.properties" do
    source 'kafka-connect-distributed.properties.erb'
    owner kafka_user
    group kafka_group
    mode '0640'
    variables(
      bootstrap_servers: "localhost:#{node['axonops']['kafka']['port']}",
      group_id: node['axonops']['kafka']['connect']['group_id'],
      offset_storage_topic: node['axonops']['kafka']['connect']['offset_storage_topic'],
      config_storage_topic: node['axonops']['kafka']['connect']['config_storage_topic'],
      status_storage_topic: node['axonops']['kafka']['connect']['status_storage_topic'],
      plugin_path: node['axonops']['kafka']['connect']['plugin_path'],
      rest_port: node['axonops']['kafka']['connect']['port']
    )
  end

  # Create Connect service
  template '/etc/systemd/system/kafka-connect.service' do
    source 'kafka-connect.service.erb'
    mode '0644'
    variables(
      java_home: java_home,
      kafka_install_dir: kafka_install_dir,
      kafka_user: kafka_user,
      kafka_group: kafka_group,
      kafka_heap_size: node['axonops']['kafka']['heap_size'],
      kafka_log_dir: kafka_log_dir
    )
    notifies :run, 'execute[systemctl-daemon-reload]', :immediately
  end

  service 'kafka-connect' do
    supports status: true, restart: true
    action [:enable, :start] if node['axonops']['kafka']['autostart']
  end
end