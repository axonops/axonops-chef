# InSpec controls — Cassandra 5.0 (default) suite.
# Implements features/cassandra_install.feature ("5.0 tarball install").

cassandra_home = '/opt/cassandra'
conf = "#{cassandra_home}/conf/cassandra.yaml"

control 'cassandra-5.0-java17' do
  impact 1.0
  title 'Java 17 is installed for Cassandra 5.0'

  describe command('java -version') do
    its('stderr') { should match(/version "17/) }
  end
end

control 'cassandra-5.0-layout' do
  impact 1.0
  title 'Cassandra 5.0 is laid out with the Java 17 JVM option files'

  describe file(conf) do
    it { should exist }
    its('owner') { should eq 'cassandra' }
  end

  describe file("#{cassandra_home}/conf/jvm-server.options") do
    it { should exist }
  end

  describe file("#{cassandra_home}/conf/jvm17-server.options") do
    it { should exist }
  end

  describe yaml(conf) do
    its(%w(sstable selected_format)) { should cmp 'bti' }
  end
end

control 'cassandra-5.0-service' do
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
