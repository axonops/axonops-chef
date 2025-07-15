#
# Cookbook:: axonops
# Recipe:: test_real_packages
#
# Test recipe for real AxonOps packages
#

# Set up for offline installation with real packages
node.override['axonops']['offline_install'] = true
node.override['axonops']['offline_packages_dir'] = '/vagrant/offline_packages'
node.override['axonops']['offline_packages_path'] = '/vagrant/offline_packages'
node.override['axonops']['deployment_mode'] = 'self-hosted'

# Enable all components
node.override['axonops']['server']['enabled'] = true
node.override['axonops']['dashboard']['enabled'] = true
node.override['axonops']['agent']['enabled'] = true
node.override['axonops']['agent']['java_agent']['enabled'] = true

# Common setup
include_recipe 'axonops::_common'

# Install Java first (required by all components)
include_recipe 'axonops::java'

# Install Elasticsearch for AxonOps storage
include_recipe 'axonops::elasticsearch'

# Install the real AxonOps packages
include_recipe 'axonops::install_real_axonops_packages'

# Configure AxonOps Server
template '/etc/axonops/axon-server.yml' do
  source 'axon-server.yml.erb'
  owner 'axonops'
  group 'axonops'
  mode '0640'
  variables(
    deployment_mode: 'self-hosted',
    listen_address: '0.0.0.0',
    listen_port: 8080,
    elasticsearch_url: 'http://localhost:9200',
    cassandra_hosts: ['localhost:9042']
  )
  notifies :restart, 'service[axon-server]', :delayed
end

# Configure AxonOps Dashboard
template '/etc/axonops/axon-dash.yml' do
  source 'axon-dash.yml.erb'
  owner 'axonops'
  group 'axonops'
  mode '0640'
  variables(
    listen_address: '0.0.0.0',
    listen_port: 3000,
    server_endpoint: 'http://localhost:8080'
  )
  notifies :restart, 'service[axon-dash]', :delayed
end

# Configure AxonOps Agent
template '/etc/axonops/axon-agent.yml' do
  source 'axon-agent.yml.erb'
  owner 'axonops'
  group 'axonops'
  mode '0640'
  variables(
    agent_name: node['hostname'],
    server_hosts: ['localhost:8080'],
    cassandra_hosts: ['localhost:9042'],
    monitoring_interval: 60
  )
  notifies :restart, 'service[axon-agent]', :delayed
end

# Skip the regular agent installation since we'll use install_real_axonops_packages
node.override['axonops']['agent']['enabled'] = false

# Install Cassandra for testing (without agent)
include_recipe 'axonops::install_cassandra_tarball'
include_recipe 'axonops::configure_cassandra'

# Now re-enable agent and install with real packages
node.override['axonops']['agent']['enabled'] = true

# Log summary
log 'real_packages_test' do
  message <<-MSG
  
  AxonOps Real Packages Test Deployment
  =====================================
  
  Components:
  - AxonOps Server: http://#{node['ipaddress']}:8080
  - AxonOps Dashboard: http://#{node['ipaddress']}:3000
  - AxonOps Agent: Monitoring local Cassandra
  - Elasticsearch: http://localhost:9200
  - Cassandra: localhost:9042
  
  Services:
  - axon-server.service
  - axon-dash.service
  - axon-agent.service
  - elasticsearch.service
  - cassandra.service
  
  Configuration:
  - /etc/axonops/axon-server.yml
  - /etc/axonops/axon-dash.yml
  - /etc/axonops/axon-agent.yml
  
  Next Steps:
  1. Access dashboard at http://#{node['ipaddress']}:3000
  2. Check agent registration in the UI
  3. Monitor Cassandra metrics
  
  MSG
  level :info
end