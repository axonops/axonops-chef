control 'cassandra_java_version' do
  title 'Verify Java version for Cassandra'
  describe command('java -version') do
    its('stderr') { should match /version "(1\.8|11\.|17\.)/ }
  end
end
