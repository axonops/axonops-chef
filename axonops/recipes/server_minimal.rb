#
# Cookbook:: axonops
# Recipe:: server_minimal
#
# Minimal server recipe for testing without dependencies
#

# Create axonops user and directories
include_recipe 'axonops::_common'

# For testing, create mock server binary
file '/usr/bin/axon-server' do
  content "#!/bin/bash\necho 'AxonOps Server (test mode)'\n"
  mode '0755'
end

# Create config
directory '/etc/axonops' do
  owner 'axonops'
  group 'axonops'
  mode '0755'
end

file '/etc/axonops/axon-server.yml' do
  content <<-YAML
server:
  listen_port: 8080
  api_key: test-key
  organization: test-org
elasticsearch:
  url: http://localhost:9200
cassandra:
  seeds:
    - localhost
YAML
  owner 'axonops'
  group 'axonops'
  mode '0600'
end

# Create systemd service
file '/etc/systemd/system/axon-server.service' do
  content <<-EOH
[Unit]
Description=AxonOps Server (Test)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/axon-server
User=axonops
Group=axonops
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOH
  mode '0644'
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
end

execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

log 'server-test-complete' do
  message 'Server minimal test recipe completed successfully'
  level :info
end