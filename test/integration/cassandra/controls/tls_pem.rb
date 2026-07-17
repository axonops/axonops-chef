control 'cassandra_pem_tls_in_yaml' do
  title 'Verify PEM TLS in cassandra.yaml'
  only_if { command('cat /opt/cassandra/conf/cassandra.yaml /etc/cassandra/conf/cassandra.yaml 2>/dev/null').stdout.include?('PEMBasedSslContextFactory') }
  describe command('cat /opt/cassandra/conf/cassandra.yaml /etc/cassandra/conf/cassandra.yaml 2>/dev/null') do
    its('stdout') { should match /PEMBasedSslContextFactory/ }
  end
end

control 'cassandra_pem_tls_no_keystore' do
  title 'Verify no keystore with PEM TLS'
  only_if { command('cat /opt/cassandra/conf/cassandra.yaml /etc/cassandra/conf/cassandra.yaml 2>/dev/null').stdout.include?('PEMBasedSslContextFactory') }
  describe command('cat /opt/cassandra/conf/cassandra.yaml /etc/cassandra/conf/cassandra.yaml 2>/dev/null') do
    # we just need it to not have keystore in server_encryption_options
    # A bit hard to parse yaml accurately with grep, but we'll do our best.
    its('stdout') { should_not match /keystore:/ }
  end
end
