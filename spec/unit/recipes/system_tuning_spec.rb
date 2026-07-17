require 'spec_helper'

describe 'axonops::system_tuning' do
  let(:chef_run) do
    ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04').converge(described_recipe)
  end

  it 'creates sysctl file' do
    # dummy
  end
end
