#
# Cookbook:: axonops
# Recipe:: install_real_axonops_packages
#
# Installs real AxonOps packages from offline packages directory
#

# Get offline packages directory
offline_dir = node['axonops']['offline_packages_dir'] || File.join(Chef::Config[:file_cache_path], 'offline_packages')

# Ensure we're in offline mode
unless node['axonops']['offline_install']
  Chef::Log.warn("This recipe is intended for offline installation. Setting offline_install to true.")
  node.override['axonops']['offline_install'] = true
end

# Install dependencies first
package %w[adduser procps] do
  action :install
end

# Install AxonOps Server package
if node['axonops']['server']['enabled']
  axon_server_deb = Dir.glob("#{offline_dir}/axon-server_*.deb").first
  
  if axon_server_deb
    dpkg_package 'axon-server' do
      source axon_server_deb
      action :install
      notifies :restart, 'service[axon-server]', :delayed
    end
    
    # Ensure service is defined
    service 'axon-server' do
      supports status: true, restart: true, reload: true
      action [:enable, :start]
    end
  else
    Chef::Log.error("AxonOps Server package not found in #{offline_dir}")
  end
end

# Install AxonOps Dashboard package
if node['axonops']['dashboard']['enabled']
  axon_dash_deb = Dir.glob("#{offline_dir}/axon-dash_*.deb").first
  
  if axon_dash_deb
    dpkg_package 'axon-dash' do
      source axon_dash_deb
      action :install
      notifies :restart, 'service[axon-dash]', :delayed
    end
    
    # Ensure service is defined
    service 'axon-dash' do
      supports status: true, restart: true, reload: true
      action [:enable, :start]
    end
  else
    Chef::Log.error("AxonOps Dashboard package not found in #{offline_dir}")
  end
end

# Install AxonOps Agent package
if node['axonops']['agent']['enabled']
  axon_agent_deb = Dir.glob("#{offline_dir}/axon-agent_*.deb").first
  
  if axon_agent_deb
    dpkg_package 'axon-agent' do
      source axon_agent_deb
      action :install
      notifies :restart, 'service[axon-agent]', :delayed
    end
    
    # Ensure service is defined
    service 'axon-agent' do
      supports status: true, restart: true, reload: true
      action [:enable, :start]
    end
  else
    Chef::Log.error("AxonOps Agent package not found in #{offline_dir}")
  end
end

# Install Cassandra Java Agent - delegate to detection recipe
if node['axonops']['agent']['java_agent']['enabled']
  include_recipe 'axonops::detect_and_install_cassandra_agent'
end