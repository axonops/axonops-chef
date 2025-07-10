#
# Cookbook:: axonops
# Recipe:: cassandra
#
# Installs Apache Cassandra 5.0 for user applications
# This is separate from any Cassandra used internally by AxonOps server
#

# Install Java if not already installed
unless node['cassandra']['skip_java_install']
  include_recipe 'axonops::java'
end

# System tuning for Cassandra
# TODO: Fix system_tuning recipe
# include_recipe 'axonops::system_tuning'

# Create Cassandra user and group
group node['cassandra']['group'] do
  system true
end

user node['cassandra']['user'] do
  group node['cassandra']['group']
  system true
  shell '/bin/false'
  home '/var/lib/cassandra'
  manage_home true
end

# Create necessary directories
[
  node['cassandra']['install_dir'],
  node['cassandra']['directories']['data'],
  node['cassandra']['directories']['hints'],
  node['cassandra']['directories']['saved_caches'],
  node['cassandra']['directories']['commitlog'],
  node['cassandra']['directories']['logs'],
  node['cassandra']['directories']['gc_logs'],
  '/etc/cassandra',
].each do |dir|
  directory dir do
    owner node['cassandra']['user']
    group node['cassandra']['group']
    mode '0755'
    recursive true
  end
end

# Install Cassandra based on format
case node['cassandra']['install_format']
when 'tar', 'tarball'
  include_recipe 'axonops::install_cassandra_tarball'
when 'package'
  include_recipe 'axonops::install_cassandra_package'
else
  raise("Unsupported install format: #{node['cassandra']['install_format']}")
end

# Configure Cassandra
include_recipe 'axonops::configure_cassandra'

# Setup service
include_recipe 'axonops::cassandra_service'

# Configure security if enabled
if node['cassandra']['authenticator'] != 'AllowAllAuthenticator'
  include_recipe 'axonops::cassandra_security'
end

# Configure audit logging if enabled
if node['cassandra']['audit_log']['enabled']
  include_recipe 'axonops::cassandra_audit_logging'
end

# If AxonOps agent is enabled, ensure it monitors this Cassandra
if node['axonops']['agent']['enabled']
  Chef::Log.info('AxonOps agent will monitor this Cassandra installation')
  include_recipe 'axonops::agent'
end
