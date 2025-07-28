#
# Cookbook:: axonops
# Recipe:: system_tuning
#
# Applies system-level tuning optimized for Apache Cassandra
#

# VM Settings for Cassandra
sysctl 'vm.max_map_count' do
  value node['cassandra']['system']['max_map_count']
  action :apply
  not_if { node['axonops']['skip_vm_max_map_count'] }
end

sysctl 'vm.swappiness' do
  value node['cassandra']['system']['vm_swappiness']
  action :apply
  not_if { node['axonops']['skip_vm_swappiness'] }
end

sysctl 'vm.dirty_ratio' do
  value node['cassandra']['system']['vm_dirty_ratio']
  action :apply
end

sysctl 'vm.dirty_background_ratio' do
  value node['cassandra']['system']['vm_dirty_background_ratio']
  action :apply
end

sysctl 'vm.zone_reclaim_mode' do
  value node['cassandra']['system']['vm_zone_reclaim_mode']
  action :apply
  only_if { ::File.exist?('/proc/sys/vm/zone_reclaim_mode') }
end

# Network settings for Cassandra
sysctl 'net.core.rmem_max' do
  value node['cassandra']['system']['net_core_rmem_max']
  action :apply
end

sysctl 'net.core.wmem_max' do
  value node['cassandra']['system']['net_core_wmem_max']
  action :apply
end

sysctl 'net.core.rmem_default' do
  value node['cassandra']['system']['net_core_rmem_default']
  action :apply
end

sysctl 'net.core.wmem_default' do
  value node['cassandra']['system']['net_core_wmem_default']
  action :apply
end

sysctl 'net.core.optmem_max' do
  value node['cassandra']['system']['net_core_optmem_max']
  action :apply
end

sysctl 'net.ipv4.tcp_rmem' do
  value node['cassandra']['system']['net_ipv4_tcp_rmem']
  action :apply
end

sysctl 'net.ipv4.tcp_wmem' do
  value node['cassandra']['system']['net_ipv4_tcp_wmem']
  action :apply
end

sysctl 'net.ipv4.tcp_keepalive_time' do
  value node['cassandra']['system']['net_ipv4_tcp_keepalive_time']
  action :apply
end

sysctl 'net.ipv4.tcp_keepalive_probes' do
  value node['cassandra']['system']['net_ipv4_tcp_keepalive_probes']
  action :apply
end

sysctl 'net.ipv4.tcp_keepalive_intvl' do
  value node['cassandra']['system']['net_ipv4_tcp_keepalive_intvl']
  action :apply
end

sysctl 'net.ipv4.tcp_fin_timeout' do
  value node['cassandra']['system']['net_ipv4_tcp_fin_timeout']
  action :apply
end

sysctl 'net.ipv4.tcp_tw_reuse' do
  value node['cassandra']['system']['net_ipv4_tcp_tw_reuse']
  action :apply
end

sysctl 'net.ipv4.tcp_moderate_rcvbuf' do
  value node['cassandra']['system']['net_ipv4_tcp_moderate_rcvbuf']
  action :apply
end

sysctl 'net.ipv4.tcp_syncookies' do
  value node['cassandra']['system']['net_ipv4_tcp_syncookies']
  action :apply
end

sysctl 'net.ipv4.tcp_max_syn_backlog' do
  value node['cassandra']['system']['net_ipv4_tcp_max_syn_backlog']
  action :apply
end

sysctl 'net.core.somaxconn' do
  value node['cassandra']['system']['net_core_somaxconn']
  action :apply
end

# Use limits.d for setting ulimits (more reliable than ulimit_domain)
template "/etc/security/limits.d/cassandra.conf" do
  source 'cassandra_limits.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    user: node['cassandra']['user'],
    file_limit: node['cassandra']['system']['file_descriptor_limit'],
    memlock_limit: node['cassandra']['system']['memlock_limit'],
    as_limit: node['cassandra']['system']['as_limit'],
    nproc_limit: node['cassandra']['system']['nproc_limit']
  )
  action :create
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
  execute "disable-transparent-hugepage-#{param}" do
    command "echo never > /sys/kernel/mm/transparent_hugepage/#{param}"
    only_if { ::File.exist?("/sys/kernel/mm/transparent_hugepage/#{param}") }
    not_if "grep -q '\\[never\\]' /sys/kernel/mm/transparent_hugepage/#{param}"
  end
end

# Set I/O scheduler for optimal Cassandra performance
ruby_block 'set-io-scheduler' do
  block do
    Dir.glob('/sys/block/*/queue/scheduler').each do |scheduler_file|
      device = scheduler_file.split('/')[3]
      
      # Skip virtual devices
      next if device.start_with?('loop', 'ram', 'dm-')
      
      # Check if device is rotational (HDD) or not (SSD)
      rotational_file = "/sys/block/#{device}/queue/rotational"
      if ::File.exist?(rotational_file)
        is_rotational = ::File.read(rotational_file).strip == '1'
        
        current_scheduler = ::File.read(scheduler_file).strip
        
        # For SSDs use noop/none, for HDDs use deadline
        desired_scheduler = is_rotational ? 'deadline' : 'none'
        
        # Fallback schedulers
        if !current_scheduler.include?(desired_scheduler)
          if desired_scheduler == 'none' && current_scheduler.include?('noop')
            desired_scheduler = 'noop'
          elsif desired_scheduler == 'deadline' && current_scheduler.include?('mq-deadline')
            desired_scheduler = 'mq-deadline'
          end
        end
        
        # Set scheduler if available
        if current_scheduler.include?(desired_scheduler) && !current_scheduler.include?("[#{desired_scheduler}]")
          ::File.write(scheduler_file, desired_scheduler)
          Chef::Log.info("Set I/O scheduler to #{desired_scheduler} for #{device}")
        end
      end
    end
  end
end

# Disable CPU frequency scaling for consistent performance
execute 'set-cpu-performance-governor' do
  command 'for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > $gov 2>/dev/null || true; done'
  only_if { ::File.exist?('/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor') }
end

# Ensure the settings persist across reboots
template '/etc/rc.local' do
  source 'rc.local.erb'
  mode '0755'
  owner 'root'
  group 'root'
  variables(
    cassandra_data_dirs: node['axonops']['cassandra']['data_file_directories'] || ['/var/lib/cassandra/data']
  )
  action :create
end

# Create systemd service to ensure rc.local runs on systems using systemd
systemd_unit 'rc-local.service' do
  content({
    Unit: {
      Description: '/etc/rc.local Compatibility',
      ConditionFileIsExecutable: '/etc/rc.local'
    },
    Service: {
      Type: 'oneshot',
      ExecStart: '/etc/rc.local',
      RemainAfterExit: 'yes'
    },
    Install: {
      WantedBy: 'multi-user.target'
    }
  })
  action [:create, :enable]
  only_if { ::File.exist?('/bin/systemctl') || ::File.exist?('/usr/bin/systemctl') }
end

# Log completion
log 'system_tuning_complete' do
  message 'Cassandra system tuning configuration completed'
  level :info
end