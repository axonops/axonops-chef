# InSpec test for recipe axonops::server

control 'axonops-server-installation' do
  impact 1.0
  title 'AxonOps Server Installation'
  desc 'Verify AxonOps server is properly installed and configured'

  describe package('axon-server') do
    it { should be_installed }
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
    /var/lib/axonops/data
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

control 'axonops-server-dependencies' do
  impact 1.0
  title 'AxonOps Server Dependencies'
  desc 'Verify required dependencies are installed'

  # Java should be installed
  describe command('java -version') do
    its('exit_status') { should eq 0 }
    its('stderr') { should match /17\.\d+/ }
  end

  # Elasticsearch should be running for AxonOps config storage
  describe service('elasticsearch') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  describe port(9200) do
    it { should be_listening }
    its('protocols') { should include 'tcp' }
  end

  # Cassandra should be running for AxonOps metrics storage
  describe service('cassandra') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  describe port(9042) do
    it { should be_listening }
    its('protocols') { should include 'tcp' }
  end
end

control 'axonops-server-configuration' do
  impact 1.0
  title 'AxonOps Server Configuration'
  desc 'Verify server configuration files'

  describe file('/etc/axonops/axon-server.yml') do
    it { should exist }
    its('owner') { should eq 'axonops' }
    its('group') { should eq 'axonops' }
    its('mode') { should cmp '0600' }
    its('content') { should match /listen_address:/ }
    its('content') { should match /listen_port:/ }
    its('content') { should match /cassandra:/ }
    its('content') { should match /elasticsearch:/ }
  end

  describe file('/etc/axonops/logback.xml') do
    it { should exist }
    its('owner') { should eq 'axonops' }
    its('group') { should eq 'axonops' }
  end
end

control 'axonops-server-service' do
  impact 1.0
  title 'AxonOps Server Service'
  desc 'Verify server service is running'

  describe systemd_service('axon-server') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  describe port(8080) do
    it { should be_listening }
    its('protocols') { should include 'tcp' }
  end

  describe port(9000) do
    it { should be_listening }
    its('protocols') { should include 'tcp' }
  end

  describe file('/etc/systemd/system/axon-server.service.d/override.conf') do
    it { should exist }
    its('content') { should match /LimitNOFILE=65536/ }
  end
end

control 'axonops-server-health' do
  impact 0.8
  title 'AxonOps Server Health Check'
  desc 'Verify server is healthy and responding'

  describe http('http://localhost:8080/health') do
    its('status') { should eq 200 }
    its('body') { should match /healthy|ok/i }
  end

  describe http('http://localhost:8080/api/v1/ping') do
    its('status') { should eq 200 }
  end

  # Verify server can connect to its storage backends
  describe command('curl -s http://localhost:9200/_cluster/health | jq -r .status') do
    its('stdout') { should match /green|yellow/ }
  end

  describe command('cqlsh -e "SELECT cluster_name FROM system.local" localhost 9042') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match /AxonOps Cluster/ }
  end
end

control 'axonops-server-security' do
  impact 0.9
  title 'AxonOps Server Security'
  desc 'Verify security configurations'

  # SSL/TLS configuration
  describe file('/etc/axonops/ssl/server.crt') do
    it { should exist }
    its('owner') { should eq 'axonops' }
    its('mode') { should cmp '0600' }
  end

  describe file('/etc/axonops/ssl/server.key') do
    it { should exist }
    its('owner') { should eq 'axonops' }
    its('mode') { should cmp '0600' }
  end

  # Authentication should be enabled
  describe file('/etc/axonops/axon-server.yml') do
    its('content') { should match /auth_enabled: true/ }
    its('content') { should match /require_api_key: true/ }
  end

  # Ensure default credentials are changed
  describe http('http://localhost:8080/api/v1/auth/login',
    method: 'POST',
    headers: { 'Content-Type' => 'application/json' },
    data: '{"username":"admin","password":"admin"}') do
    its('status') { should_not eq 200 }
  end
end

control 'axonops-server-logging' do
  impact 0.5
  title 'AxonOps Server Logging'
  desc 'Verify logging is configured correctly'

  describe file('/var/log/axonops/axon-server.log') do
    it { should exist }
    its('owner') { should eq 'axonops' }
    its('group') { should eq 'axonops' }
  end

  # Log rotation should be configured
  describe file('/etc/logrotate.d/axonops') do
    it { should exist }
    its('content') { should match %r{/var/log/axonops/\*.log} }
    its('content') { should match /daily/ }
    its('content') { should match /rotate 7/ }
    its('content') { should match /compress/ }
  end
end

control 'axonops-server-performance' do
  impact 0.7
  title 'AxonOps Server Performance'
  desc 'Verify performance configurations'

  # JVM heap settings
  describe file('/etc/axonops/axon-server.env') do
    its('content') { should match /-Xmx/ }
    its('content') { should match /-Xms/ }
  end

  # Connection pool settings
  describe file('/etc/axonops/axon-server.yml') do
    its('content') { should match /max_connections:/ }
    its('content') { should match /connection_timeout:/ }
  end
end

# Integration tests for multi-node setup
control 'axonops-server-cluster' do
  impact 0.8
  title 'AxonOps Server Clustering'
  desc 'Verify server clustering configuration'
  only_if { node['axonops']['server']['cluster_enabled'] }

  describe file('/etc/axonops/axon-server.yml') do
    its('content') { should match /cluster_enabled: true/ }
    its('content') { should match /cluster_nodes:/ }
  end

  # Hazelcast clustering port
  describe port(5701) do
    it { should be_listening }
  end
end
