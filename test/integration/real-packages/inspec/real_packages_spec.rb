# InSpec test for real AxonOps packages

# Test that AxonOps user and group exist
describe group('axonops') do
  it { should exist }
end

describe user('axonops') do
  it { should exist }
  its('group') { should eq 'axonops' }
  its('home') { should eq '/var/lib/axonops' }
end

# Test that directories are created with correct permissions
%w[
  /etc/axonops
  /var/log/axonops
  /var/lib/axonops
  /opt/axonops
  /usr/share/axonops
].each do |dir|
  describe directory(dir) do
    it { should exist }
    its('owner') { should eq 'axonops' }
    its('group') { should eq 'axonops' }
    its('mode') { should cmp '0775' }
  end
end

# Test that packages are installed (even if forced)
describe command('dpkg -l | grep axon-server') do
  its('stdout') { should match(/axon-server/) }
end

describe command('dpkg -l | grep axon-dash') do
  its('stdout') { should match(/axon-dash/) }
end

describe command('dpkg -l | grep axon-agent') do
  its('stdout') { should match(/axon-agent/) }
end

# Test that configuration files exist
describe file('/etc/axonops/axon-server.yml') do
  it { should exist }
  its('owner') { should eq 'axonops' }
  its('group') { should eq 'axonops' }
  its('mode') { should cmp '0640' }
  its('content') { should match(/listen_address: 0.0.0.0/) }
  its('content') { should match(/listen_port: 8080/) }
end

describe file('/etc/axonops/axon-dash.yml') do
  it { should exist }
  its('owner') { should eq 'axonops' }
  its('group') { should eq 'axonops' }
  its('mode') { should cmp '0640' }
  its('content') { should match(/listen_port: 3000/) }
  its('content') { should match(/server_endpoint: http:\/\/localhost:8080/) }
end

describe file('/etc/axonops/axon-agent.yml') do
  it { should exist }
  its('owner') { should eq 'axonops' }
  its('group') { should eq 'axonops' }
  its('mode') { should cmp '0640' }
  its('content') { should match(/hosts: \["localhost:8080"\]/) }
end

# Test that systemd services are enabled
describe systemd_service('axon-server') do
  it { should be_installed }
  it { should be_enabled }
  # Note: May not be running due to architecture mismatch
end

describe systemd_service('axon-dash') do
  it { should be_installed }
  it { should be_enabled }
end

describe systemd_service('axon-agent') do
  it { should be_installed }
  it { should be_enabled }
end

# Test system limits
describe file('/etc/security/limits.d/axonops.conf') do
  it { should exist }
  its('content') { should match(/axonops soft nofile 100000/) }
  its('content') { should match(/axonops hard nofile 100000/) }
end

# Test sysctl settings
describe file('/etc/sysctl.d/99-axonops.conf') do
  it { should exist }
  its('content') { should match(/vm.max_map_count=1048575/) }
end

# Check if binaries exist (even if they can't run)
describe file('/usr/bin/axon-server') do
  it { should exist }
  it { should be_executable }
end

describe file('/usr/bin/axon-dash') do
  it { should exist }
  it { should be_executable }
end

describe file('/usr/bin/axon-agent') do
  it { should exist }
  it { should be_executable }
end