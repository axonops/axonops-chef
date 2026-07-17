control 'cassandra_jvm_option_files_311' do
  title 'Verify 3.11 JVM option files'
  only_if { file('/opt/cassandra/conf/jvm.options').exist? }
  describe file('/opt/cassandra/conf/jvm.options') do
    it { should exist }
  end
  describe file('/opt/cassandra/conf/jvm-server.options') do
    it { should_not exist }
  end
end

control 'cassandra_jvm_option_files_41' do
  title 'Verify 4.1 JVM option files'
  only_if { file('/opt/cassandra/conf/jvm11-server.options').exist? && !file('/opt/cassandra/conf/jvm17-server.options').exist? }
  describe file('/opt/cassandra/conf/jvm-server.options') do
    it { should exist }
  end
  describe file('/opt/cassandra/conf/jvm11-server.options') do
    it { should exist }
  end
  describe file('/opt/cassandra/conf/jvm-clients.options') do
    it { should exist }
  end
  describe file('/opt/cassandra/conf/jvm11-clients.options') do
    it { should exist }
  end
end

control 'cassandra_jvm_option_files_50' do
  title 'Verify 5.0 JVM option files'
  only_if { file('/opt/cassandra/conf/jvm17-server.options').exist? }
  describe file('/opt/cassandra/conf/jvm-server.options') do
    it { should exist }
  end
  describe file('/opt/cassandra/conf/jvm11-server.options') do
    it { should exist }
  end
  describe file('/opt/cassandra/conf/jvm17-server.options') do
    it { should exist }
  end
  describe file('/opt/cassandra/conf/jvm-clients.options') do
    it { should exist }
  end
  describe file('/opt/cassandra/conf/jvm11-clients.options') do
    it { should exist }
  end
  describe file('/opt/cassandra/conf/jvm17-clients.options') do
    it { should exist }
  end
end
