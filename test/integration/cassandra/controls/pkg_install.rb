control 'cassandra_apt_repo' do
  title 'Verify Cassandra APT repo'
  only_if { os.debian? }
  describe file('/etc/apt/sources.list.d/cassandra.list') do
    its('content') { should match /debian\.cassandra\.apache\.org/ }
  end
end

control 'cassandra_pkg_installed' do
  title 'Verify Cassandra package installed'
  only_if { os.debian? }
  describe package('cassandra') do
    it { should be_installed }
  end
end

control 'cassandra_pkg_held' do
  title 'Verify Cassandra package is held'
  only_if { os.debian? }
  describe command('apt-mark showhold') do
    its('stdout') { should match /cassandra/ }
  end
end

control 'cassandra_conf_dir_pkg' do
  title 'Verify config directory for package install'
  only_if { os.debian? }
  describe file('/etc/cassandra') do
    it { should be_directory }
  end
end
