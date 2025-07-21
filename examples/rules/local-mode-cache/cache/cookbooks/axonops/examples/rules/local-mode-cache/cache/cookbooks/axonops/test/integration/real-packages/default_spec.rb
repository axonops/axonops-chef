# InSpec tests for real AxonOps packages

# Test that packages are installed
describe package('axon-server') do
  it { should be_installed }
end

describe package('axon-dash') do
  it { should be_installed }
end

describe package('axon-agent') do
  it { should be_installed }
end

# Test that services are running
describe service('axon-server') do
  it { should be_enabled }
  it { should be_running }
end

describe service('axon-dash') do
  it { should be_enabled }
  it { should be_running }
end

describe service('axon-agent') do
  it { should be_enabled }
  it { should be_running }
end

# Test that ports are listening
describe port(8080) do
  it { should be_listening }
  its('protocols') { should include 'tcp' }
end

describe port(3000) do
  it { should be_listening }
  its('protocols') { should include 'tcp' }
end

# Test configuration files
describe file('/etc/axonops/axon-server.yml') do
  it { should exist }
  it { should be_file }
  it { should be_owned_by 'axonops' }
  it { should be_grouped_into 'axonops' }
  its('mode') { should cmp '0640' }
end

describe file('/etc/axonops/axon-dash.yml') do
  it { should exist }
  it { should be_file }
  it { should be_owned_by 'axonops' }
  it { should be_grouped_into 'axonops' }
  its('mode') { should cmp '0640' }
end

describe file('/etc/axonops/axon-agent.yml') do
  it { should exist }
  it { should be_file }
  it { should be_owned_by 'axonops' }
  it { should be_grouped_into 'axonops' }
  its('mode') { should cmp '0640' }
end

# Test API endpoints
describe http('http://localhost:8080/api/v1/health') do
  its('status') { should eq 200 }
  its('body') { should match /healthy|ok/i }
end

describe http('http://localhost:3000') do
  its('status') { should eq 200 }
end

# Test Java agent installation
describe command('dpkg -l | grep axon-cassandra') do
  its('exit_status') { should eq 0 }
  its('stdout') { should match /axon-cassandra.*agent/ }
end

# Test Java agent JAR exists
describe file('/usr/share/axonops/axon-cassandra5.0-agent.jar') do
  it { should exist }
  it { should be_file }
end

# Test Cassandra JVM options include agent
describe file('/etc/cassandra/jvm-server.options') do
  its('content') { should match %r{-javaagent:/usr/share/axonops/axon-cassandra.*\.jar} }
end

# Test processes are running
describe processes('java') do
  its('commands') { should match [/axon-server/] }
  its('commands') { should match [/axon-agent/] }
end

# Test log files
describe file('/var/log/axonops/axon-server.log') do
  it { should exist }
  it { should be_file }
end

describe file('/var/log/axonops/axon-agent.log') do
  it { should exist }
  it { should be_file }
end