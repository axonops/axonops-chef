control 'cassandra_sysctl_file' do
  title 'Verify sysctl settings'
  describe file('/etc/sysctl.d/99-cassandra.conf') do
    it { should exist }
    its('content') { should match /vm\.swappiness\s*=\s*1/ }
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
