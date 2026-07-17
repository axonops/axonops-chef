#
# Cookbook:: axonops
# Recipe:: system_tuning
#
# Applies system-level tuning optimized for Apache Cassandra
#

# not_if blocks run with self rebound to the resource, so a def'd method
# isn't reachable there — compute once and close over the local var instead.
running_in_container = ::File.exist?('/.dockerenv') ||
  (::File.exist?('/proc/1/cgroup') && ::File.read('/proc/1/cgroup').match?(/docker|lxc|kubepods/))

sysctl_content = <<~SYSCTL
  vm.swappiness=1
  vm.overcommit_memory=1
  vm.max_map_count=1048575
  net.ipv4.tcp_keepalive_time=300
  net.core.rmem_max=16777216
  net.core.wmem_max=16777216
  net.core.rmem_default=16777216
  net.core.wmem_default=16777216
  net.core.optmem_max=40960
  net.ipv4.tcp_rmem=4096 87380 16777216
  net.ipv4.tcp_wmem=4096 65536 16777216
SYSCTL

file '/etc/sysctl.d/99-cassandra.conf' do
  content sysctl_content
  mode '0644'
  owner 'root'
  group 'root'
  notifies :run, 'execute[sysctl -p /etc/sysctl.d/99-cassandra.conf]', :immediately
  not_if { running_in_container }
end

execute 'sysctl -p /etc/sysctl.d/99-cassandra.conf' do
  command 'sysctl -p /etc/sysctl.d/99-cassandra.conf'
  action :nothing
  not_if { running_in_container }
end

template '/etc/security/limits.d/cassandra.conf' do
  source 'limits.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    user: node['axonops']['cassandra']['user'],
    memlock_limit: node['axonops']['cassandra']['limits']['memlock'] || 'unlimited',
    nofile: node['axonops']['cassandra']['limits']['nofile'] || 1000000,
    as_limit: node['axonops']['cassandra']['limits']['as'] || 'unlimited',
    nproc_limit: node['axonops']['cassandra']['limits']['nproc'] || 32768
  )
end

if node['axonops']['cassandra']['disable_irqbalance']
  file '/etc/default/irqbalance' do
    content "ENABLED=\"0\"\n"
    mode '0644'
    owner 'root'
    group 'root'
  end
end

if node['axonops']['cassandra']['jemalloc_enabled']
  if platform_family?('debian')
    package 'libjemalloc2' do
      action :install
    end
    node.run_state['cassandra_jemalloc_path'] = '/usr/lib/x86_64-linux-gnu/libjemalloc.so.2'
  elsif platform_family?('rhel', 'amazon', 'fedora')
    package 'epel-release' do
      action :install
      only_if { platform_family?('rhel') }
    end
    package 'jemalloc' do
      action :install
    end
    node.run_state['cassandra_jemalloc_path'] = '/usr/lib64/libjemalloc.so.2'
  end
end

log 'system_tuning_complete' do
  message 'Cassandra system tuning configuration completed'
  level :info
end
