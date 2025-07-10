#
# Cookbook:: axonops
# Recipe:: dashboard_test
#
# Test recipe for AxonOps dashboard
#

# Include prerequisites
include_recipe 'axonops::default'

# Create required users and directories
include_recipe 'axonops::_common'

# For testing, create mock dashboard
file '/usr/bin/axon-dash' do
  content "#!/bin/bash\necho 'AxonOps Dashboard (test mode)'\n"
  mode '0755'
end

# Create config
file '/etc/axonops/axon-dash.yml' do
  content <<-YAML
dashboard:
  listen_address: 0.0.0.0
  listen_port: 3000
  server_endpoint: http://localhost:8080
  context_path: /
YAML
  owner 'axonops'
  group 'axonops'
  mode '0640'
end

# Create systemd service
file '/etc/systemd/system/axon-dash.service' do
  content <<-EOH
[Unit]
Description=AxonOps Dashboard (Test)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/axon-dash
User=axonops
Group=axonops
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOH
  mode '0644'
  notifies :run, 'execute[systemctl-daemon-reload-dash]', :immediately
end

execute 'systemctl-daemon-reload-dash' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Log completion
log 'axonops-dashboard-test-info' do
  message 'AxonOps dashboard test recipe completed'
  level :info
end