#
# Cookbook:: axonops
# Recipe:: test_real_packages_minimal
#
# Minimal test recipe for real AxonOps packages
#

# Set up for offline installation
node.override['axonops']['offline_install'] = true
node.override['axonops']['offline_packages_dir'] = '/vagrant/offline_packages'

# Common setup
include_recipe 'axonops::_common'

# Update apt cache first
execute 'apt-update' do
  command 'apt-get update'
  action :run
end

# Install dependencies
package %w[adduser procps python3] do
  action :install
end

# Install real AxonOps packages
Chef::Log.info("Installing real AxonOps packages from #{node['axonops']['offline_packages_dir']}")

# Install server package
server_deb = Dir.glob("#{node['axonops']['offline_packages_dir']}/axon-server_*.deb").first
if server_deb
  # Use execute to force architecture
  execute 'install-axon-server' do
    command "dpkg --force-architecture -i #{server_deb}"
    action :run
    not_if "dpkg -l | grep -q '^ii  axon-server '"
  end
  
  # Create minimal config
  directory '/etc/axonops' do
    owner 'axonops'
    group 'axonops'
    mode '0755'
  end
  
  file '/etc/axonops/axon-server.yml' do
    content <<-YAML
server:
  listen_address: 0.0.0.0
  listen_port: 8080

storage:
  type: elasticsearch
  elasticsearch:
    url: http://localhost:9200
    
logging:
  level: INFO
  file: /var/log/axonops/axon-server.log
YAML
    owner 'axonops'
    group 'axonops'
    mode '0640'
  end
  
  service 'axon-server' do
    action [:enable, :start]
  end
else
  Chef::Log.error("axon-server package not found")
end

# Install dashboard package
dash_deb = Dir.glob("#{node['axonops']['offline_packages_dir']}/axon-dash_*.deb").first
if dash_deb
  # Fix broken packages first
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
  
logging:
  level: INFO
  file: /var/log/axonops/axon-dash.log
YAML
    owner 'axonops'
    group 'axonops'
    mode '0640'
  end
  
  service 'axon-dash' do
    action [:enable, :start]
  end
else
  Chef::Log.error("axon-dash package not found")
end

# Install agent package
agent_deb = Dir.glob("#{node['axonops']['offline_packages_dir']}/axon-agent_*.deb").first
if agent_deb
  execute 'install-axon-agent' do
    command "dpkg --force-architecture --force-depends -i #{agent_deb}"
    action :run
    not_if "dpkg -l | grep -q '^ii  axon-agent '"
  end
  
  file '/etc/axonops/axon-agent.yml' do
    content <<-YAML
agent:
  name: #{node['hostname']}
  
server:
  hosts: ["localhost:8080"]
  
cassandra:
  hosts: ["localhost:9042"]
  
monitoring:
  interval: 60
  
logging:
  level: INFO
  file: /var/log/axonops/axon-agent.log
YAML
    owner 'axonops'
    group 'axonops'
    mode '0640'
  end
  
  service 'axon-agent' do
    action [:enable, :start]
  end
else
  Chef::Log.error("axon-agent package not found")
end

# Log summary
log 'real_packages_minimal_test' do
  message <<-MSG
  
  AxonOps Real Packages Minimal Test
  ==================================
  
  Installed Packages:
  - axon-server: #{server_deb ? 'YES' : 'NO'}
  - axon-dash: #{dash_deb ? 'YES' : 'NO'}
  - axon-agent: #{agent_deb ? 'YES' : 'NO'}
  
  Services should be running on:
  - Server: http://#{node['ipaddress']}:8080
  - Dashboard: http://#{node['ipaddress']}:3000
  
  Check logs in /var/log/axonops/
  
  MSG
  level :info
end