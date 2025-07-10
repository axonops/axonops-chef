# InSpec test for recipe axonops::agent_test

control 'axonops-agent-test-installation' do
  impact 1.0
  title 'AxonOps Agent Test Installation'
  desc 'Verify AxonOps agent test recipe properly installed and configured'

  # Test recipe creates a dummy binary instead of installing package
  describe file('/usr/bin/axon-agent') do
    it { should exist }
    it { should be_executable }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
  end

  describe user('axonops') do
    it { should exist }
    its('group') { should eq 'axonops' }
    its('shell') { should eq '/bin/false' }
    its('home') { should eq '/var/lib/axonops' }
  end

  describe group('axonops') do
    it { should exist }
  end

  %w(
    /etc/axonops
    /var/log/axonops
    /var/lib/axonops
    /usr/share/axonops
  ).each do |dir|
    describe directory(dir) do
      it { should exist }
      its('owner') { should eq 'axonops' }
      its('group') { should eq 'axonops' }
      its('mode') { should cmp '0755' }
    end
  end
end

control 'axonops-agent-test-configuration' do
  impact 1.0
  title 'AxonOps Agent Test Configuration'
  desc 'Verify agent configuration files'

  describe file('/etc/axonops/axon-agent.yml') do
    it { should exist }
    its('owner') { should eq 'axonops' }
    its('group') { should eq 'axonops' }
    its('mode') { should cmp '0600' }
    its('content') { should match /api_key: "test-agent-key"/ }
    its('content') { should match /organisation: "test-org"/ }
    its('content') { should match /agents\.axonops\.cloud/ }
  end

  describe file('/etc/systemd/system/axon-agent.service') do
    it { should exist }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('content') { should match /Description=AxonOps Agent \(Test\)/ }
    its('content') { should match /User=axonops/ }
    its('content') { should match /Group=axonops/ }
  end
end

control 'axonops-agent-test-cassandra-detection' do
  impact 0.7
  title 'Cassandra Detection'
  desc 'Verify agent cassandra detection'

  describe file('/etc/axonops/.cassandra_detected') do
    it { should exist }
    its('content') { should match /false/ }
  end
end
