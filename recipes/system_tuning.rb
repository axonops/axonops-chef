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

# Swap is disabled outright (swapoff + /etc/fstab) further down unless the
# operator opts out, so vm.swappiness is only meaningful on hosts that keep
# swap. Write it only there, rather than implying swappiness is the mechanism.
disable_swap = node['axonops']['disable_swap'] && !node['axonops']['skip_vm_swappiness']

sysctl_content = <<~SYSCTL
  #{disable_swap ? '' : "vm.swappiness=1\n"}vm.overcommit_memory=1
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

# /etc/sysctl.d normally ships with procps/systemd, but minimal container
# base images can lack it, and this recipe can run before axonops::common
# (which also writes here) in the include order.
directory '/etc/sysctl.d' do
  recursive true
end

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

# ---------------------------------------------------------------------------
# Transparent Huge Pages
#
# THP is not a sysctl — it lives in /sys/kernel/mm/transparent_hugepage. Set it
# now for the running kernel and install a systemd unit so it survives reboot.
# A systemd unit is used rather than a GRUB kernel argument or a tuned profile
# because it needs no bootloader rewrite, no reboot to take effect, and no
# tuned dependency on the minimal images this cookbook targets.
# ---------------------------------------------------------------------------
thp_enabled_path = '/sys/kernel/mm/transparent_hugepage/enabled'
thp_defrag_path = '/sys/kernel/mm/transparent_hugepage/defrag'
manage_thp = node['axonops']['disable_transparent_hugepages'] && !running_in_container

# The knobs render as e.g. "always madvise [never]" — the bracketed value is
# the active one, so this is a true idempotency guard, not a file-exists check.
thp_already_never = lambda do
  [thp_enabled_path, thp_defrag_path].all? do |path|
    !::File.exist?(path) || ::File.read(path).include?('[never]')
  end
end

# Plain redirections, no shell variables: the identical command string is
# reused as the systemd ExecStart below, where a `$var` would be eaten by
# systemd's own variable expansion.
thp_command = "echo never > #{thp_enabled_path} 2>/dev/null; " \
              "echo never > #{thp_defrag_path} 2>/dev/null; true"

execute 'disable transparent hugepages (running kernel)' do
  command thp_command
  only_if { manage_thp && ::File.exist?(thp_enabled_path) }
  not_if(&thp_already_never)
end

systemd_unit 'disable-transparent-hugepages.service' do
  content(
    'Unit' => {
      'Description' => 'Disable Transparent Huge Pages (Cassandra tuning)',
      'DefaultDependencies' => 'no',
      'After' => 'sysinit.target local-fs.target',
      'Before' => 'basic.target',
    },
    'Service' => {
      'Type' => 'oneshot',
      'RemainAfterExit' => 'yes',
      'ExecStart' => "/bin/sh -c \"#{thp_command}\"",
    },
    'Install' => { 'WantedBy' => 'basic.target' }
  )
  action %i(create enable)
  only_if { manage_thp }
end

# ---------------------------------------------------------------------------
# Swap
#
# Cassandra must never swap: a swapped-out node stays in the ring while its
# latency collapses, which is worse than the node being down. vm.swappiness=1
# only makes swapping unlikely — turn it off instead, and keep it off across
# reboots by commenting out the swap entries in /etc/fstab.
# ---------------------------------------------------------------------------
manage_swap = disable_swap && !running_in_container

log 'skip_vm_swappiness_deprecated' do
  message 'node["axonops"]["skip_vm_swappiness"] is deprecated: swap is now ' \
          'disabled entirely. Use node["axonops"]["disable_swap"] = false ' \
          'instead; skip_vm_swappiness will be removed in a future release.'
  level :warn
  only_if { node['axonops']['skip_vm_swappiness'] }
end

execute 'swapoff -a' do
  command 'swapoff -a'
  only_if { manage_swap }
  # /proc/swaps always carries a header line; a second line means swap is on.
  only_if { ::File.exist?('/proc/swaps') && ::File.readlines('/proc/swaps').length > 1 }
end

fstab_swap_line = /^\s*[^#\s]\S*\s+\S+\s+swap\s/

ruby_block 'comment out swap entries in /etc/fstab' do
  block do
    lines = ::File.readlines('/etc/fstab')
    updated = lines.map do |line|
      line.match?(fstab_swap_line) ? "# Disabled by axonops::system_tuning: #{line}" : line
    end
    ::File.write('/etc/fstab', updated.join)
  end
  only_if { manage_swap }
  only_if do
    ::File.exist?('/etc/fstab') && ::File.readlines('/etc/fstab').any? { |l| l.match?(fstab_swap_line) }
  end
end

# /etc/security/limits.d normally ships with pam/shadow-utils, but minimal
# container base images can lack it (same reasoning as /etc/sysctl.d above).
directory '/etc/security/limits.d' do
  recursive true
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
  # /etc/default normally ships with the base OS, but minimal container
  # images can lack it (same reasoning as /etc/sysctl.d above).
  directory '/etc/default' do
    recursive true
  end

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
