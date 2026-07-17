#!/usr/bin/env ruby
require 'spec_helper'

describe 'axonops::java' do
  context 'when only axonops.offline_install is set (not java.offline_install directly)' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '22.04') do |node|
        node.override['axonops']['offline_install'] = true
        node.override['java']['tarball_path'] = '/tmp/fake-zulu.tar.gz'
      end
    end

    before do
      allow(::File).to receive(:exist?).and_call_original
      allow(::File).to receive(:exist?).with('/tmp/fake-zulu.tar.gz').and_return(true)
    end

    it 'propagates the flag into java.offline_install' do
      chef_run.converge(described_recipe)
      expect(chef_run.node['java']['offline_install']).to be true
    end

    it 'does not attempt to fetch the Azul GPG key' do
      chef_run.converge(described_recipe)
      expect(chef_run).not_to run_execute('add-azul-repo-key')
    end

    it 'does not configure the Zulu apt/yum repository' do
      chef_run.converge(described_recipe)
      expect(chef_run).not_to create_file('/etc/apt/sources.list.d/zulu.list')
      expect(chef_run).not_to install_rpm_package('zulu-repo')
    end

    it 'installs Java from the local tarball instead' do
      chef_run.converge(described_recipe)
      expect(chef_run).to run_execute('extract-java')
    end
  end

  context 'when neither offline flag is set' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '22.04').converge(described_recipe)
    end

    it 'still attempts the online Azul repo install path' do
      expect(chef_run).to run_execute('add-azul-repo-key')
    end
  end
end
