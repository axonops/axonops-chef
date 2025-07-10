require 'spec_helper'

describe 'axonops::agent' do
  include_context 'chef_run'

  context 'with default attributes' do
    let(:node_attributes) do
      {
        'axonops' => {
          'api' => {
            'key' => 'test-key',
            'organization' => 'test-org',
          },
        },
      }
    end

    it 'includes the repo recipe' do
      expect(chef_run).to include_recipe('axonops::repo')
    end

    it 'creates axonops group' do
      expect(chef_run).to create_group('axonops').with(
        system: true
      )
    end

    it 'creates axonops user' do
      expect(chef_run).to create_user('axonops').with(
        group: 'axonops',
        system: true,
        shell: '/bin/false',
        home: '/var/lib/axonops'
      )
    end

    it 'creates required directories' do
      %w(/etc/axonops /var/log/axonops /var/lib/axonops /usr/share/axonops).each do |dir|
        expect(chef_run).to create_directory(dir).with(
          owner: 'axonops',
          group: 'axonops',
          mode: '0755'
        )
      end
    end

    it 'installs axon-agent package' do
      expect(chef_run).to install_package('axon-agent')
    end

    it 'creates agent configuration' do
      expect(chef_run).to create_template('/etc/axonops/axon-agent.yml').with(
        owner: 'axonops',
        group: 'axonops',
        mode: '0600',
        sensitive: true
      )
    end

    it_behaves_like 'creates_service', 'axon-agent'
  end

  context 'with existing Cassandra detected' do
    before do
      allow(File).to receive(:exist?).with('/opt/cassandra/bin/cassandra').and_return(true)
      allow(File).to receive(:exist?).with('/opt/cassandra/conf/cassandra.yaml').and_return(true)
      allow(File).to receive(:exist?).with('/opt/cassandra/conf/jvm-server.options').and_return(true)
      allow(File).to receive(:read).with('/opt/cassandra/conf/jvm-server.options').and_return('')
    end

    let(:node_attributes) do
      {
        'axonops' => {
          'api' => {
            'key' => 'test-key',
            'organization' => 'test-org',
          },
        },
      }
    end

    it 'detects Cassandra installation' do
      expect(chef_run).to run_ruby_block('detect-cassandra')
    end

    it 'configures Cassandra JVM agent' do
      expect(chef_run).to run_ruby_block('configure-cassandra-jvm-agent')
    end
  end

  context 'with offline installation' do
    let(:node_attributes) do
      {
        'axonops' => {
          'offline_install' => true,
          'offline_packages_path' => '/opt/axonops-packages',
          'packages' => {
            'agent' => 'axon-agent_2.0.4_amd64.deb',
            'java_agent' => 'axon-cassandra5.0-agent-jdk17-1.0.10.jar',
          },
        },
      }
    end

    before do
      allow(File).to receive(:read).with('/opt/axonops-packages/axon-cassandra5.0-agent-jdk17-1.0.10.jar').and_return('jar_content')
    end

    it 'does not include repo recipe' do
      expect(chef_run).not_to include_recipe('axonops::repo')
    end

    it 'installs from local package' do
      expect(chef_run).to install_dpkg_package('axon-agent').with(
        source: '/opt/axonops-packages/axon-agent_2.0.4_amd64.deb'
      )
    end

    it 'copies Java agent from local directory' do
      expect(chef_run).to create_file('/usr/share/axonops/axon-cassandra5.0-agent-jdk17-1.0.10.jar')
    end
  end

  context 'with self-hosted deployment' do
    let(:node_attributes) do
      {
        'axonops' => {
          'deployment_mode' => 'self-hosted',
          'server' => {
            'enabled' => true,
            'listen_address' => '192.168.1.10',
            'listen_port' => 8080,
          },
        },
      }
    end

    it 'configures agent to connect to self-hosted server' do
      expect(chef_run).to create_template('/etc/axonops/axon-agent.yml') do |template|
        expect(template.variables[:agent_host]).to eq('192.168.1.10')
        expect(template.variables[:agent_port]).to eq(8080)
      end
    end
  end

  context 'on RHEL platform' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'centos', version: '7') do |node|
        node.automatic['platform_family'] = 'rhel'
        node.override['axonops']['offline_install'] = true
        node.override['axonops']['packages']['agent'] = 'axon-agent-2.0.4-1.el7.x86_64.rpm'
      end.converge(described_recipe)
    end

    before do
      allow(File).to receive(:exist?).with('/opt/axonops-packages/axon-agent-2.0.4-1.el7.x86_64.rpm').and_return(true)
      allow(File).to receive(:exist?).with('/opt/axonops-packages/axon-cassandra5.0-agent-jdk17-1.0.10.jar').and_return(true)
      allow(File).to receive(:read).with('/opt/axonops-packages/axon-cassandra5.0-agent-jdk17-1.0.10.jar').and_return('jar_content')
    end

    it 'installs RPM package' do
      expect(chef_run).to install_rpm_package('axon-agent').with(
        source: '/opt/axonops-packages/axon-agent-2.0.4-1.el7.x86_64.rpm'
      )
    end
  end
end
