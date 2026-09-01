require 'spec_helper'

describe 'axonops::system_tuning' do
  THP_ENABLED = '/sys/kernel/mm/transparent_hugepage/enabled'.freeze
  THP_DEFRAG = '/sys/kernel/mm/transparent_hugepage/defrag'.freeze
  FSTAB_WITH_SWAP = [
    "UUID=1111 / ext4 defaults 0 1\n",
    "UUID=2222 none swap sw 0 0\n",
  ].freeze

  # The recipe reads the host's own filesystem to decide what to do — container
  # markers at compile time, THP/swap state in the resource guards. Stub every
  # one of those paths so the examples assert the recipe's logic rather than
  # whatever swap and THP configuration the CI runner happens to have.
  def stub_host(in_container: false, thp: 'always madvise [always]',
                swap_active: true, fstab: FSTAB_WITH_SWAP)
    allow(::File).to receive(:exist?).and_call_original
    allow(::File).to receive(:read).and_call_original
    allow(::File).to receive(:readlines).and_call_original

    allow(::File).to receive(:exist?).with('/.dockerenv').and_return(in_container)
    allow(::File).to receive(:exist?).with('/proc/1/cgroup').and_return(false)

    [THP_ENABLED, THP_DEFRAG].each do |path|
      allow(::File).to receive(:exist?).with(path).and_return(true)
      allow(::File).to receive(:read).with(path).and_return("#{thp}\n")
    end

    swaps = ["Filename Type Size Used Priority\n"]
    swaps << "/dev/sda2 partition 2097148 0 -2\n" if swap_active
    allow(::File).to receive(:exist?).with('/proc/swaps').and_return(true)
    allow(::File).to receive(:readlines).with('/proc/swaps').and_return(swaps)

    allow(::File).to receive(:exist?).with('/etc/fstab').and_return(true)
    allow(::File).to receive(:readlines).with('/etc/fstab').and_return(fstab)
  end

  context 'on a non-container host' do
    before { stub_host }

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
    before { stub_host(in_container: true) }

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
    before { stub_host }

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
    before { stub_host }

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

  context 'on a second converge, with nothing left to change' do
    before do
      stub_host(
        thp: 'always madvise [never]',
        swap_active: false,
        fstab: ["UUID=1111 / ext4 defaults 0 1\n",
                "# Disabled by axonops::system_tuning: UUID=2222 none swap sw 0 0\n"]
      )
    end

    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04').converge(described_recipe)
    end

    it 'does not re-apply the THP or swap changes' do
      expect(chef_run).not_to run_execute('disable transparent hugepages (running kernel)')
      expect(chef_run).not_to run_execute('swapoff -a')
      expect(chef_run).not_to run_ruby_block('comment out swap entries in /etc/fstab')
    end
  end

  context 'with a zram swap device in /etc/fstab' do
    before do
      stub_host(fstab: ["/dev/zram0 none swap defaults 0 0\n"])
    end

    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04').converge(described_recipe)
    end

    it 'still comments the entry out' do
      expect(chef_run).to run_ruby_block('comment out swap entries in /etc/fstab')
    end
  end
end
