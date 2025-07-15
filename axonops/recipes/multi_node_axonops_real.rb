#
# Cookbook:: axonops
# Recipe:: multi_node_axonops_real
#
# Deploys complete AxonOps stack using REAL packages for multi-node testing
#

Chef::Log.info("Setting up AxonOps Server node with REAL packages at #{node['axonops']['multi_node']['server_ip']}")

# Set up for offline installation with real packages
node.override['axonops']['offline_install'] = true
node.override['axonops']['offline_packages_dir'] = '/vagrant/offline_packages'

# Common setup
include_recipe 'axonops::_common'

# Install Java for all components
include_recipe 'axonops::java'

# Install Elasticsearch for AxonOps storage
Chef::Log.info("Installing Elasticsearch for AxonOps storage...")
include_recipe 'axonops::elasticsearch'

# Install Cassandra for AxonOps data storage (internal to AxonOps)
Chef::Log.info("Installing Cassandra for AxonOps data storage...")
node.override['cassandra']['force_fresh_install'] = true
node.override['cassandra']['data_root'] = '/data/axonops-data'
node.override['cassandra']['cluster_name'] = 'AxonOps Data'
node.override['cassandra']['listen_address'] = node['axonops']['multi_node']['server_ip']
node.override['cassandra']['rpc_address'] = node['axonops']['multi_node']['server_ip']
node.override['cassandra']['directories']['logs'] = '/var/log/axonops-data'

include_recipe 'axonops::axonops_data'

# Update apt cache for dependencies
execute 'apt-update' do
  command 'apt-get update'
  action :run
end

# Install dependencies
package %w[adduser procps python3] do
  action :install
end

# Install real AxonOps Server package
server_deb = Dir.glob("#{node['axonops']['offline_packages_dir']}/axon-server_*.deb").first
if server_deb
  Chef::Log.info("Installing real AxonOps Server from #{server_deb}")
  
  # Use architecture forcing for cross-platform testing
  execute 'install-axon-server' do
    command "dpkg --force-architecture --force-depends -i #{server_deb}"
    action :run
    not_if "dpkg -l | grep -q '^ii  axon-server '"
  end
  
  # Configure AxonOps Server
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
  
  service 'axon-server' do
    action [:enable, :start]
  end
else
  Chef::Log.error("axon-server package not found in #{node['axonops']['offline_packages_dir']}")
end

# Install real AxonOps Dashboard package
dash_deb = Dir.glob("#{node['axonops']['offline_packages_dir']}/axon-dash_*.deb").first
if dash_deb
  Chef::Log.info("Installing real AxonOps Dashboard from #{dash_deb}")
  
  # Fix broken packages and install dependencies
  execute 'fix-broken-packages' do
    command 'apt --fix-broken install -y || true'
    action :run
  end
  
  execute 'install-axon-dash' do
    command "dpkg --force-architecture --force-depends -i #{dash_deb}"
    action :run
    not_if "dpkg -l | grep -q '^ii  axon-dash '"
  end
  
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
  
  service 'axon-dash' do
    action [:enable, :start]
  end
else
  Chef::Log.error("axon-dash package not found in #{node['axonops']['offline_packages_dir']}")
end

# Log success
log 'axonops-server-info' do
  message <<-MSG
  
  AxonOps Server stack deployed with REAL packages!
  ==================================================
  
  Components installed:
  - Elasticsearch: http://localhost:9200
  - Cassandra (AxonOps Data): #{node['axonops']['multi_node']['server_ip']}:9042
  - AxonOps Server: http://#{node['axonops']['multi_node']['server_ip']}:8080
  - AxonOps Dashboard: http://#{node['axonops']['multi_node']['server_ip']}:3000
  
  Note: Services may fail to start on ARM64 with AMD64 binaries.
  Check logs in /var/log/axonops/ for details.
  
  MSG
  level :info
end