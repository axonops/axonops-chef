#
# Cookbook:: axonops
# Recipe:: _common
#
# Common setup for all AxonOps components
#

include_recipe 'axonops::system_tuning' unless node['axonops']['skip_system_tuning']
include_recipe 'axonops::users'

# Create log directory with proper permissions
['/var/log/axonops', '/var/lib/axonops'].each do |dir|
  directory dir do
    owner node['axonops']['agent']['user']
    group node['axonops']['agent']['group']
    mode '0775'
  end
end


# Set up system limits for axonops user
template '/etc/security/limits.d/axonops.conf' do
  source 'limits.conf.erb'
  mode '0644'
  variables(
    user: node['axonops']['agent']['user'],
    limits: {
      'nofile' => '65536',
      'nproc' => '32768',
      'memlock' => 'unlimited'
    }
  )
  action :create
end

# Ensure sysctl settings for network and memory
file '/etc/sysctl.d/99-axonops.conf' do
  sysctl_content = ["# AxonOps recommended settings"]
  sysctl_content << "vm.max_map_count=1048575" unless node['axonops']['skip_vm_max_map_count']
  sysctl_content << "net.ipv4.tcp_keepalive_time=60"
  sysctl_content << "net.ipv4.tcp_keepalive_probes=3"
  sysctl_content << "net.ipv4.tcp_keepalive_intvl=10"

  content sysctl_content.join("\n") + "\n"
  mode '0644'
  notifies :run, 'execute[sysctl-reload]', :immediately
end

execute 'sysctl-reload' do
  command 'sysctl -p /etc/sysctl.d/99-axonops.conf'
  action :nothing
end
