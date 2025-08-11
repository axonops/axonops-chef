#
# Cookbook:: cassandra-ops
# Recipe:: axonops_dashboard
#
# Deploys AxonOps Dashboard for self-hosted monitoring UI
#

include_recipe 'axonops::common'

# Install fuse package for RedHat family
package 'fuse' do
  only_if { platform_family?('rhel', 'fedora') }
end


# Install AxonOps dashboard package
if node['axonops']['offline_install']
  # Offline installation from local package
  if node['axonops']['dashboard']['package'].nil?
    raise('Offline installation requested but axonops.dashboard.package not specified')
  end

  package_path = ::File.join(node['axonops']['offline_packages_path'], node['axonops']['offline_packages']['dashboard'])

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
  include_recipe 'axonops::repo'

  # Online installation from repository
  package 'axon-dash' do
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

# Reload systemd
execute 'systemctl-daemon-reload-dash' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Configure nginx if requested
if node['axonops']['dashboard']['nginx_proxy'] && node['platform_family'] == 'debian'
  include_recipe 'axonops::dashboard_nginx'
end

# Enable and start AxonOps dashboard
service 'axon-dash' do
  supports status: true, restart: true, reload: true
  action [:enable, :start]
end

# Log access information
log 'axonops-dashboard-info' do
  message lazy {
    if node['axonops']['dashboard']['nginx_proxy']
      # When using nginx proxy
      if node['axonops']['dashboard']['nginx']['ssl_enabled']
        "AxonOps Dashboard is available via nginx at https://#{node['axonops']['dashboard']['nginx']['server_name']}:#{node['axonops']['dashboard']['nginx']['ssl_port']}#{node['axonops']['dashboard']['context_path']}"
      else
        "AxonOps Dashboard is available via nginx at http://#{node['axonops']['dashboard']['nginx']['server_name']}:#{node['axonops']['dashboard']['nginx']['listen_port']}#{node['axonops']['dashboard']['context_path']}"
      end
    else
      # Direct access
      "AxonOps Dashboard is available at http://#{node['axonops']['dashboard']['listen_address']}:#{node['axonops']['dashboard']['listen_port']}#{node['axonops']['dashboard']['context_path']}"
    end
  }
  level :info
end
