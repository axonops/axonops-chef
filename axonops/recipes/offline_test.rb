#
# Cookbook:: axonops
# Recipe:: offline_test
#
# Test recipe for offline/airgapped installation
#

# Include prerequisites
include_recipe 'axonops::default'
include_recipe 'axonops::_common'

# Set offline mode
node.override['axonops']['offline_install'] = true
node.override['axonops']['offline_packages_path'] = '/tmp/packages'

# Create offline package directory
directory '/tmp/packages' do
  mode '0755'
  recursive true
end

# Create dummy packages for testing
%w[
  axon-agent_1.0.0_amd64.deb
  axon-server_1.0.0_amd64.deb 
  axon-dash_1.0.0_amd64.deb
].each do |pkg|
  file "/tmp/packages/#{pkg}" do
    content "Dummy package for testing: #{pkg}"
    mode '0644'
  end
end

# Create dummy Java tarball
file '/tmp/packages/zulu17-jdk.tar.gz' do
  content "Dummy Java tarball for testing"
  mode '0644'
end

# Install Java to /opt/java (simulating offline install)
directory '/opt/java' do
  mode '0755'
  recursive true
end

directory '/opt/java/zulu17' do
  mode '0755'
end

link '/opt/java/default' do
  to '/opt/java/zulu17'
end

directory '/opt/java/zulu17/bin' do
  mode '0755'
  recursive true
end

# Create mock java binary
file '/opt/java/zulu17/bin/java' do
  content "#!/bin/bash\necho 'Java 17 (offline test mode)'\n"
  mode '0755'
end

# Set JAVA_HOME for offline Java
file '/etc/profile.d/java.sh' do
  content <<-EOH
export JAVA_HOME=/opt/java/default
export PATH=$JAVA_HOME/bin:$PATH
EOH
  mode '0644'
end

# Create mock agent binary and config
file '/usr/bin/axon-agent' do
  content "#!/bin/bash\necho 'AxonOps Agent (offline test mode)'\n"
  mode '0755'
end

# Create agent config pointing to internal endpoints
file '/etc/axonops/axon-agent.yml' do
  content <<-YAML
agent:
  name: "node1"
  tags:
    dc: "datacenter1"
    environment: "airgapped"

server:
  hosts: ["internal.axonops.local:8080"]
  use_ssl: false
  
organization_id: "offline-org"

cassandra:
  hosts: ["localhost:9042"]
  binary_port: 9042
  
features:
  metrics: true
  events: true
  backups: true
YAML
  owner 'axonops'
  group 'axonops'
  mode '0640'
end

# Create systemd service
file '/etc/systemd/system/axon-agent.service' do
  content <<-EOH
[Unit]
Description=AxonOps Agent (Offline)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/axon-agent
User=axonops
Group=axonops
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOH
  mode '0644'
  notifies :run, 'execute[systemctl-daemon-reload-offline]', :immediately
end

execute 'systemctl-daemon-reload-offline' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Log completion
log 'axonops-offline-test-info' do
  message 'AxonOps offline test recipe completed'
  level :info
end