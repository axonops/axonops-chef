require 'spec_helper'

describe 'axonops::install_cassandra_pkg' do
  let(:chef_run) do
    ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04') do |node|
      node.override['axonops']['cassandra']['install_format'] = 'pkg'
    end.converge(described_recipe)
  end

  it 'installs package' do
    expect(chef_run).to install_package('cassandra')
  end
end
