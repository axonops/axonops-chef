#!/usr/bin/env ruby
require 'spec_helper'

# NOTE: axonops::agent's java_agent_package selection branches on
# `node.run_list.include?('recipe[axonops::cassandra]') || cassandra_detected`,
# and `cassandra_detected` is only ever set inside a converge-time ruby_block —
# it is always false during ChefSpec's compile-only dry run. So these specs
# converge through axonops::cassandra (which run-list-includes itself and
# includes axonops::agent), the same way a real node exercises this path,
# rather than converging axonops::agent in isolation.
describe 'axonops::cassandra' do
  let(:common_attrs) do
    lambda do |node|
      node.override['axonops']['agent']['org_key'] = 'test-org-key'
      node.override['axonops']['agent']['org_name'] = 'test-org'
    end
  end

  context 'when a DSE install is detected at /opt/dse' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '22.04', &common_attrs)
    end

    before do
      allow(::File).to receive(:exist?).and_return(false)
      allow(::Dir).to receive(:glob).and_return([])
      allow(::Dir).to receive(:glob).with('/opt/dse').and_return(['/opt/dse'])
    end

    it 'sets cassandra.edition to dse and does not install Apache Cassandra' do
      chef_run.converge(described_recipe)
      expect(chef_run.node['axonops']['cassandra']['edition']).to eq('dse')
      expect(chef_run).not_to run_execute('extract-cassandra')
    end

    it 'delegates monitoring to axonops::agent, installing the DSE java agent package' do
      chef_run.converge(described_recipe)
      expect(chef_run).to install_package('axon-dse-agent')
    end
  end

  context 'when a DSE config file is detected at /etc/dse/cassandra/cassandra.yaml' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '22.04', &common_attrs)
    end

    before do
      allow(::File).to receive(:exist?).and_return(false)
      allow(::File).to receive(:exist?).with('/etc/dse/cassandra/cassandra.yaml').and_return(true)
      allow(::Dir).to receive(:glob).and_return([])
    end

    it 'sets cassandra.edition to dse' do
      chef_run.converge(described_recipe)
      expect(chef_run.node['axonops']['cassandra']['edition']).to eq('dse')
    end
  end

  context 'when no DSE install is present (plain Apache Cassandra)' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '22.04', &common_attrs)
    end

    before do
      allow(::File).to receive(:exist?).and_return(false)
      allow(::Dir).to receive(:glob).and_return([])
    end

    it 'leaves cassandra.edition as apache and installs Apache Cassandra' do
      chef_run.converge(described_recipe)
      expect(chef_run.node['axonops']['cassandra']['edition']).to eq('apache')
      expect(chef_run).to run_execute('extract-cassandra')
    end

    it 'installs the Apache Cassandra java agent package, not a nil package (regression check)' do
      chef_run.converge(described_recipe)
      expect(chef_run).to install_package('axon-cassandra5.0-agent-jdk17')
    end
  end
end
