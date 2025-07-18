#
# Cookbook:: cassandra-ops
# Recipe:: system_tuning
#
# Applies system-level tuning for Cassandra
#

# Set vm.max_map_count
sysctl 'vm.max_map_count' do
  value node['cassandra']['system']['max_map_count']
  action :apply
end

# Configure ulimits for cassandra user
ulimit_domain node['cassandra']['user'] do
  rule do
    item :nofile
    type :hard
    value node['cassandra']['system']['file_descriptor_limit']
  end
  rule do
    item :nofile
    type :soft
    value node['cassandra']['system']['file_descriptor_limit']
  end
  rule do
    item :memlock
    type :hard
    value node['cassandra']['system']['memlock_limit']
  end
  rule do
    item :memlock
    type :soft
    value node['cassandra']['system']['memlock_limit']
  end
  rule do
    item :as
    type :hard
    value node['cassandra']['system']['as_limit']
  end
  rule do
    item :as
    type :soft
    value node['cassandra']['system']['as_limit']
  end
  rule do
    item :nproc
    type :hard
    value node['cassandra']['system']['nproc_limit']
  end
  rule do
    item :nproc
    type :soft
    value node['cassandra']['system']['nproc_limit']
  end
end

# Disable swap
execute 'disable-swap' do
  command 'swapoff -a'
  only_if 'swapon -s | grep -v Filename'
end

# Remove swap from fstab
ruby_block 'remove-swap-from-fstab' do
  block do
    fe = Chef::Util::FileEdit.new('/etc/fstab')
    fe.search_file_delete_line(/\sswap\s/)
    fe.write_file
  end
  only_if { ::File.exist?('/etc/fstab') }
end

# Configure transparent huge pages
%w(enabled defrag).each do |param|
  file "/sys/kernel/mm/transparent_hugepage/#{param}" do
    content 'never'
    only_if { ::File.exist?("/sys/kernel/mm/transparent_hugepage/#{param}") }
  end
end

# Ensure the settings persist across reboots
template '/etc/rc.local' do
  source 'rc.local.erb'
  mode '0755'
  action :create
  only_if { platform_family?('debian') }
end
