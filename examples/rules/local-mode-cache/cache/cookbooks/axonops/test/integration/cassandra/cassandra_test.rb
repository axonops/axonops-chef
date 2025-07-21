# InSpec test for recipe axonops::cassandra

control 'cassandra-installation' do
  impact 1.0
  title 'Apache Cassandra Installation'
  desc 'Verify Apache Cassandra 5.0 is properly installed'

  describe user('cassandra') do
    it { should exist }
    its('group') { should eq 'cassandra' }
    its('shell') { should eq '/bin/false' }
    its('home') { should eq '/var/lib/cassandra' }
  end

  describe group('cassandra') do
    it { should exist }
  end

  # Verify Cassandra binary exists
  describe file('/opt/cassandra/bin/cassandra') do
    it { should exist }
    it { should be_executable }
    its('owner') { should eq 'cassandra' }
  end

  # Data directories
  %w(
    /data/cassandra/data
    /data/cassandra/hints
    /data/cassandra/saved_caches
    /data/cassandra/commitlog
    /var/log/cassandra
    /etc/cassandra
    /var/lib/cassandra
  ).each do |dir|
    describe directory(dir) do
      it { should exist }
      its('owner') { should eq 'cassandra' }
      its('group') { should eq 'cassandra' }
      its('mode') { should cmp '0755' }
    end
  end
end

control 'cassandra-configuration' do
  impact 1.0
  title 'Cassandra Configuration'
  desc 'Verify Cassandra configuration files'

  describe file('/etc/cassandra/cassandra.yaml') do
    it { should exist }
    its('owner') { should eq 'cassandra' }
    its('group') { should eq 'cassandra' }
    its('mode') { should cmp '0644' }

    # Core settings
    its('content') { should match /cluster_name:/ }
    its('content') { should match /num_tokens: 16/ }
    its('content') { should match %r{data_file_directories:\s*\n\s*- /data/cassandra/data} }
    its('content') { should match %r{commitlog_directory: /data/cassandra/commitlog} }
    its('content') { should match %r{saved_caches_directory: /data/cassandra/saved_caches} }
    its('content') { should match %r{hints_directory: /data/cassandra/hints} }

    # Network settings
    its('content') { should match /listen_address:/ }
    its('content') { should match /rpc_address:/ }
    its('content') { should match /native_transport_port: 9042/ }
    its('content') { should match /storage_port: 7000/ }
  end

  describe file('/etc/cassandra/cassandra-env.sh') do
    it { should exist }
    its('owner') { should eq 'cassandra' }
    its('content') { should match /JVM_OPTS/ }
    its('content') { should match /-Xmx/ }
    its('content') { should match /-Xms/ }
  end

  describe file('/etc/cassandra/jvm.options') do
    it { should exist }
    its('owner') { should eq 'cassandra' }
  end

  describe file('/etc/cassandra/logback.xml') do
    it { should exist }
    its('owner') { should eq 'cassandra' }
  end
end

control 'cassandra-service' do
  impact 1.0
  title 'Cassandra Service'
  desc 'Verify Cassandra service is running'

  describe systemd_service('cassandra') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  # Native transport
  describe port(9042) do
    it { should be_listening }
    its('protocols') { should include 'tcp' }
  end

  # Storage port
  describe port(7000) do
    it { should be_listening }
    its('protocols') { should include 'tcp' }
  end

  # JMX port (should only bind to localhost)
  describe port(7199) do
    it { should be_listening }
    its('addresses') { should include '127.0.0.1' }
    its('addresses') { should_not include '0.0.0.0' }
  end
end

control 'cassandra-functionality' do
  impact 1.0
  title 'Cassandra Functionality'
  desc 'Verify Cassandra is functioning correctly'

  describe command('nodetool status') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match /^UN/ } # Node should be Up and Normal
  end

  describe command('nodetool info') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match /Gossip active\s+: true/ }
    its('stdout') { should match /Native Transport active: true/ }
  end

  describe command('cqlsh -e "SELECT cluster_name FROM system.local" localhost 9042') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match /cluster_name/ }
  end

  # Test keyspace creation
  describe command(<<-CMD) do
    cqlsh -e "CREATE KEYSPACE IF NOT EXISTS test_inspec WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};" localhost 9042
  CMD
    its('exit_status') { should eq 0 }
  end

  # Verify keyspace exists
  describe command('cqlsh -e "DESCRIBE KEYSPACE test_inspec" localhost 9042') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match /CREATE KEYSPACE test_inspec/ }
  end

  # Cleanup
  describe command('cqlsh -e "DROP KEYSPACE IF EXISTS test_inspec" localhost 9042') do
    its('exit_status') { should eq 0 }
  end
end

control 'cassandra-performance' do
  impact 0.7
  title 'Cassandra Performance Settings'
  desc 'Verify performance configurations'

  # System settings
  describe command('sysctl vm.max_map_count') do
    its('stdout') { should match /vm.max_map_count = 1048575/ }
  end

  describe command('sysctl net.ipv4.tcp_keepalive_time') do
    its('stdout') { should match /net.ipv4.tcp_keepalive_time = 60/ }
  end

  # Process limits
  describe command('cat /proc/$(pgrep -f CassandraDaemon)/limits') do
    its('stdout') { should match /Max open files\s+100000\s+100000/ }
    its('stdout') { should match /Max processes\s+32768\s+32768/ }
  end

  # JVM settings verification
  describe command('ps aux | grep -i cassandra | grep -v grep') do
    its('stdout') { should match /-XX:\+UseG1GC/ }
    its('stdout') { should match /-XX:MaxGCPauseMillis=/ }
  end
end

control 'cassandra-security' do
  impact 0.8
  title 'Cassandra Security'
  desc 'Verify security configurations'
  only_if { node['cassandra']['authenticator'] == 'PasswordAuthenticator' }

  describe file('/etc/cassandra/cassandra.yaml') do
    its('content') { should match /authenticator: PasswordAuthenticator/ }
    its('content') { should match /authorizer: CassandraAuthorizer/ }
  end

  # Default credentials should be changed
  describe command('cqlsh -u cassandra -p cassandra localhost 9042 -e "SELECT * FROM system.local"') do
    its('exit_status') { should_not eq 0 }
  end

  # SSL/TLS configuration
  describe file('/etc/cassandra/cassandra.yaml') do
    its('content') { should match /client_encryption_options:/ }
    its('content') { should match /enabled: true/ }
    its('content') { should match /keystore:/ }
    its('content') { should match /truststore:/ }
  end if node['cassandra']['client_encryption_enabled']

  describe file(node['cassandra']['ssl_keystore_path']) do
    it { should exist }
    its('owner') { should eq 'cassandra' }
    its('mode') { should cmp '0600' }
  end if node['cassandra']['client_encryption_enabled']
end

control 'cassandra-logging' do
  impact 0.5
  title 'Cassandra Logging'
  desc 'Verify logging configuration'

  describe file('/var/log/cassandra/system.log') do
    it { should exist }
    its('owner') { should eq 'cassandra' }
    its('group') { should eq 'cassandra' }
  end

  describe file('/var/log/cassandra/debug.log') do
    it { should exist }
    its('owner') { should eq 'cassandra' }
  end

  # Log rotation
  describe file('/etc/logrotate.d/cassandra') do
    it { should exist }
    its('content') { should match %r{/var/log/cassandra/\*.log} }
    its('content') { should match /daily/ }
    its('content') { should match /rotate 7/ }
  end
end

control 'cassandra-monitoring' do
  impact 0.6
  title 'Cassandra Monitoring'
  desc 'Verify monitoring capabilities'

  # JMX should be accessible locally
  describe command('echo "beans" | java -jar /usr/share/cassandra/lib/jmx_prometheus_javaagent.jar 2>/dev/null') do
    its('exit_status') { should eq 0 }
  end if File.exist?('/usr/share/cassandra/lib/jmx_prometheus_javaagent.jar')

  # Verify metrics are available
  describe command('nodetool tablestats system') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match /Keyspace : system/ }
  end

  # Check if AxonOps agent is monitoring this instance
  describe file('/opt/cassandra/conf/cassandra-env.sh') do
    its('content') { should match /axon-cassandra-agent\.jar/ }
  end if node['axonops']['agent']['enabled']
end

control 'cassandra-backup-readiness' do
  impact 0.5
  title 'Cassandra Backup Readiness'
  desc 'Verify backup configurations'

  # Snapshot directory should exist
  describe directory('/data/cassandra/data') do
    it { should exist }
    it { should be_writable.by('owner') }
  end

  # Test snapshot capability
  describe command('nodetool snapshot --tag test-snapshot') do
    its('exit_status') { should eq 0 }
  end

  # Cleanup test snapshot
  describe command('nodetool clearsnapshot -t test-snapshot') do
    its('exit_status') { should eq 0 }
  end
end
