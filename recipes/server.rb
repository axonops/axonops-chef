#
# Cookbook:: axonops
# Recipe:: server
#
# Deploys AxonOps Server for self-hosted monitoring
#
if node['axonops']['server']['cassandra']['install']
  # The configuration for Cassandra is now in the server attributes
  node['axonops']['server']['cassandra'].each do |key, value|
    node.override['axonops']['cassandra'][key] = value
  end
  include_recipe 'axonops::cassandra'
end

# Install dependencies if needed
if node['axonops']['server']['elasticsearch']['install']
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

# Determine Elasticsearch and Cassandra endpoints
elastic_url = if node['axonops']['server']['elasticsearch']['install']
                'http://127.0.0.1:9200'
              else
                node['axonops']['server']['elasticsearch']['url']
              end

cassandra_hosts = if node['axonops']['server']['cassandra']['install']
                    ['127.0.0.1']
                  else
                    node['axonops']['server']['cassandra']['hosts']
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
    elastic_host: elastic_url,
    elastic_port: URI.parse(elastic_url).port || 9200,
    cassandra_hosts: cassandra_hosts,
    cassandra_dc: node['axonops']['server']['cassandra']['dc'],
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
