control 'cassandra_yaml_exists' do
  title 'Verify cassandra.yaml exists and has correct permissions'
  describe.one do
    describe file('/etc/cassandra/conf/cassandra.yaml') do
      it { should exist }
      its('mode') { should cmp '0644' }
      its('owner') { should eq 'cassandra' }
    end
    describe file('/opt/cassandra/conf/cassandra.yaml') do
      it { should exist }
      its('mode') { should cmp '0644' }
      its('owner') { should eq 'cassandra' }
    end
  end
end

control 'cassandra_yaml_schema_311' do
  title 'Verify 3.11 schema keys'
  only_if { command('cat /opt/cassandra/conf/cassandra.yaml /etc/cassandra/conf/cassandra.yaml 2>/dev/null').stdout.include?('read_request_timeout_in_ms') }
  describe command('cat /opt/cassandra/conf/cassandra.yaml /etc/cassandra/conf/cassandra.yaml 2>/dev/null') do
    its('stdout') { should match /read_request_timeout_in_ms:/ }
    its('stdout') { should_not match /^read_request_timeout: / }
  end
end

control 'cassandra_yaml_schema_modern' do
  title 'Verify 4.x/5.x schema keys'
  only_if { command('cat /opt/cassandra/conf/cassandra.yaml /etc/cassandra/conf/cassandra.yaml 2>/dev/null').stdout.match?(/^read_request_timeout: /) }
  describe command('cat /opt/cassandra/conf/cassandra.yaml /etc/cassandra/conf/cassandra.yaml 2>/dev/null') do
    its('stdout') { should match /^read_request_timeout:/ }
    its('stdout') { should_not match /read_request_timeout_in_ms:/ }
  end
end

control 'cassandra_yaml_no_rpc_keys_on_41_50' do
  title 'Verify no RPC keys on 4.1+'
  only_if { command('cat /opt/cassandra/conf/cassandra.yaml /etc/cassandra/conf/cassandra.yaml 2>/dev/null').stdout.match?(/^read_request_timeout: /) }
  describe command('cat /opt/cassandra/conf/cassandra.yaml /etc/cassandra/conf/cassandra.yaml 2>/dev/null') do
    its('stdout') { should_not match /start_rpc:/ }
    its('stdout') { should_not match /rpc_port:/ }
  end
end
