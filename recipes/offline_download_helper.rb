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
Chef::Log.info("  default['axonops']['packages']['agent'] = 'axon-agent_VERSION_ARCH.deb'")
Chef::Log.info("  default['axonops']['packages']['server'] = 'axon-server_VERSION_ARCH.deb'")
Chef::Log.info("  default['axonops']['packages']['dashboard'] = 'axon-dash_VERSION_ARCH.deb'")
Chef::Log.info("  default['axonops']['packages']['java_agent'] = 'axon-cassandraVER-agent-jdkVER.jar'")
Chef::Log.info('')
Chef::Log.info('Replace VERSION and ARCH with actual values for your packages.')
Chef::Log.info('=' * 80)

# Create a sample download script
template ::File.join(download_path, 'download-packages.sh') do
  source 'offline-download-script.sh.erb'
  mode '0755'
  variables(
    agent_version: node['axonops']['agent']['version'],
    server_version: node['axonops']['server']['version'],
    dashboard_version: node['axonops']['dashboard']['version'],
    java_agent_version: node['axonops']['java_agent']['version'],
    java_agent_package: node['axonops']['java_agent']['package'],
    repository_url: node['axonops']['repository']['url'],
    cassandra_version: node['axonops']['server']['cassandra']['version'],
    elastic_version: node['axonops']['server']['elastic']['version'],
    zulu_version: node['java']['zulu']['version'],
    zulu_build: node['java']['zulu']['build']
  )
  action :create
end

Chef::Log.info('')
Chef::Log.info("A sample download script has been created at: #{download_path}/download-packages.sh")
Chef::Log.info('However, we strongly recommend using the official downloader from GitHub.')
Chef::Log.info('')
