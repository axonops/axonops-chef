#
# Cookbook:: axonops
# Recipe:: cassandra_minimal
#
# Minimal Cassandra installation for testing
#

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
  content "#!/bin/bash\necho 'Cassandra (test mode)'\n"
  mode '0755'
end

# Create basic config
file '/etc/cassandra/cassandra.yaml' do
  content <<-YAML
cluster_name: 'Test Cluster'
num_tokens: 16
endpoint_snitch: SimpleSnitch
data_file_directories:
  - /var/lib/cassandra/data
commitlog_directory: /var/lib/cassandra/commitlog
saved_caches_directory: /var/lib/cassandra/saved_caches
hints_directory: /var/lib/cassandra/hints
YAML
  owner 'cassandra'
  group 'cassandra'
  mode '0644'
end

# Create systemd service
file '/etc/systemd/system/cassandra.service' do
  content <<-EOH
[Unit]
Description=Cassandra (Test)
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/cassandra
User=cassandra
Group=cassandra
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOH
  mode '0644'
  notifies :run, 'execute[systemctl-daemon-reload-cassandra]', :immediately
end

execute 'systemctl-daemon-reload-cassandra' do
  command 'systemctl daemon-reload'
  action :nothing
end

log 'cassandra-minimal-complete' do
  message 'Cassandra minimal test recipe completed'
  level :info
end