#
# Cookbook:: axonops
# Recipe:: install_elasticsearch_tarball
#
# Installs Elasticsearch 7.x from tarball for AxonOps metrics storage
#

# Only install if needed for self-hosted AxonOps
unless node['axonops']['server']['elasticsearch']['install']
  Chef::Log.info('Skipping Elasticsearch installation - using external instance')
  return
end

# Ensure Java is installed first
include_recipe 'axonops::java'

# Configuration
elasticsearch_version = node['elasticsearch']['version'] || '7.17.26'
elasticsearch_user = 'elasticsearch'
elasticsearch_group = 'elasticsearch'
install_dir = '/opt/elasticsearch'
data_dir = '/var/lib/elasticsearch'

# Installation paths
tarball_name = "elasticsearch-#{elasticsearch_version}-linux-#{node['kernel']['machine'] == 'aarch64' ? 'aarch64' : 'x86_64'}.tar.gz"
elasticsearch_home = "#{install_dir}/elasticsearch-#{elasticsearch_version}"
elasticsearch_current = "#{install_dir}/elasticsearch"

# Create elasticsearch user and group
group elasticsearch_group do
  system true
  action :create
end

user elasticsearch_user do
  group elasticsearch_group
  system true
  shell '/bin/false'
  home data_dir
  manage_home false
  action :create
end

# Create base directories
[install_dir, data_dir, '/var/log/elasticsearch'].each do |dir|
  directory dir do
    owner dir == install_dir ? 'root' : elasticsearch_user
    group dir == install_dir ? 'root' : elasticsearch_group
    mode '0755'
    recursive true
  end
end

# Determine tarball source
if node['axonops']['offline_install']
  # Offline installation
  tarball_path = ::File.join(node['axonops']['offline_packages_path'], tarball_name)
  
  unless ::File.exist?(tarball_path)
    # Try alternate naming
    alt_tarball = ::File.join(node['axonops']['offline_packages_path'], "elasticsearch-#{elasticsearch_version}.tar.gz")
    if ::File.exist?(alt_tarball)
      tarball_path = alt_tarball
    else
      raise Chef::Exceptions::FileNotFound, "Offline installation requested but tarball not found: #{tarball_path}"
    end
  end
else
  # Online installation - download from Elastic
  tarball_url = "https://artifacts.elastic.co/downloads/elasticsearch/#{tarball_name}"
  tarball_path = "#{Chef::Config[:file_cache_path]}/#{tarball_name}"
  
  remote_file tarball_path do
    source tarball_url
    mode '0644'
    action :create
    not_if { ::File.exist?(elasticsearch_home) }
  end
end

# Extract Elasticsearch
execute 'extract-elasticsearch' do
  command "tar -xzf #{tarball_path} -C #{install_dir}"
  creates elasticsearch_home
  notifies :run, 'execute[fix-elasticsearch-permissions]', :immediately
end

# Fix permissions
execute 'fix-elasticsearch-permissions' do
  command "chown -R #{elasticsearch_user}:#{elasticsearch_group} #{elasticsearch_home}"
  action :nothing
end

# Create symlink for easier management
link elasticsearch_current do
  to elasticsearch_home
  link_type :symbolic
end

# Create Elasticsearch directories
%w[
  data
  logs
  tmp
].each do |dir|
  directory "#{data_dir}/#{dir}" do
    owner elasticsearch_user
    group elasticsearch_group
    mode '0750'
    recursive true
  end
end

# Create config directory
directory '/etc/elasticsearch' do
  owner 'root'
  group elasticsearch_group
  mode '0750'
end

# Symlink configuration directory
link '/etc/elasticsearch/config' do
  to "#{elasticsearch_current}/config"
  link_type :symbolic
end

# Configure Elasticsearch
template "#{elasticsearch_current}/config/elasticsearch.yml" do
  source 'elasticsearch.yml.erb'
  owner elasticsearch_user
  group elasticsearch_group
  mode '0640'
  variables(
    cluster_name: 'axonops-metrics',
    node_name: node['hostname'],
    path_data: "#{data_dir}/data",
    path_logs: '/var/log/elasticsearch',
    network_host: node['axonops']['server']['elasticsearch']['bind_address'] || '127.0.0.1',
    http_port: 9200,
    discovery_type: 'single-node',  # For single node setup
    heap_size: node['elasticsearch']['heap_size'] || '2g'
  )
  notifies :restart, 'service[elasticsearch]', :delayed
end

# Configure JVM options
template "#{elasticsearch_current}/config/jvm.options" do
  source 'elasticsearch-jvm.options.erb'
  owner elasticsearch_user
  group elasticsearch_group
  mode '0640'
  variables(
    heap_size: node['elasticsearch']['heap_size'] || '2g'
  )
  notifies :restart, 'service[elasticsearch]', :delayed
end

# Add Elasticsearch bin to PATH
file '/etc/profile.d/elasticsearch.sh' do
  content <<-EOH
export ES_HOME=#{elasticsearch_current}
export PATH=$PATH:$ES_HOME/bin
EOH
  mode '0644'
end

# Create systemd service file
systemd_unit 'elasticsearch.service' do
  content(
    Unit: {
      Description: 'Elasticsearch',
      Documentation: 'https://www.elastic.co',
      Wants: 'network-online.target',
      After: 'network-online.target'
    },
    Service: {
      Type: 'notify',
      RuntimeDirectory: 'elasticsearch',
      PrivateTmp: true,
      Environment: [
        "ES_HOME=#{elasticsearch_current}",
        "ES_PATH_CONF=#{elasticsearch_current}/config",
        "JAVA_HOME=#{node['java']['java_home']}"
      ],
      WorkingDirectory: elasticsearch_current,
      User: elasticsearch_user,
      Group: elasticsearch_group,
      ExecStart: "#{elasticsearch_current}/bin/elasticsearch",
      StandardOutput: 'journal',
      StandardError: 'inherit',
      LimitNOFILE: '65535',
      LimitNPROC: '4096',
      LimitAS: 'infinity',
      LimitFSIZE: 'infinity',
      TimeoutStopSec: '0',
      KillSignal: 'SIGTERM',
      KillMode: 'process',
      SendSIGKILL: 'no',
      SuccessExitStatus: '143',
      TimeoutStartSec: '75'
    },
    Install: {
      WantedBy: 'multi-user.target'
    }
  )
  action [:create, :enable]
  notifies :restart, 'service[elasticsearch]', :delayed
end

# Set system limits
file '/etc/security/limits.d/elasticsearch.conf' do
  content <<-EOH
#{elasticsearch_user} - nofile 65535
#{elasticsearch_user} - nproc 4096
#{elasticsearch_user} - memlock unlimited
EOH
  mode '0644'
end

# Kernel tuning
execute 'set-vm-max-map-count-es' do
  command 'sysctl -w vm.max_map_count=262144'
  not_if 'test $(sysctl -n vm.max_map_count) -ge 262144'
end

file '/etc/sysctl.d/99-elasticsearch.conf' do
  content 'vm.max_map_count=262144'
  mode '0644'
end

# Disable swap for Elasticsearch
execute 'disable-swap' do
  command 'swapoff -a'
  only_if 'swapon -s | grep -q "^/"'
end

# Start and enable Elasticsearch service
service 'elasticsearch' do
  supports status: true, restart: true, reload: false
  action [:enable, :start]
end

# Wait for Elasticsearch to be ready
ruby_block 'wait_for_elasticsearch' do
  block do
    require 'net/http'
    require 'uri'
    
    uri = URI.parse('http://127.0.0.1:9200')
    retries = 30
    
    begin
      response = Net::HTTP.get_response(uri)
      unless response.code.to_i == 200
        raise "Elasticsearch not ready: #{response.code}"
      end
      Chef::Log.info("Elasticsearch is ready at http://127.0.0.1:9200")
    rescue => e
      if retries > 0
        retries -= 1
        Chef::Log.info("Waiting for Elasticsearch to start... (#{e.message})")
        sleep 5
        retry
      else
        raise "Elasticsearch failed to start: #{e.message}"
      end
    end
  end
end

# Log installation info
log 'elasticsearch-installation' do
  message "Elasticsearch #{elasticsearch_version} installed at #{elasticsearch_home}"
  level :info
end