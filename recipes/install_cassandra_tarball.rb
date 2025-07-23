#
# Cookbook:: axonops
# Recipe:: install_cassandra_tarball
#
# Installs Apache Cassandra from tarball
#

# Ensure Java is installed first
include_recipe 'axonops::java'

# Get configuration
cassandra_version = node['axonops']['cassandra']['version']
cassandra_user = node['axonops']['cassandra']['user']
cassandra_group = node['axonops']['cassandra']['group']
install_dir = node['axonops']['cassandra']['install_dir']
data_root = node['axonops']['cassandra']['data_root']

# Installation paths
tarball_name = "apache-cassandra-#{cassandra_version}-bin.tar.gz"
cassandra_home = "#{install_dir}/apache-cassandra-#{cassandra_version}"
cassandra_current = "#{install_dir}/cassandra"

# Create base directories
[install_dir, data_root].each do |dir|
  directory dir do
    owner 'root'
    group 'root'
    mode '0755'
    recursive true
  end
end

# Determine tarball source
if node['axonops']['offline_install']
  # Offline installation
  tarball_path = ::File.join(node['axonops']['offline_packages_path'], tarball_name)
  
  unless ::File.exist?(tarball_path)
    raise Chef::Exceptions::FileNotFound, "Offline installation requested but tarball not found: #{tarball_path}"
  end
else
  # Online installation - download from Apache
  tarball_base_url = node['axonops']['cassandra']['base_url']
  tarball_url = "#{tarball_base_url}/#{cassandra_version}/#{tarball_name}"
  tarball_path = "#{Chef::Config[:file_cache_path]}/#{tarball_name}"
  
  remote_file tarball_path do
    source tarball_url
    mode '0644'
    action :create
    not_if { ::File.exist?(cassandra_home) }
  end
end

# Extract Cassandra
execute 'extract-cassandra' do
  command "tar -xzf #{tarball_path} -C #{install_dir}"
  creates cassandra_home
  notifies :run, 'execute[fix-cassandra-permissions]', :immediately
end

# Fix permissions
execute 'fix-cassandra-permissions' do
  command "chown -R #{cassandra_user}:#{cassandra_group} #{cassandra_home}"
  action :nothing
end

# Create symlink for easier management
link cassandra_current do
  to cassandra_home
  link_type :symbolic
end

# Create Cassandra directories
%w[
  data
  commitlog
  saved_caches
  hints
  cdc_raw
].each do |dir|
  directory "#{data_root}/#{dir}" do
    owner cassandra_user
    group cassandra_group
    mode '0750'
    recursive true
  end
end

# Create log directories
directory node['axonops']['cassandra']['directories']['logs'] do
  owner cassandra_user
  group cassandra_group
  mode '0755'
  recursive true
end

directory node['axonops']['cassandra']['directories']['gc_logs'] do
  owner cassandra_user
  group cassandra_group
  mode '0755'
  recursive true
end

# Create config directory if it doesn't exist
directory '/etc/cassandra' do
  owner 'root'
  group 'root'
  mode '0755'
end

# Symlink configuration directory
link '/etc/cassandra/conf' do
  to "#{cassandra_current}/conf"
  link_type :symbolic
end

# Add Cassandra bin to PATH
file '/etc/profile.d/cassandra.sh' do
  content <<-EOH
export CASSANDRA_HOME=#{cassandra_current}
export PATH=$PATH:$CASSANDRA_HOME/bin:$CASSANDRA_HOME/tools/bin
EOH
  mode '0644'
end

# Create runtime directory for PID file
directory '/var/run/cassandra' do
  owner cassandra_user
  group cassandra_group
  mode '0755'
end

systemd_unit 'cassandra.service' do
  content({
    'Unit' => {
      'Description' => 'Apache Cassandra',
      'After' => 'network.target'
    },
    'Service' => {
      'Type' => 'forking',
      'ExecStart' => "#{cassandra_current}/bin/cassandra -p /var/run/cassandra/cassandra.pid",
      'User' => cassandra_user,
      'Group' => cassandra_group,
      'LimitNOFILE' => 100000,
      'LimitMEMLOCK' => 'infinity',
      'LimitNPROC' => 32768,
      'LimitAS' => 'infinity',
      'Environment' => "CASSANDRA_HOME=#{cassandra_current}",
      'PIDFile' => '/var/run/cassandra/cassandra.pid',
      'RuntimeDirectory' => 'cassandra',
      'RuntimeDirectoryMode' => '0755',
      'Restart' => 'on-failure',
      'RestartSec' => 10
    },
    'Install' => {
      'WantedBy' => 'multi-user.target'
    }
  })
  action [:create, :enable, :start]
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
end

execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Set system limits
file '/etc/security/limits.d/cassandra.conf' do
  content <<-EOH
#{cassandra_user} - memlock unlimited
#{cassandra_user} - nofile 100000
#{cassandra_user} - nproc 32768
#{cassandra_user} - as unlimited
EOH
  mode '0644'
  only_if { node['axonops']['skip_system_tuning'] && !node['axonops']['skip_system_tuning'] }
end

# Log installation info
log 'cassandra-installation' do
  message "Apache Cassandra #{cassandra_version} installed at #{cassandra_home}"
  level :info
end