# InSpec controls — Cassandra 3.11 suite.
# Implements features/cassandra_install.feature ("3.11 tarball install") and
# the legacy-schema scenarios of features/cassandra_version_support.feature.

cassandra_home = '/opt/cassandra'
conf = "#{cassandra_home}/conf/cassandra.yaml"

control 'cassandra-3.11-java8' do
  impact 1.0
  title 'Java 8 is installed for Cassandra 3.11'
  desc 'Cassandra 3.11 requires Java 8.'

  describe command('java -version') do
    its('stderr') { should match(/version "(1\.8\.|8)/) }
  end
end

control 'cassandra-3.11-layout' do
  impact 1.0
  title 'Cassandra 3.11 is laid out and owned correctly'

  describe file(cassandra_home) do
    it { should be_symlink }
  end

  describe file(conf) do
    it { should exist }
    its('owner') { should eq 'cassandra' }
    its('group') { should eq 'cassandra' }
  end

  describe file("#{cassandra_home}/conf/jvm.options") do
    it { should exist }
  end

  describe group('cassandra') do
    it { should exist }
  end

  describe user('cassandra') do
    it { should exist }
  end
end

control 'cassandra-3.11-legacy-schema' do
  impact 1.0
  title 'cassandra.yaml uses the legacy 3.11 integer-unit schema'

  describe file(conf) do
    its('content') { should match(/^read_request_timeout_in_ms:\s*5000/) }
    its('content') { should match(/^commitlog_segment_size_in_mb:\s*32/) }
    its('content') { should match(/^start_rpc:\s*false/) }
    its('content') { should_not match(/selected_format/) }
    its('content') { should_not match(/allocate_tokens_for_local_replication_factor/) }
  end

  describe yaml(conf) do
    its(['read_request_timeout_in_ms']) { should cmp 5000 }
    its(['num_tokens']) { should cmp 16 }
  end
end

control 'cassandra-3.11-service' do
  impact 1.0
  title 'The cassandra service is enabled and running'

  describe service('cassandra') do
    it { should be_enabled }
    it { should be_running }
  end

  describe port(9042) do
    it { should be_listening }
  end
end
