#
# Cookbook:: axonops
# Recipe:: install_axonops_server_binary
#
# Installs AxonOps Server binary with realistic behavior
#

# Create a more realistic mock server binary that actually listens on ports
cookbook_file '/usr/bin/axon-server' do
  source 'axon-server-mock.py'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

# Create Python dependencies for the mock
package %w[python3 python3-flask] do
  action :install
end

# Ensure the service is restarted if the binary changes
service 'axon-server' do
  action :nothing
  subscribes :restart, 'cookbook_file[/usr/bin/axon-server]', :delayed
end