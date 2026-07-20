#
# Cookbook:: axonops
# Recipe:: offline_download_helper
#
# Ships the standalone offline-package downloader to a node and prints usage.
#
# The download logic no longer lives in an ERB template baked from node
# attributes — it is a static, Chef-free script (files/default/download-packages.sh)
# driven entirely by CLI flags. This recipe now just copies that script into
# node['axonops']['offline_packages_path'] and logs a recommended command line
# derived from the node's current attributes, so existing
# `include_recipe 'axonops::offline_download_helper'` users keep working.
#
# You do NOT need Chef to use the downloader: run
# files/default/download-packages.sh directly on any internet-connected machine
# with --components to pick what to fetch. See README / docs/OFFLINE.md.
#

download_path = node['axonops']['offline_packages_path']

# --- Build a recommended command line from the node's current attributes so
# the logged guidance matches how this node is configured. Purely advisory —
# the shipped script has its own built-in defaults and 'latest' fallbacks.
edition = node['axonops']['cassandra']['edition']
install_format = node['axonops']['cassandra']['install_format']

# DSE monitors an existing Cassandra (never downloads/installs it), so the
# 'cassandra' component is only meaningful for the apache edition.
components = %w(java agent server dashboard)
components.unshift('cassandra') if edition != 'dse'

recommended_args = ["--components #{components.join(',')}"]
recommended_args << "--edition #{edition}" if edition != 'apache'
recommended_args << "--dse-version #{node['axonops']['cassandra']['dse_version']}" if edition == 'dse'
recommended_args << "--cassandra-version #{node['axonops']['cassandra']['version']}" if edition != 'dse'
recommended_args << "--cassandra-install-format #{install_format}" if edition != 'dse' && install_format != 'tar'
recommended_args << "--repo-url #{node['axonops']['repository']['url']}"

# Create download directory
directory download_path do
  recursive true
  mode '0755'
end

# Ship the standalone downloader onto the node.
cookbook_file ::File.join(download_path, 'download-packages.sh') do
  source 'download-packages.sh'
  mode '0755'
  action :create
end

# Log instructions
Chef::Log.info('=' * 80)
Chef::Log.info('AxonOps Offline Package Download Helper')
Chef::Log.info('=' * 80)
Chef::Log.info('')
Chef::Log.info("A standalone downloader has been installed at: #{download_path}/download-packages.sh")
Chef::Log.info('It needs NO Chef — run it on any machine with internet access and pick the')
Chef::Log.info('components to fetch, then copy the results to your airgapped target.')
Chef::Log.info('')
Chef::Log.info('Recommended command for this node:')
Chef::Log.info("  #{download_path}/download-packages.sh #{recommended_args.join(' ')}")
Chef::Log.info('')
Chef::Log.info('Component sets (mix and match with --components):')
Chef::Log.info('  cassandra                                  # just the Cassandra tarball/pkg')
Chef::Log.info('  cassandra,java                             # + Azul Zulu JDK')
Chef::Log.info('  cassandra,java,agent                       # + axon-agent + java-agent')
Chef::Log.info('  cassandra,java,agent,server,dashboard      # full self-hosted stack')
Chef::Log.info('')
Chef::Log.info("The script prints the exact node['axonops']['offline_packages'][*]")
Chef::Log.info('attribute values to set once it finishes.')
Chef::Log.info('')
Chef::Log.info('For comprehensive downloads AxonOps also publishes:')
Chef::Log.info('  https://github.com/axonops/axonops-installer-packages-downloader')
Chef::Log.info('=' * 80)
