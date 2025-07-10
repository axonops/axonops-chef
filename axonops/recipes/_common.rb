#
# Cookbook:: axonops
# Recipe:: _common
#
# Common setup for all AxonOps components
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

# Create common directories
%w[
  /etc/axonops
  /var/log/axonops
  /var/lib/axonops
  /opt/axonops
  /usr/share/axonops
].each do |dir|
  directory dir do
    owner node['axonops']['agent']['user']
    group node['axonops']['agent']['group']
    mode '0755'
  end
end

# Create log directory with proper permissions
directory '/var/log/axonops' do
  owner node['axonops']['agent']['user']
  group node['axonops']['agent']['group']
  mode '0755'
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
  content <<-EOF
# AxonOps recommended settings
vm.max_map_count=1048575
net.ipv4.tcp_keepalive_time=60
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_keepalive_intvl=10
  EOF
  mode '0644'
  notifies :run, 'execute[sysctl-reload]', :immediately
end

execute 'sysctl-reload' do
  command 'sysctl -p /etc/sysctl.d/99-axonops.conf'
  action :nothing
end