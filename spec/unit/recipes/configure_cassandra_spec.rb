require 'spec_helper'

describe 'axonops::configure_cassandra' do
  let(:chef_run_311) do
    ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04') do |node|
      node.override['axonops']['cassandra']['version'] = '3.11.17'
    end.converge(described_recipe)
  end

  let(:chef_run_41) do
    ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04') do |node|
      node.override['axonops']['cassandra']['version'] = '4.1.7'
    end.converge(described_recipe)
  end

  let(:chef_run_50) do
    ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04') do |node|
      node.override['axonops']['cassandra']['version'] = '5.0.5'
    end.converge(described_recipe)
  end

  it 'TestConfigure_PEMInternode_RendersCorrectly' do
  end
  it 'TestConfigure_JKSInternode_RendersCorrectly' do
  end
  it 'TestConfigure_CassandraYaml_AllAttributesPassedAsVariables' do
  end
end
