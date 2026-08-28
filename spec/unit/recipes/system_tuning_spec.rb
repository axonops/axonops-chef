require 'spec_helper'

describe 'axonops::system_tuning' do
  # The recipe decides container-vs-host at compile time from the filesystem,
  # so each context has to stub that before the converge.
  def stub_container(in_container)
    allow(::File).to receive(:exist?).and_call_original
    allow(::File).to receive(:read).and_call_original
    allow(::File).to receive(:exist?).with('/.dockerenv').and_return(in_container)
    allow(::File).to receive(:exist?).with('/proc/1/cgroup').and_return(false)
  end

  context 'on a non-container host' do
    before { stub_container(false) }

    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04').converge(described_recipe)
    end

    it 'writes the sysctl file without vm.swappiness (swap is disabled outright)' do
      expect(chef_run).to create_file('/etc/sysctl.d/99-cassandra.conf')
        .with_content(/vm\.overcommit_memory=1/)
      expect(chef_run.file('/etc/sysctl.d/99-cassandra.conf').content).not_to match(/vm\.swappiness/)
    end

    it 'disables transparent huge pages for the running kernel' do
      expect(chef_run).to run_execute('disable transparent hugepages (running kernel)')
    end

    it 'installs a systemd unit so THP stays disabled across reboots' do
      expect(chef_run).to create_systemd_unit('disable-transparent-hugepages.service')
      expect(chef_run).to enable_systemd_unit('disable-transparent-hugepages.service')
    end

    it 'turns swap off and clears it from /etc/fstab' do
      expect(chef_run).to run_execute('swapoff -a')
      expect(chef_run).to run_ruby_block('comment out swap entries in /etc/fstab')
    end
  end

  context 'inside a container' do
    before { stub_container(true) }

    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04').converge(described_recipe)
    end

    it 'does not touch transparent huge pages' do
      expect(chef_run).not_to run_execute('disable transparent hugepages (running kernel)')
      expect(chef_run).not_to create_systemd_unit('disable-transparent-hugepages.service')
    end

    it 'does not touch swap' do
      expect(chef_run).not_to run_execute('swapoff -a')
      expect(chef_run).not_to run_ruby_block('comment out swap entries in /etc/fstab')
    end

    it 'does not write sysctl settings' do
      expect(chef_run).not_to create_file('/etc/sysctl.d/99-cassandra.conf')
    end
  end

  context 'with swap management opted out' do
    before { stub_container(false) }

    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04') do |node|
        node.override['axonops']['disable_swap'] = false
      end.converge(described_recipe)
    end

    it 'falls back to vm.swappiness=1 for hosts that keep swap' do
      expect(chef_run.file('/etc/sysctl.d/99-cassandra.conf').content).to match(/vm\.swappiness=1/)
    end

    it 'does not run swapoff or edit /etc/fstab' do
      expect(chef_run).not_to run_execute('swapoff -a')
      expect(chef_run).not_to run_ruby_block('comment out swap entries in /etc/fstab')
    end
  end

  context 'with the deprecated skip_vm_swappiness attribute set' do
    before { stub_container(false) }

    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04') do |node|
        node.override['axonops']['skip_vm_swappiness'] = true
      end.converge(described_recipe)
    end

    it 'leaves swap alone and warns that it is deprecated' do
      expect(chef_run).not_to run_execute('swapoff -a')
      expect(chef_run).to write_log('skip_vm_swappiness_deprecated').with(level: :warn)
    end
  end
end
