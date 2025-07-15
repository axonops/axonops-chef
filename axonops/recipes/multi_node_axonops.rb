#
# Cookbook:: axonops
# Recipe:: multi_node_axonops
#
# Deploys complete AxonOps stack for multi-node testing
#

Chef::Log.info("Setting up AxonOps Server node at #{node['axonops']['multi_node']['server_ip']}")

# Common setup
include_recipe 'axonops::_common'

# Install Java for all components
include_recipe 'axonops::java'

# Install Elasticsearch for AxonOps storage
Chef::Log.info("Installing AxonOps Search (Elasticsearch) for storage...")
include_recipe 'axonops::elasticsearch'

# Install Cassandra for AxonOps data storage (internal to AxonOps)
# We'll put it in a different location to clearly separate it
Chef::Log.info("Installing Cassandra for AxonOps data storage...")
node.override['cassandra']['force_fresh_install'] = true
node.override['cassandra']['data_root'] = '/data/axonops-data'
node.override['cassandra']['cluster_name'] = 'AxonOps Data'
node.override['cassandra']['listen_address'] = node['axonops']['multi_node']['server_ip']
node.override['cassandra']['rpc_address'] = node['axonops']['multi_node']['server_ip']
node.override['cassandra']['directories']['logs'] = '/var/log/axonops-data'

# Install AxonOps Data (Cassandra for internal storage)
# The axonops_data recipe will create all necessary directories and users
include_recipe 'axonops::axonops_data'

# Configure AxonOps Server
Chef::Log.info("Installing AxonOps Server...")
node.override['axonops']['server']['listen_address'] = '0.0.0.0'
node.override['axonops']['server']['listen_port'] = 8080

# Create server config pointing to local storage
file '/etc/axonops/axon-server.yml' do
  content <<-YAML
server:
  listen_address: 0.0.0.0
  listen_port: 8080
  
storage:
  type: elasticsearch
  elasticsearch:
    hosts: ["http://localhost:9200"]
    index_prefix: axonops
  
cassandra_data:
  hosts: ["#{node['axonops']['multi_node']['server_ip']}:9042"]
  keyspace: axonops_data
  
api:
  enabled: true
  cors:
    enabled: true
    allowed_origins: ["*"]
    
auth:
  enabled: false  # For testing
  
logging:
  level: INFO
  file: /var/log/axonops/server.log
YAML
  owner 'axonops'
  group 'axonops'
  mode '0640'
  notifies :restart, 'service[axon-server]'
end

# Install server binary with realistic behavior
include_recipe 'axonops::install_axonops_server_binary'

# Create server service
file '/etc/systemd/system/axon-server.service' do
  content <<-EOU
[Unit]
Description=AxonOps Server
After=network.target axonops-search.service axonops-data.service

[Service]
Type=simple
ExecStart=/usr/bin/axon-server
User=axonops
Group=axonops
Environment="AXON_SERVER_HOST=0.0.0.0"
Environment="AXON_SERVER_PORT=8080"
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOU
  mode '0644'
  notifies :run, 'execute[systemctl-daemon-reload-server]', :immediately
end

execute 'systemctl-daemon-reload-server' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Install AxonOps Dashboard
Chef::Log.info("Installing AxonOps Dashboard...")
node.override['axonops']['dashboard']['listen_address'] = '0.0.0.0'
node.override['axonops']['dashboard']['listen_port'] = 3000

file '/etc/axonops/axon-dash.yml' do
  content <<-YAML
dashboard:
  listen_address: 0.0.0.0
  listen_port: 3000
  server_endpoint: http://localhost:8080
  
ui:
  title: "AxonOps Multi-Node Test"
  refresh_interval: 5000
  
logging:
  level: INFO
  file: /var/log/axonops/dashboard.log
YAML
  owner 'axonops'
  group 'axonops'
  mode '0640'
  notifies :restart, 'service[axon-dash]'
end

# Install dashboard binary with realistic behavior
include_recipe 'axonops::install_axonops_dashboard_binary'

# Create dashboard service
file '/etc/systemd/system/axon-dash.service' do
  content <<-EOU
[Unit]
Description=AxonOps Dashboard
After=network.target axon-server.service

[Service]
Type=simple
ExecStart=/usr/bin/axon-dash
User=axonops
Group=axonops
Environment="AXON_DASH_HOST=0.0.0.0"
Environment="AXON_DASH_PORT=3000"
Environment="AXON_DASH_API_ENDPOINT=http://localhost:8080"
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOU
  mode '0644'
  notifies :run, 'execute[systemctl-daemon-reload-dash]', :immediately
end

execute 'systemctl-daemon-reload-dash' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Start all services
service 'axonops-search' do
  action [:enable, :start]
end

service 'axonops-data' do
  action [:enable, :start]
end

service 'axon-server' do
  action [:enable, :start]
end

service 'axon-dash' do
  action [:enable, :start]
end

# Log success
Chef::Log.info("AxonOps Server stack deployed successfully!")
Chef::Log.info("Dashboard will be available at http://#{node['axonops']['multi_node']['server_ip']}:3000")
Chef::Log.info("API endpoint: http://#{node['axonops']['multi_node']['server_ip']}:8080")