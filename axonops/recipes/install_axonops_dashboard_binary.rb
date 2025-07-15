#
# Cookbook:: axonops
# Recipe:: install_axonops_dashboard_binary
#
# Installs AxonOps Dashboard binary with realistic behavior
#

# Install Python and Flask for the mock
package %w[python3 python3-flask] do
  action :install
end

# Create the mock dashboard binary
cookbook_file '/usr/bin/axon-dash' do
  source 'axon-dash-mock.py'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

# Ensure the service is restarted if the binary changes
service 'axon-dash' do
  action :nothing
  subscribes :restart, 'cookbook_file[/usr/bin/axon-dash]', :delayed
end