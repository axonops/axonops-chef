require 'spec_helper'

describe 'axonops::server' do
  include_context 'chef_run'

  context 'with SaaS deployment mode' do
    let(:node_attributes) do
      {
        'axonops' => {
          'deployment_mode' => 'saas',
          'server' => {
            'enabled' => true,
          },
        },
      }
    end

    it 'does not install server in SaaS mode' do
      expect(chef_run.resource_collection).to be_empty
    end
  end

  context 'with self-hosted deployment' do
    let(:node_attributes) do
      {
        'axonops' => {
          'deployment_mode' => 'self-hosted',
          'server' => {
            'enabled' => true,
            'elasticsearch' => {
              'install' => true,
            },
            'cassandra' => {
              'install' => true,
            },
          },
        },
      }
    end

    it 'includes dependency recipes' do
      expect(chef_run).to include_recipe('axonops::dependencies::elasticsearch')
      expect(chef_run).to include_recipe('axonops::dependencies::cassandra_metrics')
    end

    it 'includes repo recipe' do
      expect(chef_run).to include_recipe('axonops::repo')
    end

    it 'creates axonops user and group' do
      expect(chef_run).to create_group('axonops')
      expect(chef_run).to create_user('axonops')
    end

    it 'creates required directories' do
      %w(/etc/axonops /var/log/axonops /var/lib/axonops).each do |dir|
        expect(chef_run).to create_directory(dir)
      end
    end

    it 'installs axon-server package' do
      expect(chef_run).to install_package('axon-server')
    end

    it 'creates server configuration' do
      expect(chef_run).to create_template('/etc/axonops/axon-server.yml').with(
        owner: 'axonops',
        group: 'axonops',
        mode: '0640'
      )
    end

    it_behaves_like 'creates_service', 'axon-server'

    it 'waits for server to be ready' do
      expect(chef_run).to run_ruby_block('wait-for-axon-server')
    end
  end

  context 'with existing infrastructure' do
    let(:node_attributes) do
      {
        'axonops' => {
          'deployment_mode' => 'self-hosted',
          'server' => {
            'enabled' => true,
            'elasticsearch' => {
              'install' => false,
              'url' => 'http://my-elastic:9200',
            },
            'cassandra' => {
              'install' => false,
              'hosts' => %w(cass1 cass2),
            },
          },
        },
      }
    end

    it 'does not include dependency recipes' do
      expect(chef_run).not_to include_recipe('axonops::dependencies::elasticsearch')
      expect(chef_run).not_to include_recipe('axonops::dependencies::cassandra_metrics')
    end

    it 'configures server to use existing infrastructure' do
      expect(chef_run).to create_template('/etc/axonops/axon-server.yml') do |template|
        expect(template.variables[:elastic_host]).to eq('http://my-elastic:9200')
        expect(template.variables[:cassandra_hosts]).to eq(%w(cass1 cass2))
      end
    end
  end

  context 'with TLS enabled' do
    let(:node_attributes) do
      {
        'axonops' => {
          'deployment_mode' => 'self-hosted',
          'server' => {
            'enabled' => true,
            'tls' => {
              'mode' => 'TLS',
              'cert_file' => '/etc/ssl/certs/axonops.crt',
              'key_file' => '/etc/ssl/private/axonops.key',
            },
          },
        },
      }
    end

    before do
      allow(File).to receive(:exist?).with('/etc/ssl/certs/axonops.crt').and_return(true)
      allow(File).to receive(:exist?).with('/etc/ssl/private/axonops.key').and_return(true)
    end

    it 'validates TLS certificate files' do
      expect(chef_run).to create_file_if_missing('/etc/ssl/certs/axonops.crt')
      expect(chef_run).to create_file_if_missing('/etc/ssl/private/axonops.key')
    end
  end

  context 'with offline installation' do
    let(:node_attributes) do
      {
        'axonops' => {
          'deployment_mode' => 'self-hosted',
          'server' => {
            'enabled' => true,
          },
          'offline_install' => true,
          'offline_packages_path' => '/opt/axonops-packages',
          'packages' => {
            'server' => 'axon-server_1.0.0_amd64.deb',
          },
        },
      }
    end

    it 'does not include repo recipe' do
      expect(chef_run).not_to include_recipe('axonops::repo')
    end

    it 'installs from local package' do
      expect(chef_run).to install_dpkg_package('axon-server').with(
        source: '/opt/axonops-packages/axon-server_1.0.0_amd64.deb'
      )
    end
  end
end
