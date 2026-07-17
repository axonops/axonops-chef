#
# Cookbook:: axonops
# Recipe:: cassandra
#
# Installs Apache Cassandra 5.0 for user applications
# This is separate from any Cassandra used internally by AxonOps server
#

# Check for existing Cassandra installation
if ::File.exist?('/etc/cassandra/cassandra.yaml') ||
   ::File.exist?('/etc/cassandra/conf/cassandra.yaml') ||
   ::File.exist?('/usr/bin/cassandra') ||
   ::File.exist?('/opt/cassandra/bin/cassandra')
  true
end

# Auto-detect DataStax Enterprise (DSE) 5.1 if not already explicitly
# configured. This cookbook only monitors DSE via axonops::agent — it never
# installs or manages it. See docs/DSE.md.
if node['axonops']['cassandra']['edition'] == 'apache' && AxonOpsCassandra.dse_installed?
  node.override['axonops']['cassandra']['edition'] = 'dse'
end

if node['axonops']['cassandra']['edition'] == 'dse'
  Chef::Log.info('DataStax Enterprise (DSE) detected — axonops::cassandra only monitors it via axonops::agent, it does not install or manage it.')
  include_recipe 'axonops::agent' if node['axonops']['agent']['enabled']
  return
end

package 'tar' do
  action :install
  only_if { platform_family?('rhel') }
end

# Install Java if not already installed. Select the Java major version required
# by the configured Cassandra version (3.11 -> 8, 4.1 -> 11, 5.0 -> 17).
unless node['axonops']['cassandra']['skip_java_install']
  node.override['java']['version'] = AxonOpsCassandra.java_major(node['axonops']['cassandra']['version'])
  include_recipe 'axonops::java'
end

# System tuning for Cassandra
include_recipe 'axonops::system_tuning' unless node['axonops']['cassandra']['skip_system_tuning']

include_recipe 'axonops::users'

# Create necessary directories
[
  node['axonops']['cassandra']['install_dir'],
  node['axonops']['cassandra']['data_dir'],
  node['axonops']['cassandra']['commitlog_directory'],
  node['axonops']['cassandra']['hints_directory'],
  node['axonops']['cassandra']['saved_caches_directory'],
  node['axonops']['cassandra']['log_dir'],
  node['axonops']['cassandra']['gc_log_dir'],
  '/etc/cassandra',
].flatten.each do |dir|
  directory dir do
    owner node['axonops']['cassandra']['user']
    group node['axonops']['cassandra']['group']
    mode '0755'
    recursive true
  end
end

# Create data directories (can be multiple)
node['axonops']['cassandra']['data_file_directories'].each do |dir|
  directory dir do
    owner node['axonops']['cassandra']['user']
    group node['axonops']['cassandra']['group']
    mode '0755'
    recursive true
  end
end

if node['axonops']['cassandra']['install_format'] == 'tar'
  include_recipe 'axonops::install_cassandra_tarball'
elsif node['axonops']['cassandra']['install_format'] == 'pkg'
  include_recipe 'axonops::install_cassandra_pkg'
else
  raise "Unsupported install_format: #{node['axonops']['cassandra']['install_format']}"
end

# If AxonOps agent is enabled, ensure it monitors this Cassandra
if node['axonops']['agent']['enabled']
  Chef::Log.info('AxonOps agent will monitor this Cassandra installation')
  include_recipe 'axonops::agent'
end

# Configure Cassandra
include_recipe 'axonops::configure_cassandra'

install_dir = node['axonops']['cassandra']['install_dir']
cassandra_current = "#{install_dir}/cassandra"
cassandra_user = node['axonops']['cassandra']['user']
cassandra_group = node['axonops']['cassandra']['group']

systemd_unit 'cassandra.service' do
  content({
            'Unit' => {
              'Description' => 'Apache Cassandra',
              'After' => 'network.target',
            },
            'Service' => {
              'Type' => 'forking',
              'ExecStart' => "#{cassandra_current}/bin/cassandra -p /var/run/cassandra/cassandra.pid",
              'User' => cassandra_user,
              'Group' => cassandra_group,
              'LimitNOFILE' => node['axonops']['cassandra']['limits']['nofile'],
              'LimitMEMLOCK' => 'infinity',
              'LimitNPROC' => 32768,
              'LimitAS' => 'infinity',
              'Environment' => "CASSANDRA_HOME=#{cassandra_current}",
              'PIDFile' => '/var/run/cassandra/cassandra.pid',
              'RuntimeDirectory' => 'cassandra',
              'RuntimeDirectoryMode' => '0755',
              'Restart' => 'on-failure',
              'RestartSec' => 10,
            },
            'Install' => {
              'WantedBy' => 'multi-user.target',
            },
          })
  action [:create, :enable, :start]
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
end

execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end
