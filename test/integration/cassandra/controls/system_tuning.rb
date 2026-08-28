control 'cassandra_sysctl_file' do
  title 'Verify sysctl settings'
  describe file('/etc/sysctl.d/99-cassandra.conf') do
    it { should exist }
    its('content') { should match /vm\.overcommit_memory\s*=\s*1/ }
    its('content') { should match /vm\.max_map_count\s*=\s*1048575/ }
    # Swap is disabled outright, so swappiness is not the mechanism any more.
    its('content') { should_not match /vm\.swappiness/ }
  end
end

control 'cassandra_thp_disabled' do
  title 'Verify transparent huge pages are disabled and stay disabled'
  # Skipped in containers: /sys is read-only and shared with the host.
  only_if('not applicable inside a container') { !file('/.dockerenv').exist? }

  describe file('/sys/kernel/mm/transparent_hugepage/enabled') do
    its('content') { should match(/\[never\]/) }
  end

  describe file('/sys/kernel/mm/transparent_hugepage/defrag') do
    its('content') { should match(/\[never\]/) }
  end

  # Survives reboot.
  describe systemd_service('disable-transparent-hugepages') do
    it { should be_enabled }
  end
end

control 'cassandra_swap_disabled' do
  title 'Verify swap is off now and after a reboot'
  only_if('not applicable inside a container') { !file('/.dockerenv').exist? }

  describe command('swapon --show') do
    its('stdout') { should be_empty }
  end

  describe file('/etc/fstab') do
    its('content') { should_not match(/^\s*[^#\s]\S*\s+\S+\s+swap\s/) }
  end
end

control 'cassandra_limits_file' do
  title 'Verify limits settings'
  describe file('/etc/security/limits.d/cassandra.conf') do
    its('content') { should match /nofile\s+(?:1000000|[1-9]\d{6,})/ }
  end
end

control 'cassandra_irqbalance_disabled' do
  title 'Verify irqbalance disabled'
  describe file('/etc/default/irqbalance') do
    its('content') { should match /ENABLED="0"/ }
  end
end
