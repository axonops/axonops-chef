#
# Cookbook:: axonops
# Recipe:: install_axonops_agent_binary
#
# Installs AxonOps Agent binary with realistic behavior
#

# Install Python for the mock
package %w[python3] do
  action :install
end

# Create the mock agent binary
cookbook_file '/usr/bin/axon-agent' do
  source 'axon-agent-mock.py'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

# Ensure the service is restarted if the binary changes
service 'axon-agent' do
  action :nothing
  subscribes :restart, 'cookbook_file[/usr/bin/axon-agent]', :delayed
end