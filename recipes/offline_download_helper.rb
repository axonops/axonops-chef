#
# Cookbook:: cassandra-ops
# Recipe:: offline_download_helper
#
# Helper recipe to download AxonOps packages for offline installation
#

# This recipe helps download AxonOps packages for airgapped environments
# It's meant to be run on a machine with internet access

require 'fileutils'

download_path = node['axonops']['offline_packages_path']

# attributes/agent.rb and attributes/default.rb default these to the literal
# string 'latest' — meaningful to a `package` resource's `version` property
# (apt/yum resolve the keyword themselves), but useless once spliced into a
# download URL/filename, which is all this sample script does with them.
# Pin known-good fallbacks so the generated script works out of the box;
# update by re-checking `dnf list --showduplicates axon-agent axon-server
# axon-dash axon-cassandra3.11-agent` against packages.axonops.com.
LATEST_KNOWN_PACKAGE_VERSIONS = {
  agent: '2.0.30',
  server: '2.0.34',
  dashboard: '2.0.36',
  java_agent: '1.0.14',
}.freeze

resolve_version = lambda do |attr_version, key|
  attr_version == 'latest' ? LATEST_KNOWN_PACKAGE_VERSIONS.fetch(key) : attr_version
end

# The *monitored* Cassandra (axonops::cassandra / axonops::agent) — drives
# java_agent_package and, for package installs, the Cassandra RPM download.
# Distinct from node['axonops']['server']['cassandra']['version'] below, which
# is the separate metrics-storage Cassandra bundled with axonops::server and
# is only ever fetched as a tarball.
monitored_cassandra_version = node['axonops']['cassandra']['version']

# Same resolution order as recipes/agent.rb: explicit override wins, DSE
# resolves from dse_version (there is no generic 'axon-dse-agent' package),
# otherwise derive from the Cassandra series so 3.11/4.1/5.0 each get the
# right axon-cassandra*-agent package instead of always defaulting to the
# 5.0/jdk17 build.
java_agent_package = if node['axonops']['cassandra']['edition'] == 'dse'
                        node['axonops']['java_agent']['dse'] ||
                          AxonOpsCassandra.dse_java_agent_package(node['axonops']['cassandra']['dse_version'])
                      elsif node['axonops']['java_agent']['package'] != 'axon-cassandra5.0-agent-jdk17'
                        node['axonops']['java_agent']['package']
                      else
                        AxonOpsCassandra.java_agent_package(monitored_cassandra_version)
                      end

# Create download directory
directory download_path do
  recursive true
  mode '0755'
end

# Log instructions
Chef::Log.info('=' * 80)
Chef::Log.info('AxonOps Offline Package Download Helper')
Chef::Log.info('=' * 80)
Chef::Log.info('')
Chef::Log.info('For comprehensive offline package downloading, we recommend using:')
Chef::Log.info('https://github.com/axonops/axonops-installer-packages-downloader')
Chef::Log.info('')
Chef::Log.info('This tool will download all necessary AxonOps packages for your platform.')
Chef::Log.info('')
Chef::Log.info('Usage:')
Chef::Log.info('1. Clone the repository on a machine with internet access')
Chef::Log.info('2. Run the download script for your target platform')
Chef::Log.info("3. Copy the downloaded packages to: #{download_path}")
Chef::Log.info('4. Configure your Chef attributes for offline installation:')
Chef::Log.info('')
Chef::Log.info("  default['axonops']['offline_install'] = true")
Chef::Log.info("  default['axonops']['offline_packages_path'] = '#{download_path}'")
Chef::Log.info("  default['axonops']['offline_packages']['agent'] = 'axon-agent_VERSION_ARCH.deb'")
Chef::Log.info("  default['axonops']['offline_packages']['server'] = 'axon-server_VERSION_ARCH.deb'")
Chef::Log.info("  default['axonops']['offline_packages']['dashboard'] = 'axon-dash_VERSION_ARCH.deb'")
Chef::Log.info("  default['axonops']['offline_packages']['java_agent'] = 'axon-cassandraVER-agent-jdkVER.jar'")
Chef::Log.info('')
Chef::Log.info('Replace VERSION and ARCH with actual values for your packages.')
Chef::Log.info('=' * 80)

# Create a sample download script
template ::File.join(download_path, 'download-packages.sh') do
  source 'offline-download-script.sh.erb'
  mode '0755'
  variables(
    agent_version: resolve_version.call(node['axonops']['agent']['version'], :agent),
    server_version: resolve_version.call(node['axonops']['server']['version'], :server),
    dashboard_version: resolve_version.call(node['axonops']['dashboard']['version'], :dashboard),
    java_agent_version: resolve_version.call(node['axonops']['java_agent']['version'], :java_agent),
    java_agent_package: java_agent_package,
    repository_url: node['axonops']['repository']['url'],
    cassandra_version: node['axonops']['server']['cassandra']['version'],
    edition: node['axonops']['cassandra']['edition'],
    dse_version: node['axonops']['cassandra']['dse_version'],
    monitored_cassandra_version: monitored_cassandra_version,
    # DSE only ever downloads the java-agent, never a Cassandra package —
    # the series is meaningless/possibly unresolvable for a DSE version
    # string, so skip computing it rather than risk an ArgumentError.
    monitored_cassandra_series: node['axonops']['cassandra']['edition'] == 'dse' ? nil : AxonOpsCassandra.series(monitored_cassandra_version),
    monitored_cassandra_install_format: node['axonops']['cassandra']['install_format'],
    redhat_repository_url_311x: node['axonops']['cassandra']['redhat_repository_url_311x'],
    elastic_version: node['axonops']['server']['elastic']['version'],
    zulu_version: node['java']['zulu_tarball_version'],
    zulu_build: node['java']['zulu_tarball_build']
  )
  action :create
end

Chef::Log.info('')
Chef::Log.info("A sample download script has been created at: #{download_path}/download-packages.sh")
Chef::Log.info('However, we strongly recommend using the official downloader from GitHub.')
Chef::Log.info('')
