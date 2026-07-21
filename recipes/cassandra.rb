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
  only_if { platform_family?('rhel', 'fedora', 'amazon') }
end

# Install Java if not already installed. Select the Java major version required
# by the configured Cassandra version (3.11 -> 8, 4.1 -> 11, 5.0 -> 17).
unless node['axonops']['cassandra']['skip_java_install']
  node.override['java']['version'] = AxonOpsCassandra.java_major(node['axonops']['cassandra']['version'])

  # A Cassandra RPM/deb package declares a real `java-X.Y.Z-headless`
  # dependency — only an actually-installed OS package registers that with
  # rpm/dnf/dpkg, a tarball-extracted JDK doesn't (confirmed live: `dnf
  # install cassandra-3.11.19-...rpm` fails with "nothing provides
  # java-1.8.0-headless" against a tarball-only Java install). Force the
  # package-based install path (recipes/java.rb) instead of tarball whenever
  # install_format is 'pkg' — this only affects java.rb's offline branch;
  # online installs already go through the package repo either way.
  if node['axonops']['cassandra']['install_format'] == 'pkg'
    node.override['java']['package'] = true
  end

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

# Provision cqlsh in a dedicated Python virtualenv so it works on hosts whose
# system Python is >= 3.12 (Ubuntu 24.04+, Debian 13), where the bundled cqlsh
# aborts importing removed stdlib modules (asyncore, imp). See docs/CASSANDRA.md.
include_recipe 'axonops::cqlsh_venv' if node['axonops']['cassandra']['cqlsh_venv']['enabled']

# The systemd unit itself (tar installs only) is created by
# axonops::configure_cassandra's template resource — creating it here too
# used to duplicate that file with different content, whichever recipe ran
# last won, and Cassandra could time out starting under the stale version.
execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end
