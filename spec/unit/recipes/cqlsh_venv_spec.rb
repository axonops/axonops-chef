require 'spec_helper'

describe 'axonops::cqlsh_venv' do
  context 'TestCqlshVenv_Enabled_CreatesVenvInstallAndWrapper' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04').converge(described_recipe)
    end

    it 'creates the virtualenv' do
      expect(chef_run).to run_execute('create-cqlsh-venv')
        .with(command: 'python3 -m venv /opt/cassandra-cqlsh-venv')
    end

    it 'installs cqlsh into the venv' do
      expect(chef_run).to run_execute('install-cqlsh')
        .with(command: '/opt/cassandra-cqlsh-venv/bin/pip install --no-cache-dir cqlsh')
    end

    it 'installs a wrapper on PATH that execs the venv cqlsh' do
      expect(chef_run).to create_file('/usr/local/bin/cqlsh').with(mode: '0755')
      expect(chef_run).to render_file('/usr/local/bin/cqlsh')
        .with_content('exec /opt/cassandra-cqlsh-venv/bin/cqlsh "$@"')
    end
  end

  context 'TestCqlshVenv_Disabled_DoesNothing' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04') do |node|
        node.override['axonops']['cassandra']['cqlsh_venv']['enabled'] = false
      end.converge(described_recipe)
    end

    it 'does not create the venv' do
      expect(chef_run).to_not run_execute('create-cqlsh-venv')
    end

    it 'does not install the wrapper' do
      expect(chef_run).to_not create_file('/usr/local/bin/cqlsh')
    end
  end

  context 'TestCqlshVenv_Debian_InstallsVenvAndPip' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04').converge(described_recipe)
    end

    it 'installs python3-venv and python3-pip' do
      expect(chef_run).to install_package(%w(python3-venv python3-pip))
    end
  end

  context 'TestCqlshVenv_RHEL_InstallsPython3AndPip' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'rocky', version: '9').converge(described_recipe)
    end

    it 'installs python3 and python3-pip' do
      expect(chef_run).to install_package(%w(python3 python3-pip))
    end

    it 'still creates the venv and wrapper' do
      expect(chef_run).to run_execute('create-cqlsh-venv')
      expect(chef_run).to create_file('/usr/local/bin/cqlsh')
    end
  end

  context 'TestCqlshVenv_Offline_SkipsWithWarning' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04') do |node|
        node.override['axonops']['offline_install'] = true
      end.converge(described_recipe)
    end

    it 'logs a warning and skips provisioning' do
      expect(chef_run).to write_log('cqlsh-venv-offline-skip').with(level: :warn)
      expect(chef_run).to_not run_execute('create-cqlsh-venv')
      expect(chef_run).to_not create_file('/usr/local/bin/cqlsh')
    end
  end

  context 'TestCqlshVenv_CustomAttributes_AreRespected' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '24.04') do |node|
        node.override['axonops']['cassandra']['cqlsh_venv']['path'] = '/opt/cqlsh'
        node.override['axonops']['cassandra']['cqlsh_venv']['python'] = 'python3.12'
        node.override['axonops']['cassandra']['cqlsh_venv']['packages'] = ['cqlsh==6.2.0']
        node.override['axonops']['cassandra']['cqlsh_venv']['wrapper_path'] = '/usr/local/bin/cqlsh-venv'
      end.converge(described_recipe)
    end

    it 'uses the custom python, path, packages and wrapper' do
      expect(chef_run).to run_execute('create-cqlsh-venv')
        .with(command: 'python3.12 -m venv /opt/cqlsh')
      expect(chef_run).to run_execute('install-cqlsh')
        .with(command: '/opt/cqlsh/bin/pip install --no-cache-dir cqlsh==6.2.0')
      expect(chef_run).to create_file('/usr/local/bin/cqlsh-venv')
    end
  end
end
