#
# Cookbook:: axonops
# Recipe:: system_tuning
#
# Applies system-level tuning optimized for Apache Cassandra
#

running_in_container = ::File.exist?('/.dockerenv') ||
  ::File.exist?('/run/.containerenv') ||
  (node['virtualization'] && node['virtualization']['system'] == 'docker')

file '/etc/sysctl.d/99-cassandra.conf' do
  content <<-EOF
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
  EOF
  mode '0644'
  notifies :run, 'execute[apply-cassandra-sysctl]', :immediately
  not_if { running_in_container }
end

execute 'apply-cassandra-sysctl' do
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
    content "# Managed by Chef\nENABLED=\"0\"\nONESHOT=\"0\"\n"
    owner 'root'
    group 'root'
    mode '0644'
  end
end

if node['axonops']['cassandra']['jemalloc_enabled']
  case node['platform_family']
  when 'debian'
    package 'libjemalloc2'
  when 'rhel', 'fedora'
    package 'epel-release'
    package 'jemalloc'
  end

  ruby_block 'find-jemalloc' do
    block do
      jemalloc_path = Dir.glob('/usr/lib*/**/libjemalloc.so*').first
      node.run_state['cassandra_jemalloc_path'] = jemalloc_path if jemalloc_path
    end
  end
end

log 'system_tuning_complete' do
  message 'Cassandra system tuning configuration completed'
  level :info
end
