#
# Cookbook:: axonops
# Recipe:: cassandra_app
#
# Minimal Cassandra installation for testing multi-node deployment
#

# WARNING - Fresh install only
Chef::Log.warn('='*80)
Chef::Log.warn('WARNING: This recipe is for FRESH INSTALLATIONS ONLY!')
Chef::Log.warn('DO NOT use this recipe to upgrade existing Cassandra installations!')
Chef::Log.warn('='*80)

# Install Java
include_recipe 'axonops::java'

# Create cassandra user and group
group 'cassandra' do
  system true
end

user 'cassandra' do
  group 'cassandra'
  system true
  shell '/bin/false'
  home '/var/lib/cassandra'
  manage_home false
end

# Create directories
%w[
  /etc/cassandra
  /var/lib/cassandra
  /var/log/cassandra
  /var/lib/cassandra/data
  /var/lib/cassandra/commitlog
  /var/lib/cassandra/saved_caches
  /var/lib/cassandra/hints
].each do |dir|
  directory dir do
    owner 'cassandra'
    group 'cassandra'
    mode '0755'
    recursive true
  end
end

# For testing, create mock cassandra binary
file '/usr/bin/cassandra' do
  content <<-BASH
#!/bin/bash
echo "Apache Cassandra 5.0.4 starting..."
echo "Cluster: #{node['cassandra']['cluster_name']}"
echo "Listen address: #{node['cassandra']['listen_address']}"
# In real implementation, this would be the actual cassandra binary
while true; do sleep 3600; done
BASH
  mode '0755'
end

# Create nodetool mock
file '/usr/bin/nodetool' do
  content <<-BASH
#!/bin/bash
if [ "$1" = "status" ]; then
  echo "Datacenter: datacenter1"
  echo "==========="
  echo "Status=Up/Down"
  echo "|/ State=Normal/Leaving/Joining/Moving"
  echo "--  Address           Load       Tokens  Owns    Host ID                               Rack"
  echo "UN  #{node['cassandra']['listen_address']}  100 KB     16      100.0%  550e8400-e29b-41d4-a716-446655440000  rack1"
else
  echo "nodetool $@"
fi
BASH
  mode '0755'
end

# Create cqlsh mock
file '/usr/bin/cqlsh' do
  content <<-BASH
#!/bin/bash
echo "Connected to #{node['cassandra']['cluster_name']} at #{node['cassandra']['listen_address']}:9042"
echo "[cqlsh 6.1.0 | Cassandra 5.0.4 | CQL spec 3.4.7 | Native protocol v5]"
echo "Use HELP for help."
if [ -n "$2" ]; then
  echo "Executing: $2"
  echo "OK"
fi
BASH
  mode '0755'
end

# Create config
file '/etc/cassandra/cassandra.yaml' do
  content <<-YAML
cluster_name: '#{node['cassandra']['cluster_name']}'
num_tokens: 16
allocate_tokens_for_local_replication_factor: 3
hinted_handoff_enabled: true
authenticator: AllowAllAuthenticator
authorizer: AllowAllAuthorizer
partitioner: org.apache.cassandra.dht.Murmur3Partitioner
data_file_directories:
  - /var/lib/cassandra/data
commitlog_directory: /var/lib/cassandra/commitlog
saved_caches_directory: /var/lib/cassandra/saved_caches
hints_directory: /var/lib/cassandra/hints
seed_provider:
  - class_name: org.apache.cassandra.locator.SimpleSeedProvider
    parameters:
      - seeds: "#{node['cassandra']['seeds'].join(',')}"
listen_address: #{node['cassandra']['listen_address']}
rpc_address: #{node['cassandra']['rpc_address']}
native_transport_port: 9042
storage_port: 7000
ssl_storage_port: 7001
endpoint_snitch: SimpleSnitch
YAML
  owner 'cassandra'
  group 'cassandra'
  mode '0644'
end

# Create JVM options for JMX
directory '/etc/cassandra/conf.d' do
  owner 'cassandra'
  group 'cassandra'
  mode '0755'
end

# Create systemd service
file '/etc/systemd/system/cassandra.service' do
  content <<-EOH
[Unit]
Description=Apache Cassandra 5.0
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/cassandra
User=cassandra
Group=cassandra
StandardOutput=journal
StandardError=journal
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOH
  mode '0644'
  notifies :run, 'execute[systemctl-daemon-reload-cassandra-app]', :immediately
end

execute 'systemctl-daemon-reload-cassandra-app' do
  command 'systemctl daemon-reload'
  action :nothing
end

service 'cassandra' do
  supports status: true, restart: true
  action [:enable, :start]
end

log 'cassandra-app-complete' do
  message 'Apache Cassandra 5.0 (test) installation completed'
  level :info
end