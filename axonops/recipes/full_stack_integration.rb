#
# Cookbook:: axonops
# Recipe:: full_stack_integration
#
# Deploys complete AxonOps stack with real components for integration testing
#

Chef::Log.info("Deploying full AxonOps stack for integration testing")

# Set deployment mode to self-hosted
node.override['axonops']['deployment_mode'] = 'self-hosted'

# Install Java first
include_recipe 'axonops::java'

# Install Elasticsearch for AxonOps storage
Chef::Log.info("Installing Elasticsearch for AxonOps...")
node.override['axonops']['server']['elasticsearch']['install'] = true
node.override['elasticsearch']['version'] = '7.17.26'
node.override['elasticsearch']['heap_size'] = '1g'
include_recipe 'axonops::install_elasticsearch_tarball'

# Install Cassandra for AxonOps metrics storage
Chef::Log.info("Installing Cassandra for AxonOps metrics...")
node.override['cassandra']['cluster_name'] = 'AxonOps Metrics'
node.override['cassandra']['version'] = '4.1.9'
node.override['cassandra']['data_root'] = '/var/lib/axonops-cassandra'
node.override['cassandra']['directories']['logs'] = '/var/log/axonops-cassandra'
node.override['cassandra']['listen_address'] = node['ipaddress']
node.override['cassandra']['rpc_address'] = node['ipaddress']
node.override['cassandra']['native_transport_port'] = 9142  # Different port to avoid conflict
node.override['cassandra']['storage_port'] = 7100         # Different port
node.override['cassandra']['jmx_port'] = 7299            # Different port

# Create a separate systemd service for AxonOps Cassandra
ruby_block 'setup_axonops_cassandra' do
  block do
    # Save current cassandra attributes
    original_attrs = {}
    %w[data_root directories listen_address rpc_address native_transport_port storage_port jmx_port].each do |attr|
      original_attrs[attr] = node['cassandra'][attr]
    end
    
    # Store for later restoration
    node.run_state['original_cassandra_attrs'] = original_attrs
  end
end

include_recipe 'axonops::install_cassandra_tarball'
include_recipe 'axonops::configure_cassandra'

# Rename the service to avoid conflicts
execute 'rename_axonops_cassandra_service' do
  command 'mv /etc/systemd/system/cassandra.service /etc/systemd/system/axonops-cassandra.service'
  only_if { ::File.exist?('/etc/systemd/system/cassandra.service') }
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
end

execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

service 'axonops-cassandra' do
  service_name 'axonops-cassandra'
  supports status: true, restart: true
  action [:enable, :start]
end

# Wait for services to be ready
ruby_block 'wait_for_services' do
  block do
    # Wait for Elasticsearch
    require 'net/http'
    require 'uri'
    
    Chef::Log.info("Waiting for Elasticsearch to be ready...")
    es_retries = 30
    begin
      uri = URI.parse('http://localhost:9200')
      response = Net::HTTP.get_response(uri)
      unless response.code.to_i == 200
        raise "Elasticsearch not ready: #{response.code}"
      end
      Chef::Log.info("Elasticsearch is ready!")
    rescue => e
      if es_retries > 0
        es_retries -= 1
        Chef::Log.info("Waiting for Elasticsearch... (#{e.message})")
        sleep 5
        retry
      else
        raise "Elasticsearch failed to start: #{e.message}"
      end
    end
    
    # Wait for Cassandra
    Chef::Log.info("Waiting for AxonOps Cassandra to be ready...")
    cass_retries = 30
    begin
      # Check if port is listening
      require 'socket'
      TCPSocket.new('localhost', 9142).close
      Chef::Log.info("AxonOps Cassandra is ready!")
    rescue => e
      if cass_retries > 0
        cass_retries -= 1
        Chef::Log.info("Waiting for Cassandra... (#{e.message})")
        sleep 5
        retry
      else
        raise "Cassandra failed to start: #{e.message}"
      end
    end
  end
end

# Install AxonOps Server
Chef::Log.info("Installing AxonOps Server...")
node.override['axonops']['server']['enabled'] = true
node.override['axonops']['server']['listen_address'] = '0.0.0.0'
node.override['axonops']['server']['listen_port'] = 8080
node.override['axonops']['server']['elasticsearch']['url'] = 'http://localhost:9200'
node.override['axonops']['server']['cassandra']['hosts'] = ["#{node['ipaddress']}:9142"]

# Use the actual server recipe
include_recipe 'axonops::server'

# Install AxonOps Dashboard
Chef::Log.info("Installing AxonOps Dashboard...")
node.override['axonops']['dashboard']['enabled'] = true
node.override['axonops']['dashboard']['listen_address'] = '0.0.0.0'
node.override['axonops']['dashboard']['listen_port'] = 3000
node.override['axonops']['dashboard']['server_endpoint'] = "http://localhost:8080"

include_recipe 'axonops::dashboard'

# Now install application Cassandra cluster (restore original attributes)
ruby_block 'restore_cassandra_attrs' do
  block do
    if node.run_state['original_cassandra_attrs']
      node.run_state['original_cassandra_attrs'].each do |attr, value|
        node.override['cassandra'][attr] = value
      end
    end
  end
end

# Install application Cassandra
Chef::Log.info("Installing Application Cassandra cluster...")
node.override['cassandra']['cluster_name'] = 'Test Application Cluster'
node.override['cassandra']['version'] = '5.0.4'
node.override['cassandra']['data_root'] = '/var/lib/cassandra'
node.override['cassandra']['directories']['logs'] = '/var/log/cassandra'
node.override['cassandra']['listen_address'] = node['ipaddress']
node.override['cassandra']['rpc_address'] = node['ipaddress']
node.override['cassandra']['native_transport_port'] = 9042  # Standard port
node.override['cassandra']['storage_port'] = 7000         # Standard port
node.override['cassandra']['jmx_port'] = 7199            # Standard port

include_recipe 'axonops::cassandra'

# Install AxonOps Agent to monitor the application Cassandra
Chef::Log.info("Installing AxonOps Agent...")
node.override['axonops']['agent']['enabled'] = true
node.override['axonops']['agent']['hosts'] = 'localhost'
node.override['axonops']['agent']['port'] = 8080
node.override['axonops']['agent']['cassandra_home'] = '/opt/cassandra/cassandra'
node.override['axonops']['agent']['cassandra_config'] = '/opt/cassandra/cassandra/conf'

include_recipe 'axonops::agent'

# Create test data in application Cassandra
execute 'wait_for_app_cassandra' do
  command 'sleep 30'
  action :run
end

execute 'create_test_keyspace' do
  command <<-CQL
    /opt/cassandra/cassandra/bin/cqlsh -e "
    CREATE KEYSPACE IF NOT EXISTS test_app 
    WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};
    
    USE test_app;
    
    CREATE TABLE IF NOT EXISTS users (
      id uuid PRIMARY KEY,
      username text,
      email text,
      created_at timestamp
    );
    
    INSERT INTO users (id, username, email, created_at) 
    VALUES (uuid(), 'testuser1', 'test1@example.com', toTimestamp(now()));
    
    INSERT INTO users (id, username, email, created_at) 
    VALUES (uuid(), 'testuser2', 'test2@example.com', toTimestamp(now()));
    "
  CQL
  retries 3
  retry_delay 10
  ignore_failure true
end

# Log summary
log 'full_stack_summary' do
  message <<-MSG
  
  AxonOps Full Stack Integration Deployment Complete!
  ==================================================
  
  Components Installed:
  - Elasticsearch 7.x (AxonOps storage): http://#{node['ipaddress']}:9200
  - Cassandra (AxonOps metrics): #{node['ipaddress']}:9142
  - AxonOps Server: http://#{node['ipaddress']}:8080
  - AxonOps Dashboard: http://#{node['ipaddress']}:3000
  - Application Cassandra: #{node['ipaddress']}:9042
  - AxonOps Agent: Monitoring application Cassandra
  
  Test Data:
  - Keyspace: test_app
  - Table: users (with sample data)
  
  Next Steps:
  1. Access dashboard at http://#{node['ipaddress']}:3000
  2. Check agent connection in the UI
  3. View Cassandra metrics and logs
  
  MSG
  level :info
end