#
# Cookbook:: cassandra-ops
# Recipe:: axonops_dashboard
#
# Deploys AxonOps Dashboard for self-hosted monitoring UI
#

# Validate deployment mode
unless node['axonops']['deployment_mode'] == 'self-hosted'
  Chef::Log.info('AxonOps dashboard recipe called but deployment_mode is not self-hosted')
  return
end

unless node['axonops']['dashboard']['enabled']
  Chef::Log.info('AxonOps dashboard is not enabled')
  return
end

# Add AxonOps repository
include_recipe 'axonops::repo'

# Install fuse package for RedHat family
package 'fuse' do
  only_if { platform_family?('rhel', 'fedora') }
end

# Create necessary directories
%w(
  /etc/axonops
  /var/log/axonops
).each do |dir|
  directory dir do
    owner node['axonops']['agent']['user']
    group node['axonops']['agent']['group']
    mode '0755'
  end
end

# Install AxonOps dashboard package
if node['axonops']['offline_install']
  # Offline installation from local package
  if node['axonops']['packages']['dashboard'].nil?
    raise('Offline installation requested but axonops.packages.dashboard not specified')
  end

  package_path = ::File.join(node['axonops']['offline_packages_path'], node['axonops']['packages']['dashboard'])

  unless ::File.exist?(package_path)
    raise("Offline package not found: #{package_path}")
  end

  case node['platform_family']
  when 'debian'
    dpkg_package node['axonops']['dashboard']['package'] do
      source package_path
      action :install
      notifies :restart, 'service[axon-dash]', :delayed
    end
  when 'rhel', 'fedora'
    rpm_package node['axonops']['dashboard']['package'] do
      source package_path
      action :install
      notifies :restart, 'service[axon-dash]', :delayed
    end
  end
else
  # Online installation from repository
  package node['axonops']['dashboard']['package'] do
    version node['axonops']['dashboard']['version'] unless node['axonops']['dashboard']['version'] == 'latest'
    action :install
    notifies :restart, 'service[axon-dash]', :delayed
  end
end

# Generate dashboard configuration
template '/etc/axonops/axon-dash.yml' do
  source 'axon-dash.yml.erb'
  owner node['axonops']['agent']['user']
  group node['axonops']['agent']['group']
  mode '0640'
  variables(
    listen_host: node['axonops']['dashboard']['listen_address'],
    listen_port: node['axonops']['dashboard']['listen_port'],
    server_endpoint: node['axonops']['dashboard']['server_endpoint'],
    context_path: node['axonops']['dashboard']['context_path']
  )
  notifies :restart, 'service[axon-dash]', :delayed
end

# Create systemd service override directory
directory '/etc/systemd/system/axon-dash.service.d' do
  owner 'root'
  group 'root'
  mode '0755'
end

# Create systemd override for service configuration
template '/etc/systemd/system/axon-dash.service.d/override.conf' do
  source 'systemd-override.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    user: node['axonops']['agent']['user'],
    group: node['axonops']['agent']['group'],
    limits: {
      'LimitNOFILE' => '65536',
    }
  )
  notifies :run, 'execute[systemctl-daemon-reload-dash]', :immediately
  notifies :restart, 'service[axon-dash]', :delayed
end

# Reload systemd
execute 'systemctl-daemon-reload-dash' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Configure nginx if requested
if node['axonops']['dashboard']['nginx_proxy']
  # TODO: Add nginx proxy recipe
  Chef::Log.info('Nginx proxy configuration requested but recipe not yet implemented')
end

# Enable and start AxonOps dashboard
service 'axon-dash' do
  supports status: true, restart: true, reload: true
  action [:enable, :start]
end

# Log access information
log 'axonops-dashboard-info' do
  message "AxonOps Dashboard is available at http://#{node['axonops']['dashboard']['listen_address']}:#{node['axonops']['dashboard']['listen_port']}#{node['axonops']['dashboard']['context_path']}"
  level :info
end
