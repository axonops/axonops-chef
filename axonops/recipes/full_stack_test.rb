#
# Cookbook:: axonops
# Recipe:: full_stack_test
#
# Test recipe for full AxonOps stack deployment
#

# Include prerequisites
include_recipe 'axonops::default'
include_recipe 'axonops::_common'

# Install Java for all components
include_recipe 'axonops::java'

# Create mock Elasticsearch
file '/usr/bin/elasticsearch' do
  content "#!/bin/bash\necho 'Elasticsearch (test mode)'\n"
  mode '0755'
end

directory '/etc/elasticsearch' do
  mode '0755'
end

file '/etc/elasticsearch/elasticsearch.yml' do
  content <<-YAML
cluster.name: axonops
node.name: node-1
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
network.host: 127.0.0.1
http.port: 9200
YAML
  mode '0644'
end

# Create mock Cassandra
include_recipe 'axonops::cassandra_minimal'

# Create all AxonOps components
['axon-agent', 'axon-server', 'axon-dash'].each do |component|
  file "/usr/bin/#{component}" do
    content "#!/bin/bash\necho '#{component} (full-stack test mode)'\n"
    mode '0755'
  end
end

# Create all configs
file '/etc/axonops/axon-agent.yml' do
  content <<-YAML
agent:
  name: "full-stack-node"
server:
  hosts: ["localhost:8080"]
cassandra:
  hosts: ["localhost:9042"]
YAML
  owner 'axonops'
  group 'axonops'
  mode '0640'
end

file '/etc/axonops/axon-server.yml' do
  content <<-YAML
server:
  listen_address: 0.0.0.0
  listen_port: 8080
storage:
  type: elasticsearch
  elasticsearch:
    hosts: ["http://localhost:9200"]
cassandra:
  hosts: ["localhost:9042"]
YAML
  owner 'axonops'
  group 'axonops'
  mode '0640'
end

file '/etc/axonops/axon-dash.yml' do
  content <<-YAML
dashboard:
  listen_address: 0.0.0.0
  listen_port: 3000
  server_endpoint: http://localhost:8080
YAML
  owner 'axonops'
  group 'axonops'
  mode '0640'
end

# Create systemd services for all components
['elasticsearch', 'cassandra', 'axon-agent', 'axon-server', 'axon-dash'].each do |service|
  file "/etc/systemd/system/#{service}.service" do
    content <<-EOH
[Unit]
Description=#{service} (Full Stack Test)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/#{service}
User=#{service == 'elasticsearch' ? 'root' : (service == 'cassandra' ? 'cassandra' : 'axonops')}
Group=#{service == 'elasticsearch' ? 'root' : (service == 'cassandra' ? 'cassandra' : 'axonops')}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOH
    mode '0644'
  end
end

execute 'systemctl-daemon-reload-full-stack' do
  command 'systemctl daemon-reload'
end

# Log completion
log 'axonops-full-stack-test-info' do
  message 'AxonOps full stack test recipe completed'
  level :info
end