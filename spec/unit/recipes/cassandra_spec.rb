require 'spec_helper'

describe 'axonops::cassandra' do
  context 'TestCassandraRecipe_TarInstall_IncludesInstallTarballRecipe' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04') do |node|
        node.override['axonops']['cassandra']['install_format'] = 'tar'
      end.converge(described_recipe)
    end
    it 'includes install_cassandra_tarball' do
      expect(chef_run).to include_recipe('axonops::install_cassandra_tarball')
    end
  end

  context 'TestCassandraRecipe_PkgInstall_IncludesInstallPkgRecipe' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04') do |node|
        node.override['axonops']['cassandra']['install_format'] = 'pkg'
      end.converge(described_recipe)
    end
    it 'includes install_cassandra_pkg' do
      expect(chef_run).to include_recipe('axonops::install_cassandra_pkg')
    end
  end

  context 'TestCassandraRecipe_UnsupportedVersion_RaisesError' do
    it 'raises error' do
      expect do
        ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04') do |node|
          node.override['axonops']['cassandra']['version'] = '2.0.0'
        end.converge(described_recipe)
      end.to raise_error(RuntimeError)
    end
  end

  context 'TestCassandraRecipe_Java8ForVersion3_11' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04') do |node|
        node.override['axonops']['cassandra']['version'] = '3.11.17'
      end.converge(described_recipe)
    end
    it 'installs java 8' do
      expect(chef_run.node['axonops']['java']['version']).to eq('8')
    end
  end

  context 'TestCassandraRecipe_Java11ForVersion4_1' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04') do |node|
        node.override['axonops']['cassandra']['version'] = '4.1.7'
      end.converge(described_recipe)
    end
    it 'installs java 11' do
      expect(chef_run.node['axonops']['java']['version']).to eq('11')
    end
  end

  context 'TestCassandraRecipe_Java17ForVersion5_0' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04') do |node|
        node.override['axonops']['cassandra']['version'] = '5.0.5'
      end.converge(described_recipe)
    end
    it 'installs java 17' do
      expect(chef_run.node['axonops']['java']['version']).to eq('17')
    end
  end

  context 'TestCassandraRecipe_SkipSystemTuning_DoesNotIncludeSystemTuningRecipe' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04') do |node|
        node.override['axonops']['cassandra']['skip_system_tuning'] = true
      end.converge(described_recipe)
    end
    it 'does not include system tuning' do
      expect(chef_run).to_not include_recipe('axonops::system_tuning')
    end
  end

  context 'TestCassandraRecipe_AgentEnabled_IncludesAgentRecipe' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04') do |node|
        node.override['axonops']['agent']['enabled'] = true
      end.converge(described_recipe)
    end
    it 'includes agent' do
      expect(chef_run).to include_recipe('axonops::agent')
    end
  end
end
