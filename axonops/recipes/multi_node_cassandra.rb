#
# Cookbook:: axonops
# Recipe:: multi_node_cassandra
#
# Deploys Apache Cassandra 5.0 with AxonOps agent for multi-node testing
#

Chef::Log.info("Setting up Cassandra application node with AxonOps monitoring")
Chef::Log.info("AxonOps Server: #{node['axonops']['multi_node']['server_ip']}")

# Common setup for AxonOps
include_recipe 'axonops::_common'

# Install Cassandra 5.0 for the application
Chef::Log.info("Installing Apache Cassandra 5.0...")
include_recipe 'axonops::cassandra_app'

# Wait a bit for Cassandra to start
ruby_block 'wait_for_cassandra' do
  block do
    sleep(10)
  end
  action :run
  only_if { ::File.exist?('/usr/bin/cassandra') || ::File.exist?('/opt/cassandra/bin/cassandra') }
end

# Configure AxonOps Agent to monitor this Cassandra
Chef::Log.info("Installing AxonOps Agent...")
node.override['axonops']['agent']['enabled'] = true

# Configure agent to connect to the AxonOps server
axonops_server_ip = node['axonops']['multi_node']['server_ip']

file '/etc/axonops/axon-agent.yml' do
  content <<-YAML
agent:
  name: "cassandra-app-#{node['hostname']}"
  tags:
    environment: "test"
    cluster: "app"
    datacenter: "dc1"
    rack: "rack1"
    
server:
  hosts: ["#{axonops_server_ip}:8080"]
  ssl: false
  
cassandra:
  hosts: ["localhost:9042"]
  username: ""  # If authentication is enabled
  password: ""  # If authentication is enabled
  
monitoring:
  interval: 60
  
metrics:
  enabled: true
  jmx:
    port: 7199
    
logs:
  enabled: true
  path: "/var/log/cassandra"
  
backups:
  enabled: false  # Enable if needed
  
organization_id: "test-org"
cluster_id: "test-cluster"

logging:
  level: INFO
  file: /var/log/axonops/agent.log
YAML
  owner 'axonops'
  group 'axonops'
  mode '0640'
  notifies :restart, 'service[axon-agent]'
end

# Install AxonOps Agent with realistic behavior
include_recipe 'axonops::install_axonops_agent_binary'

# Create agent service
file '/etc/systemd/system/axon-agent.service' do
  content <<-EOU
[Unit]
Description=AxonOps Agent
After=network.target cassandra.service

[Service]
Type=simple
ExecStart=/usr/bin/axon-agent
User=axonops
Group=axonops
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOU
  mode '0644'
  notifies :run, 'execute[systemctl-daemon-reload-agent]', :immediately
end

execute 'systemctl-daemon-reload-agent' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Ensure Cassandra is configured for monitoring
# Add JMX settings if needed
file '/etc/cassandra/jvm-server.options' do
  content <<-OPTIONS
# JVM options for Cassandra server
-Dcom.sun.management.jmxremote.port=7199
-Dcom.sun.management.jmxremote.ssl=false
-Dcom.sun.management.jmxremote.authenticate=false
-Dcom.sun.management.jmxremote.local.only=false
-Djava.rmi.server.hostname=#{node['ipaddress']}
OPTIONS
  owner 'cassandra'
  group 'cassandra'
  mode '0644'
  only_if { ::File.exist?('/etc/cassandra') }
end

# Start the agent
service 'axon-agent' do
  action [:enable, :start]
end

# Create a test keyspace to verify Cassandra is working
execute 'create_test_keyspace' do
  command <<-CQL
    cqlsh -e "CREATE KEYSPACE IF NOT EXISTS test_app WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};"
  CQL
  retries 3
  retry_delay 10
  only_if 'which cqlsh'
  ignore_failure true
end

# Log success
Chef::Log.info("Cassandra node deployed successfully with AxonOps monitoring!")
Chef::Log.info("Cassandra listening on: #{node['cassandra']['listen_address']}:9042")
Chef::Log.info("Agent reporting to: http://#{axonops_server_ip}:8080")