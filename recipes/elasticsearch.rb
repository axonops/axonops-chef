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
elastic_install_dir_versioned = "#{elastic_install_dir}-#{elastic_version}"
elastic_data_dir = node['axonops']['server']['elastic']['data_dir']
elastic_logs_dir = node['axonops']['server']['elastic']['logs_dir']
elastic_user = 'elasticsearch'
elastic_group = 'elasticsearch'

# System tuning for Elasticsearch
execute 'set-vm-max-map-count' do
  command 'sysctl -w vm.max_map_count=262144'
  not_if 'test $(sysctl -n vm.max_map_count) -ge 262144'
  not_if { node['axonops']['skip_vm_max_map_count'] }
end

file '/etc/sysctl.d/99-elasticsearch.conf' do
  content 'vm.max_map_count=262144'
  mode '0644'
  not_if { node['axonops']['skip_vm_max_map_count'] }
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
  elastic_install_dir_versioned,
  elastic_data_dir,
  elastic_logs_dir,
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
  tarball_path = ::File.join(node['axonops']['offline_packages_path'], node['axonops']['offline_packages']['elasticsearch'])

  unless ::File.exist?(tarball_path)
    raise("Offline Elasticsearch tarball not found: #{tarball_path}")
  end

  tarball_source = tarball_path
else
  # Online installation
  tarball_url = node['axonops']['server']['elastic']['tarball_url'] || 'https://artifacts.elastic.co/downloads/elasticsearch'
  arch = node['kernel']['machine'] == 'aarch64' ? 'aarch64' : 'x86_64'
  tarball_download_url = "#{tarball_url}/elasticsearch-#{elastic_version}-linux-#{arch}.tar.gz"

  remote_file "/tmp/elasticsearch-#{elastic_version}.tar.gz" do
    source tarball_download_url
    checksum node['axonops']['server']['elastic']['tarball_checksum'] if node['axonops']['server']['elastic']['tarball_checksum']
    owner 'root'
    group 'root'
    mode '0644'
    action :create
  end

  tarball_source = "/tmp/elasticsearch-#{elastic_version}.tar.gz"
end

execute 'extract-elasticsearch-tarball' do
  command "tar -xzf #{tarball_source} -C #{elastic_install_dir_versioned} --strip-components=1"
  creates "#{elastic_install_dir_versioned}/bin/elasticsearch"
  not_if { ::File.exist?("#{elastic_install_dir_versioned}/bin/elasticsearch") }
end

link elastic_install_dir do
  to elastic_install_dir_versioned
  action :create
end

directory elastic_install_dir do
  owner elastic_user
  group elastic_group
  mode '0755'
  recursive true # This will create /opt if it doesn't exist, then /opt/axonops-search
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
    listen_host: node['axonops']['server']['elastic']['listen_address'] || '127.0.0.1',
    listen_port: node['axonops']['server']['elastic']['listen_port'] || 9200,
    path_data: elastic_data_dir,
    path_logs: elastic_logs_dir,
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
    heap_size: node['axonops']['server']['elastic']['heap_size'],
    path_logs: elastic_logs_dir,
  )
  notifies :restart, 'service[axonops-search]', :delayed
end

# Set JAVA_HOME based on platform
if node['java']['install_from_package'] == false || node['axonops']['offline_install']
  java_home = node['java']['java_home']
elsif node['java']['zulu']
  java_home = node['java']['zulu_home'] || '/usr/lib/jvm/zulu-17-amd64'
else
  java_home = node['java']['openjdk_home'] || '/usr/lib/jvm/jre'
end

template '/etc/systemd/system/axonops-search.service' do
  source 'axonops-search.service.erb'
  mode '0644'
  variables(
    java_home: java_home,
    elastic_install_dir: elastic_install_dir,
    elastic_user: elastic_user,
    elastic_group: elastic_group
  )
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
  notifies :restart, 'service[axonops-search]', :delayed
end

execute "fix-elasticsearch-permissions" do
  command "chown -R #{elastic_user}:#{elastic_group} #{elastic_install_dir_versioned}"
  action :run
  only_if { ::File.exist?(elastic_install_dir_versioned) }
end

include_recipe 'axonops::elastic_self_signed'

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
