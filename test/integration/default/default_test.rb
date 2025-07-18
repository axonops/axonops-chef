# InSpec test for recipe axonops::default

describe 'axonops::default' do
  it 'does not install any packages by default' do
    # The default recipe should not install anything
    %w(axon-agent axon-server axon-dash cassandra).each do |pkg|
      describe package(pkg) do
        it { should_not be_installed }
      end
    end
  end
end
