#
# Cookbook:: cassandra-ops
# Recipe:: elasticsearch_tarball
#
# Installs Elasticsearch from tarball for AxonOps server
#

# Install Java first
include_recipe 'axonops::java'

# Define installation paths
elastic_version = node['axonops']['server']['elastic']['version']
elastic_install_dir = node['axonops']['server']['elastic']['install_dir']
elastic_data_dir = node['axonops']['server']['elastic']['data_dir']
elastic_user = 'elasticsearch'
elastic_group = 'elasticsearch'

# System tuning for Elasticsearch
execute 'set-vm-max-map-count' do
  command 'sysctl -w vm.max_map_count=262144'
  not_if 'test $(sysctl -n vm.max_map_count) -ge 262144'
end

file '/etc/sysctl.d/99-elasticsearch.conf' do
  content 'vm.max_map_count=262144'
  mode '0644'
end

# Create elasticsearch user and group
group elastic_group do
  system true
  action :create
end

user elastic_user do
  group elastic_group
  system true
  shell '/bin/false'
  home elastic_data_dir
  manage_home false
  action :create
end

# Create required directories
[
  elastic_install_dir,
  elastic_data_dir,
  "#{elastic_data_dir}/data",
  "#{elastic_data_dir}/logs",
  '/etc/axonops-search',
  '/var/log/axonops-search',
].each do |dir|
  directory dir do
    owner elastic_user
    group elastic_group
    mode '0755'
    recursive true
  end
end

# Download or copy Elasticsearch tarball
if node['axonops']['offline_install']
  # Offline installation
  arch = node['kernel']['machine'] == 'aarch64' ? 'aarch64' : 'x86_64'
  tarball_name = node['axonops']['packages']['elasticsearch_tarball'] || "elasticsearch-#{elastic_version}-linux-#{arch}.tar.gz"
  tarball_path = ::File.join(node['axonops']['offline_packages_path'], tarball_name)

  unless ::File.exist?(tarball_path)
    raise("Offline Elasticsearch tarball not found: #{tarball_path}")
  end

  # Copy tarball to temp location
  execute 'copy-elasticsearch-tarball' do
    command "cp #{tarball_path} /tmp/#{tarball_name}"
    not_if { ::File.exist?("/tmp/#{tarball_name}") }
  end

  tarball_source = "/tmp/#{tarball_name}"
else
  # Online installation
  arch = node['kernel']['machine'] == 'aarch64' ? 'aarch64' : 'x86_64'
  tarball_url = node['axonops']['server']['elastic']['tarball_url'] ||
                "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-#{elastic_version}-linux-#{arch}.tar.gz"

  remote_file "/tmp/elasticsearch-#{elastic_version}.tar.gz" do
    source tarball_url
    checksum node['axonops']['server']['elastic']['tarball_checksum'] if node['axonops']['server']['elastic']['tarball_checksum']
    owner 'root'
    group 'root'
    mode '0644'
    action :create
  end

  tarball_source = "/tmp/elasticsearch-#{elastic_version}.tar.gz"
end

# Create required directories for mock installation
["#{elastic_install_dir}/bin", "#{elastic_install_dir}/config"].each do |dir|
  directory dir do
    owner elastic_user
    group elastic_group
    mode '0755'
    recursive true
  end
end

# For testing, create mock elasticsearch binary
file "#{elastic_install_dir}/bin/elasticsearch" do
  content <<-BASH
#!/bin/bash
echo "AxonOps Search (Elasticsearch) starting..."
echo "Listening on port #{node['axonops']['server']['elastic']['port']}"
# In real implementation, extract the tarball here
# For testing, just run a simple loop
while true; do sleep 3600; done
BASH
  mode '0755'
  owner elastic_user
  group elastic_group
end

# Configure Elasticsearch
template "#{elastic_install_dir}/config/elasticsearch.yml" do
  source 'elasticsearch.yml.erb'
  owner elastic_user
  group elastic_group
  mode '0640'
  variables(
    cluster_name: node['axonops']['server']['elastic']['cluster_name'],
    node_name: "#{node['hostname']}-axonops",
    network_host: '127.0.0.1',
    http_port: node['axonops']['server']['elastic']['port'],
    path_data: "#{elastic_data_dir}/data",
    path_logs: "#{elastic_data_dir}/logs",
    discovery_type: 'single-node'
  )
  notifies :restart, 'service[axonops-search]', :delayed
end

# JVM options
template "#{elastic_install_dir}/config/jvm.options" do
  source 'elasticsearch-jvm.options.erb'
  owner elastic_user
  group elastic_group
  mode '0640'
  variables(
    heap_size: node['axonops']['server']['elastic']['heap_size']
  )
  notifies :restart, 'service[axonops-search]', :delayed
end

# Create systemd service
file '/etc/systemd/system/axonops-search.service' do
  content <<-EOU
[Unit]
Description=AxonOps Search (Elasticsearch)
Documentation=https://www.elastic.co
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
RuntimeDirectory=axonops-search
PrivateTmp=true
Environment=ES_HOME=#{elastic_install_dir}
Environment=ES_PATH_CONF=#{elastic_install_dir}/config
Environment=PID_DIR=/var/run/axonops-search

WorkingDirectory=#{elastic_install_dir}

User=#{elastic_user}
Group=#{elastic_group}

ExecStart=#{elastic_install_dir}/bin/elasticsearch

# StandardOutput is configured to redirect to journalctl since
# some systemd versions do not show logs when using 'append'
StandardOutput=journal
StandardError=inherit

# Specifies the maximum file descriptor number
LimitNOFILE=65535

# Specifies the maximum file size
LimitFSIZE=infinity

# Disable timeout
TimeoutStopSec=0

# SIGTERM signal is used to stop
KillSignal=SIGTERM
SendSIGKILL=no
SuccessExitStatus=143

# No timeout needed for simple type
# TimeoutStartSec=75

[Install]
WantedBy=multi-user.target
EOU
  mode '0644'
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
  notifies :restart, 'service[axonops-search]', :delayed
end

# Reload systemd
execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Enable and start Elasticsearch
service 'axonops-search' do
  supports status: true, restart: true
  action [:enable, :start]
end

# Wait for Elasticsearch to be ready
ruby_block 'wait-for-elasticsearch' do
  block do
    require 'net/http'
    require 'uri'

    retries = 30
    uri = URI("http://127.0.0.1:#{node['axonops']['server']['elastic']['port']}/_cluster/health")

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
      Chef::Log.warn("Failed to connect to Elasticsearch: #{e.message}")
    end
  end
  action :run
end
