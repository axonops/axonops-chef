#
# Cookbook:: axonops
# Recipe:: install_cassandra_pkg
#
# Installs Apache Cassandra from native package manager (apt/yum)
#

cassandra_version = node['axonops']['cassandra']['version']
cassandra_311 = cassandra_version.start_with?('3.11')

if cassandra_311 && platform_family?('debian')
  raise Chef::Exceptions::UnsupportedAction, 'Package installation is not supported for Cassandra 3.11.x on Debian/Ubuntu (no apt channel exists upstream). Please use tar format.'
end

# Ensure Java is installed first
include_recipe 'axonops::java'

# Determine repo series (e.g., '311x', '41x', '50x')
repo_series = cassandra_version.split('.')[0..1].join('') + 'x'

# Apache's own RPM repo dropped 3.11; fall back to the JFrog mirror the
# Ansible role uses for it. 41x/50x still come from redhat.cassandra.apache.org.
rhel_baseurl = if cassandra_311
                 node['axonops']['cassandra']['redhat_repository_url_311x']
               else
                 "https://redhat.cassandra.apache.org/#{repo_series}/noboolean/"
               end

unless node['axonops']['offline_install']
  if platform_family?('debian')
    directory '/etc/apt/keyrings' do
      owner 'root'
      group 'root'
      mode '0755'
      recursive true
    end

    remote_file '/etc/apt/keyrings/apache-cassandra.asc' do
      source 'https://downloads.apache.org/cassandra/KEYS'
      owner 'root'
      group 'root'
      mode '0644'
    end

    apt_repository 'cassandra' do
      uri 'https://debian.cassandra.apache.org'
      distribution repo_series
      components ['main']
      # Chef 18+ may auto-handle the key, but to strictly ensure [signed-by=...]
      options ['signed-by=/etc/apt/keyrings/apache-cassandra.asc']
      action :add
    end
  elsif platform_family?('rhel', 'amazon')
    yum_repository 'cassandra' do
      description 'Apache Cassandra'
      baseurl rhel_baseurl
      gpgkey 'https://downloads.apache.org/cassandra/KEYS'
      gpgcheck true
      repo_gpgcheck true
      action :create
    end
  end
end

if node['axonops']['offline_install']
  cassandra_pkg_path = AxonOpsOffline.resolve(self, node['axonops']['offline_packages']['cassandra_pkg'])
end

if platform_family?('debian')
  node.override['axonops']['cassandra']['conf_dir'] = '/etc/cassandra'

  if node['axonops']['offline_install']
    # No repo was configured above in offline mode, so `apt_package
    # 'cassandra'` (which resolves the version from a repo) has nothing to
    # install from — install the downloaded .deb directly instead, same
    # pattern as recipes/agent.rb's offline branch.
    dpkg_package 'cassandra' do
      source cassandra_pkg_path
      action :install
    end
  else
    apt_package 'cassandra' do
      version cassandra_version
      action :install
    end

    execute 'hold-cassandra' do
      command 'apt-mark hold cassandra'
      action :run
      not_if "apt-mark showhold | grep -q '^cassandra$'"
    end
  end
elsif platform_family?('rhel', 'amazon')
  node.override['axonops']['cassandra']['conf_dir'] = '/etc/cassandra/conf'

  if node['axonops']['offline_install']
    # Same reasoning as the Debian branch above: no yum repo in offline mode,
    # so point the package resource at the downloaded RPM directly.
    package 'cassandra' do
      source cassandra_pkg_path
      version "#{cassandra_version}-1"
      action :install
      allow_downgrade true
    end
  else
    # yum_package needs python yum bindings that dnf-only distros (Amazon
    # Linux 2023, RHEL 9+) don't ship. The generic package resource lets
    # Chef pick dnf_package there and yum_package on older yum-based
    # RHEL/CentOS.
    package 'cassandra' do
      version "#{cassandra_version}-1"
      action :install
      allow_downgrade true
    end
  end
else
  raise Chef::Exceptions::UnsupportedAction, 'Unsupported platform family for Cassandra package installation.'
end
