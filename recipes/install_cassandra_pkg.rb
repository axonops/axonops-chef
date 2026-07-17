#
# Cookbook:: axonops
# Recipe:: install_cassandra_pkg
#
# Installs Apache Cassandra via the official apt/yum repositories
#

version = node['axonops']['cassandra']['version']
install_format = node['axonops']['cassandra']['install_format']

if version.start_with?('3.11')
  raise Chef::Exceptions::UnsupportedAction, "cassandra: package-repo install is not supported for Cassandra 3.11; use install_format: tar"
end

if install_format != 'pkg'
  raise Chef::Exceptions::ValidationFailed, "cassandra: install_format must be 'tar' or 'pkg', got '#{install_format}'"
end

# Major release channel mapping: 4.1.7 -> 41x, 5.0.5 -> 50x
channel = version.split('.')[0..1].join + 'x'

unless node['axonops']['offline_install']
  case node['platform_family']
  when 'debian'
    package %w(gnupg curl apt-transport-https)

    directory '/etc/apt/keyrings' do
      mode '0755'
      recursive true
    end

    remote_file '/etc/apt/keyrings/apache-cassandra.asc' do
      source 'https://downloads.apache.org/cassandra/KEYS'
      mode '0644'
      action :create_if_missing
    end

    file '/etc/apt/sources.list.d/cassandra.list' do
      content "deb [signed-by=/etc/apt/keyrings/apache-cassandra.asc] https://debian.cassandra.apache.org #{channel} main\n"
      mode '0644'
      notifies :run, 'execute[apt-get-update-cassandra]', :immediately
    end

    execute 'apt-get-update-cassandra' do
      command 'apt-get update'
      action :nothing
    end

  when 'rhel', 'fedora', 'amazon'
    execute 'import-cassandra-gpg-key' do
      command 'rpm --import https://downloads.apache.org/cassandra/KEYS'
      not_if 'rpm -qa gpg-pubkey | xargs -I {} rpm -qi {} | grep -q "Apache Cassandra"'
    end

    yum_repository "cassandra#{channel.chomp('x')}" do
      description "Apache Cassandra #{channel}"
      baseurl "https://redhat.cassandra.apache.org/#{channel}/"
      gpgcheck true
      enabled true
    end
  end
end

case node['platform_family']
when 'debian'
  package "cassandra" do
    version version
    action :install
  end

  execute 'apt-mark hold cassandra' do
    not_if "apt-mark showhold | grep -q cassandra"
  end

  node.override['axonops']['cassandra']['conf_dir'] = '/etc/cassandra'
when 'rhel', 'fedora', 'amazon'
  package "cassandra-#{version}-1" do
    action :install
  end

  node.override['axonops']['cassandra']['conf_dir'] = '/etc/cassandra/conf'
end
