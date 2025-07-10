require 'spec_helper'

describe 'axonops::cassandra' do
  include_context 'chef_run'

  context 'with default attributes' do
    let(:node_attributes) do
      {
        'cassandra' => {
          'install' => true,
          'cluster_name' => 'Test Cluster',
          'seeds' => ['10.0.0.1', '10.0.0.2'],
        },
      }
    end

    before do
      # Stub included recipes
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).and_call_original
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::dependencies::java')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::system_tuning')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::install_cassandra_tarball')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::configure_cassandra')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::cassandra_service')
    end

    it 'includes java recipe' do
      expect(chef_run).to include_recipe('axonops::dependencies::java')
    end

    it 'includes system tuning recipe' do
      expect(chef_run).to include_recipe('axonops::system_tuning')
    end

    it 'creates cassandra user and group' do
      expect(chef_run).to create_group('cassandra').with(system: true)
      expect(chef_run).to create_user('cassandra').with(
        group: 'cassandra',
        system: true,
        shell: '/bin/false',
        home: '/var/lib/cassandra'
      )
    end

    it 'creates required directories' do
      directories = [
        '/opt/cassandra',
        '/data/cassandra/data',
        '/data/cassandra/hints',
        '/data/cassandra/saved_caches',
        '/data/cassandra/commitlog',
        '/var/log/cassandra',
        '/etc/cassandra',
      ]

      directories.each do |dir|
        expect(chef_run).to create_directory(dir).with(
          owner: 'cassandra',
          group: 'cassandra',
          mode: '0755',
          recursive: true
        )
      end
    end

    it 'includes installation recipe based on format' do
      expect(chef_run).to include_recipe('axonops::install_cassandra_tarball')
    end

    it 'includes configuration recipe' do
      expect(chef_run).to include_recipe('axonops::configure_cassandra')
    end

    it 'includes service recipe' do
      expect(chef_run).to include_recipe('axonops::cassandra_service')
    end
  end

  context 'with skip_java_install' do
    let(:node_attributes) do
      {
        'cassandra' => {
          'install' => true,
          'skip_java_install' => true,
        },
      }
    end

    before do
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).and_call_original
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::system_tuning')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::install_cassandra_tarball')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::configure_cassandra')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::cassandra_service')
    end

    it 'does not include java recipe' do
      expect(chef_run).not_to include_recipe('axonops::dependencies::java')
    end
  end

  context 'with package installation' do
    let(:node_attributes) do
      {
        'cassandra' => {
          'install' => true,
          'install_format' => 'package',
        },
      }
    end

    before do
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).and_call_original
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::dependencies::java')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::system_tuning')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::install_cassandra_package')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::configure_cassandra')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::cassandra_service')
    end

    it 'includes package installation recipe' do
      expect(chef_run).to include_recipe('axonops::install_cassandra_package')
    end
  end

  context 'with security enabled' do
    let(:node_attributes) do
      {
        'cassandra' => {
          'install' => true,
          'authenticator' => 'PasswordAuthenticator',
          'authorizer' => 'CassandraAuthorizer',
        },
      }
    end

    before do
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).and_call_original
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::dependencies::java')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::system_tuning')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::install_cassandra_tarball')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::configure_cassandra')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::cassandra_service')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::cassandra_security')
    end

    it 'includes security recipe' do
      expect(chef_run).to include_recipe('axonops::cassandra_security')
    end
  end

  context 'with AxonOps agent enabled' do
    let(:node_attributes) do
      {
        'cassandra' => {
          'install' => true,
        },
        'axonops' => {
          'agent' => {
            'enabled' => true,
          },
        },
      }
    end

    before do
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).and_call_original
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::dependencies::java')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::system_tuning')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::install_cassandra_tarball')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::configure_cassandra')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::cassandra_service')
      allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('axonops::agent')
    end

    it 'includes agent recipe to monitor Cassandra' do
      expect(chef_run).to include_recipe('axonops::agent')
    end
  end
end
