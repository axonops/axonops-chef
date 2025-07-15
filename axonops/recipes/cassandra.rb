#
# Cookbook:: axonops
# Recipe:: cassandra
#
# Installs Apache Cassandra 5.0 for user applications
# This is separate from any Cassandra used internally by AxonOps server
#
# WARNING: THIS RECIPE IS FOR FRESH INSTALLATIONS ONLY!
# DO NOT USE THIS RECIPE TO UPGRADE EXISTING CASSANDRA CLUSTERS!
#

# Log prominent warnings
Chef::Log.warn('='*80)
Chef::Log.warn('WARNING: axonops::cassandra recipe is for FRESH INSTALLATIONS ONLY!')
Chef::Log.warn('DO NOT use this recipe to upgrade existing Cassandra installations!')
Chef::Log.warn('This recipe will overwrite configurations and may cause data loss!')
Chef::Log.warn('='*80)

# Check if Cassandra is already installed
cassandra_installed = false

# Check for existing Cassandra installation
if ::File.exist?('/etc/cassandra/cassandra.yaml') || 
   ::File.exist?('/etc/cassandra/conf/cassandra.yaml') ||
   ::File.exist?('/usr/bin/cassandra') ||
   ::File.exist?('/opt/cassandra/bin/cassandra')
  cassandra_installed = true
end

# Also check if the service exists
execute 'check_cassandra_service' do
  command 'systemctl list-units --type=service | grep -q cassandra'
  ignore_failure true
  action :run
  notifies :create, 'ruby_block[cassandra_already_installed]', :immediately
  only_if { node['platform_family'] == 'debian' || node['platform_family'] == 'rhel' }
end

ruby_block 'cassandra_already_installed' do
  block do
    cassandra_installed = true
  end
  action :nothing
end

# Fail if Cassandra is already installed and not forced
if cassandra_installed && !node['cassandra']['force_fresh_install']
  raise Chef::Exceptions::RecipeNotFound, <<-ERROR
ERROR: Existing Cassandra installation detected!

This recipe is designed for FRESH INSTALLATIONS ONLY and should NOT be used
to upgrade existing Cassandra clusters. Using this recipe on an existing
installation may:
  - Overwrite your current configuration
  - Reset cluster settings
  - Cause data loss
  - Break your existing cluster

If this is truly a fresh installation and you're seeing this error incorrectly,
you can force installation by setting:
  node['cassandra']['force_fresh_install'] = true

For existing clusters, use only the axonops::agent recipe to add monitoring.
ERROR
end

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

# Install Cassandra - we only support tarball installation
include_recipe 'axonops::install_cassandra_tarball'

# Configure Cassandra
include_recipe 'axonops::configure_cassandra'

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
