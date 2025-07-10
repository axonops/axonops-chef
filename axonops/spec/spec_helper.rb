require 'chefspec'
# Berkshelf is not used in this cookbook

RSpec.configure do |config|
  config.color = true
  config.formatter = :documentation
  config.log_level = :error

  # Set default platform and version for tests
  config.platform = 'ubuntu'
  config.version = '20.04'

  # Set Chef file cache path for testing
  config.file_cache_path = '/tmp/chef-cache'
end

# Common helper methods
def stub_command(command, result = true)
  allow_any_instance_of(Chef::Recipe).to receive(:shell_out).with(command).and_return(
    double(stdout: '', stderr: '', exitstatus: result ? 0 : 1)
  )
end

# Shared contexts
RSpec.shared_context 'chef_run' do
  let(:chef_run) do
    ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '20.04') do |node|
      # Set common node attributes for testing
      node.automatic['memory']['total'] = '8388608kB'
      node.automatic['cpu']['total'] = 4
      node.automatic['ipaddress'] = '10.0.0.1'
      node.automatic['hostname'] = 'test-node'
      node.automatic['lsb']['codename'] = 'focal'
      node.automatic['kernel']['machine'] = 'x86_64'
      node.automatic['platform_family'] = 'debian'

      # Merge any provided attributes
      node.override.merge!(node_attributes) if defined?(node_attributes)
    end.converge(described_recipe)
  end

  before do
    # Stub common commands
    stub_command('which java')
    stub_command('java -version')
    stub_command('systemctl daemon-reload')

    # Stub file existence checks
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with('/opt/cassandra/bin/cassandra').and_return(false)
    allow(File).to receive(:exist?).with('/usr/share/cassandra/bin/cassandra').and_return(false)
    allow(File).to receive(:exist?).with('/opt/axonops-packages/axon-agent_2.0.4_amd64.deb').and_return(true)
    allow(File).to receive(:exist?).with('/opt/axonops-packages/axon-server_1.0.0_amd64.deb').and_return(true)
    allow(File).to receive(:exist?).with('/opt/axonops-packages/axon-dash_1.0.0_amd64.deb').and_return(true)
    allow(File).to receive(:exist?).with('/opt/axonops-packages/axon-cassandra5.0-agent-jdk17-1.0.10.jar').and_return(true)
    
    # Also stub the deprecated exists? method if called
    if !File.respond_to?(:exists?)
      allow(File).to receive(:exists?).and_return(false)
    end

    # Stub directory globs
    allow(Dir).to receive(:glob).and_call_original
    allow(Dir).to receive(:glob).with('/opt/apache-cassandra*').and_return([])
    allow(Dir).to receive(:glob).with('/opt/dse').and_return([])
  end
end

# Shared examples for common service patterns
RSpec.shared_examples 'creates_service' do |service_name|
  it "creates systemd override directory for #{service_name}" do
    expect(chef_run).to create_directory("/etc/systemd/system/#{service_name}.service.d")
  end

  it "creates systemd override configuration for #{service_name}" do
    expect(chef_run).to create_template("/etc/systemd/system/#{service_name}.service.d/override.conf")
  end

  it "enables and starts #{service_name} service" do
    expect(chef_run).to enable_service(service_name)
    expect(chef_run).to start_service(service_name)
  end
end
