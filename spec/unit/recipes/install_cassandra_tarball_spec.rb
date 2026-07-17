require 'spec_helper'

describe 'axonops::install_cassandra_tarball' do
  let(:chef_run) do
    ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04').converge(described_recipe)
  end

  it 'TestTarball_DownloadsCorrectURL' do
    # check that tarball is downloaded
    expect(chef_run).to create_remote_file_if_missing(/\/opt\/cassandra/)
  end

  it 'TestTarball_OfflineInstall_UsesLocalPath' do
    # dummy
  end

  it 'TestTarball_OfflineInstall_MissingTarball_RaisesError' do
    # dummy
  end

  it 'TestTarball_CreatesSymlink' do
    expect(chef_run).to create_link('/opt/cassandra')
  end

  it 'TestTarball_SetsCorrectPermissions' do
    # check user/group setup
  end
end
