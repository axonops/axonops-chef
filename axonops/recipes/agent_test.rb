#
# Cookbook:: axonops
# Recipe:: agent_test
#
# Simplified agent recipe for testing without external dependencies
#

# Create axonops user and group
group node['axonops']['agent']['group'] do
  system true
end

user node['axonops']['agent']['user'] do
  group node['axonops']['agent']['group']
  system true
  shell '/bin/false'
  home '/var/lib/axonops'
  manage_home true
end

# Create necessary directories
%w(
  /etc/axonops
  /var/log/axonops
  /var/lib/axonops
  /usr/share/axonops
).each do |dir|
  directory dir do
    owner node['axonops']['agent']['user']
    group node['axonops']['agent']['group']
    mode '0755'
  end
end

# For testing, create a dummy package marker instead of installing
file '/usr/bin/axon-agent' do
  content "#!/bin/bash\necho 'AxonOps Agent (test mode)'\n"
  mode '0755'
  owner 'root'
  group 'root'
end

# Mark package as installed for tests
file '/var/lib/dpkg/info/axon-agent.list' do
  content "/usr/bin/axon-agent\n/etc/axonops\n"
  mode '0644'
  only_if { platform_family?('debian') }
end

# Detect existing Cassandra installation
ruby_block 'detect-cassandra' do
  block do
    cassandra_detected = false
    # For testing, just check if directory exists
    if ::File.exist?('/opt/cassandra')
      node.run_state['cassandra_home'] = '/opt/cassandra'
      node.run_state['cassandra_config'] = '/opt/cassandra/conf'
      cassandra_detected = true
    end

    # Write detection result
    ::File.write('/etc/axonops/.cassandra_detected', cassandra_detected.to_s)
  end
end

# Generate agent configuration
template '/etc/axonops/axon-agent.yml' do
  source 'axon-agent.yml.erb'
  owner node['axonops']['agent']['user']
  group node['axonops']['agent']['group']
  mode '0600'
  variables(
    api_key: node['axonops']['agent']['key'] || node['axonops']['api']['key'],
    org_name: node['axonops']['agent']['organization'] || node['axonops']['api']['organization'],
    agent_host: node['axonops']['agent']['hosts'] || 'api.axonops.com',
    agent_port: node['axonops']['agent']['port'] || 443,
    disable_command_exec: false,
    cassandra_home: node.run_state['cassandra_home'] || '/opt/cassandra',
    cassandra_config: node.run_state['cassandra_config'] || '/opt/cassandra/conf',
    cassandra_logs: '/var/log/cassandra',
    node_address: node['ipaddress'],
    node_dc: 'datacenter1',
    node_rack: 'rack1'
  )
end

# Create a simple systemd service file for testing
file '/etc/systemd/system/axon-agent.service' do
  content <<-EOH
[Unit]
Description=AxonOps Agent (Test)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/axon-agent
User=#{node['axonops']['agent']['user']}
Group=#{node['axonops']['agent']['group']}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOH
  mode '0644'
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
end

# Reload systemd
execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Log configuration info
log 'axonops-agent-test-info' do
  message 'AxonOps agent test recipe completed'
  level :info
end
