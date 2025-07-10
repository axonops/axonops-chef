#
# Cookbook:: axonops
# Recipe:: offline
#
# Sets up for offline/airgapped installation
#

# Ensure offline package directory exists
directory node['axonops']['offline_packages_path'] do
  mode '0755'
  recursive true
end

# Log offline mode
log 'offline-mode' do
  message "Running in offline mode, packages should be in #{node['axonops']['offline_packages_path']}"
  level :info
end

# For testing, create dummy marker files if they don't exist
if node['axonops']['offline_install']
  %w[
    axon-agent_1.0.0_amd64.deb
    axon-server_1.0.0_amd64.deb 
    axon-dash_1.0.0_amd64.deb
  ].each do |pkg|
    file "#{node['axonops']['offline_packages_path']}/#{pkg}" do
      content "Dummy package for testing: #{pkg}"
      action :create_if_missing
    end
  end
end