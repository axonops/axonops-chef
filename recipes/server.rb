#
# Cookbook:: axonops
# Recipe:: server
#
# Deploys AxonOps Server for self-hosted monitoring
#
if node['axonops']['server']['cassandra']['install']
  # Override cassandra attributes with server attributes only if they are not nil
  node['axonops']['server']['cassandra'].each do |key, value|
    unless value.nil?
      node.override['axonops']['cassandra'][key] = value
    end
  end
  include_recipe 'axonops::cassandra'
end

# Install dependencies if needed
if node['axonops']['server']['elastic']['install']
  include_recipe 'axonops::elastic'
end

# Add AxonOps repository unless offline
unless node['axonops']['offline_install']
  include_recipe 'axonops::repo'
end

include_recipe 'axonops::common'

# Install AxonOps server package
if node['axonops']['offline_install']
  # Offline installation from local package
  if node['axonops']['server']['package'].nil?
    raise('Offline installation requested but axonops.packages.server not specified')
  end

  package_path = ::File.join(node['axonops']['offline_packages_path'], node['axonops']['server']['package'])

  unless ::File.exist?(package_path)
    raise("Offline package not found: #{package_path}")
  end

  case node['platform_family']
  when 'debian'
    dpkg_package node['axonops']['server']['package'] do
      source package_path
      action :install
      notifies :restart, 'service[axon-server]', :delayed
    end
  when 'rhel', 'fedora'
    rpm_package node['axonops']['server']['package'] do
      source package_path
      action :install
      notifies :restart, 'service[axon-server]', :delayed
    end
  end
else
  # Online installation from repository
  package node['axonops']['server']['package'] do
    version node['axonops']['server']['version'] unless node['axonops']['server']['version'] == 'latest'
    action :install
    notifies :restart, 'service[axon-server]', :delayed
  end
end

cassandra_hosts = node['axonops']['server']['cassandra']['hosts'] || ['127.0.0.1']

# Determine server version to decide configuration format
# Version 2.0.4 and above use the new search_db format
server_version = node['axonops']['server']['version']
use_new_format = if server_version == 'latest' || server_version.nil?
                   true # Assume latest supports new format
                 else
                   # Parse version and compare
                   require 'chef/version_constraint'
                   Chef::VersionConstraint.new('>= 2.0.4').include?(server_version)
                 end

# Prepare configuration based on version
if use_new_format
  # New format for axon-server >= 2.0.4
  search_db_hosts = node['axonops']['server']['search_db']['hosts'] || ['http://localhost:9200/']
  elastic_host = nil
  elastic_port = nil
else
  # Old format for axon-server < 2.0.4
  search_db_hosts = nil
  # Extract host and port from the first search_db host or use defaults
  if node['axonops']['server']['search_db']['hosts'] && !node['axonops']['server']['search_db']['hosts'].empty?
    url = URI.parse(node['axonops']['server']['search_db']['hosts'].first.chomp('/'))
    elastic_host = url.host || '127.0.0.1'
    elastic_port = url.port || 9200
  else
    elastic_host = node['axonops']['server']['elastic']['listen_address'] || '127.0.0.1'
    elastic_port = node['axonops']['server']['elastic']['listen_port'] || 9200
  end
end

# Generate server configuration
template '/etc/axonops/axon-server.yml' do
  source 'axon-server.yml.erb'
  owner node['axonops']['agent']['user']
  group node['axonops']['agent']['group']
  mode '0640'
  variables(
    listen_address: node['axonops']['server']['listen_address'],
    listen_port: node['axonops']['server']['listen_port'],
    use_new_format: use_new_format,
    search_db_hosts: search_db_hosts,
    search_db_username: node['axonops']['server']['search_db']['username'],
    search_db_password: node['axonops']['server']['search_db']['password'],
    search_db_skip_verify: node['axonops']['server']['search_db']['skip_verify'],
    search_db_replicas: node['axonops']['server']['search_db']['replicas'],
    search_db_shards: node['axonops']['server']['search_db']['shards'],
    elastic_host: elastic_host,
    elastic_port: elastic_port,
    cassandra_hosts: cassandra_hosts,
    cassandra_dc: node['axonops']['server']['cassandra']['dc'] || node['axonops']['cassandra']['dc'],
    cassandra_username: node['axonops']['server']['cassandra']['username'],
    cassandra_password: node['axonops']['server']['cassandra']['password'],
    tls_mode: node['axonops']['server']['tls']['mode'],
    tls_cert_file: node['axonops']['server']['tls']['cert_file'],
    tls_key_file: node['axonops']['server']['tls']['key_file'],
    tls_ca_file: node['axonops']['server']['tls']['ca_file'],
    retention: node['axonops']['server']['retention']
  )
  notifies :restart, 'service[axon-server]', :delayed
end

# TLS certificate validation
if %w(TLS mTLS).include?(node['axonops']['server']['tls']['mode'])
  unless node['axonops']['server']['tls']['cert_file'] && node['axonops']['server']['tls']['key_file']
    raise 'TLS certificate and key files must be specified when TLS is enabled'
  end

  # Ensure certificate files exist
  [node['axonops']['server']['tls']['cert_file'],
   node['axonops']['server']['tls']['key_file'],
   node['axonops']['server']['tls']['ca_file']].compact.each do |file|
    file file do
      action :create_if_missing
      owner node['axonops']['agent']['user']
      group node['axonops']['agent']['group']
      mode '0600'
    end
  end
end

# Reload systemd
execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Enable and start AxonOps server
service 'axon-server' do
  supports status: true, restart: true, reload: true
  action [:enable, :start]
end

# Wait for server to be ready
ruby_block 'wait-for-axon-server' do
  block do
    require 'net/http'
    require 'uri'

    retries = 30
    uri = URI("http://#{node['axonops']['server']['listen_address']}:#{node['axonops']['server']['listen_port']}/health")

    begin
      retries.times do
        begin
          response = Net::HTTP.get_response(uri)
          break if response.code == '200'
        rescue
          # Connection refused, keep trying
        end
        sleep 2
      end
    rescue StandardError => e
      Chef::Log.warn("Failed to connect to AxonOps server: #{e.message}")
    end
  end
  action :run
end

Chef::Log.info("AxonOps server deployed and available at http://#{node['axonops']['server']['listen_address']}:#{node['axonops']['server']['listen_port']}")
