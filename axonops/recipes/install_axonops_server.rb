#
# Cookbook:: axonops
# Recipe:: install_axonops_server
#
# Installs AxonOps server for self-hosted deployments
#

# Only install server if self-hosted mode
unless node['axonops']['deployment_mode'] == 'self-hosted'
  Chef::Log.info('Skipping AxonOps server installation - not in self-hosted mode')
  return
end

# Ensure Java is installed
include_recipe 'axonops::java'

# Install Elasticsearch if needed
if node['axonops']['server']['elasticsearch']['install']
  include_recipe 'axonops::install_elasticsearch_tarball'
else
  # Verify external Elasticsearch is accessible
  http_request 'check_elasticsearch' do
    url node['axonops']['server']['elasticsearch']['url']
    action :head
    message 'Checking Elasticsearch availability'
    retries 3
    retry_delay 5
    ignore_failure true
  end
end

# Install Cassandra for metrics storage if needed
if node['axonops']['server']['cassandra']['install']
  # We'll use a separate Cassandra instance for metrics
  include_recipe 'axonops::cassandra_metrics'
else
  # Verify external Cassandra is accessible
  Chef::Log.info("Using external Cassandra at: #{node['axonops']['server']['cassandra']['hosts'].join(', ')}")
end

# Create AxonOps server user and group
group 'axonops' do
  system true
  action :create
end

user 'axonops' do
  group 'axonops'
  system true
  shell '/bin/false'
  home '/var/lib/axonops'
  manage_home false
  action :create
end

# Create necessary directories
%w[
  /etc/axonops
  /var/lib/axonops
  /var/lib/axonops/server
  /var/log/axonops
  /usr/share/axonops
].each do |dir|
  directory dir do
    owner 'axonops'
    group 'axonops'
    mode '0755'
    recursive true
  end
end

# Install AxonOps server package
if node['axonops']['offline_install']
  # Offline installation
  case node['platform_family']
  when 'debian'
    dpkg_package 'axon-server' do
      source ::File.join(node['axonops']['offline_packages_path'], 'axon-server_latest_all.deb')
      action :install
      notifies :restart, 'service[axon-server]', :delayed
    end
  when 'rhel', 'fedora'
    rpm_package 'axon-server' do
      source ::File.join(node['axonops']['offline_packages_path'], 'axon-server-latest.noarch.rpm')
      action :install
      notifies :restart, 'service[axon-server]', :delayed
    end
  end
else
  # Online installation - Add repository if not already added
  if node['axonops']['repository']['enabled']
    case node['platform_family']
    when 'debian'
      # Add AxonOps APT repository if not already added
      apt_repository 'axonops' do
        uri "#{node['axonops']['repository']['url']}/apt"
        components ['main']
        distribution 'axonops'
        key "#{node['axonops']['repository']['url']}/apt/repo-signing.key"
        action :add
        not_if { ::File.exist?('/etc/apt/sources.list.d/axonops.list') }
      end
      
      apt_update 'axonops-server' do
        action :update
      end
      
      package 'axon-server' do
        action :install
        notifies :restart, 'service[axon-server]', :delayed
      end
    when 'rhel', 'fedora'
      yum_repository 'axonops' do
        description 'AxonOps Repository'
        baseurl "#{node['axonops']['repository']['url']}/yum"
        gpgkey "#{node['axonops']['repository']['url']}/yum/repo-signing.key"
        gpgcheck true
        enabled true
        action :create
        not_if { ::File.exist?('/etc/yum.repos.d/axonops.repo') }
      end
      
      package 'axon-server' do
        action :install
        notifies :restart, 'service[axon-server]', :delayed
      end
    end
  end
end

# Configure AxonOps server
template '/etc/axonops/axon-server.properties' do
  source 'axon-server.properties.erb'
  owner 'axonops'
  group 'axonops'
  mode '0640'
  variables(
    listen_address: node['axonops']['server']['listen_address'],
    listen_port: node['axonops']['server']['listen_port'],
    elasticsearch_url: node['axonops']['server']['elasticsearch']['url'],
    cassandra_hosts: node['axonops']['server']['cassandra']['hosts'],
    data_dir: '/var/lib/axonops/server',
    log_dir: '/var/log/axonops'
  )
  notifies :restart, 'service[axon-server]', :delayed
end

# Create systemd service for AxonOps server
systemd_unit 'axon-server.service' do
  content(
    Unit: {
      Description: 'AxonOps Server',
      After: 'network.target elasticsearch.service cassandra.service',
      Wants: 'elasticsearch.service'
    },
    Service: {
      Type: 'simple',
      User: 'axonops',
      Group: 'axonops',
      ExecStart: '/usr/bin/axon-server',
      Restart: 'on-failure',
      RestartSec: '10',
      StandardOutput: 'journal',
      StandardError: 'journal',
      SyslogIdentifier: 'axon-server',
      Environment: [
        'JAVA_HOME=/usr/lib/jvm/zulu17',
        'AXONOPS_HOME=/usr/share/axonops'
      ],
      LimitNOFILE: '65536',
      LimitMEMLOCK: 'infinity'
    },
    Install: {
      WantedBy: 'multi-user.target'
    }
  )
  action [:create, :enable]
  notifies :restart, 'service[axon-server]', :delayed
end

# Configure firewall if needed
if node['axonops']['server']['configure_firewall']
  case node['platform_family']
  when 'debian'
    execute 'ufw-allow-axonops' do
      command "ufw allow #{node['axonops']['server']['listen_port']}/tcp"
      not_if "ufw status | grep -q #{node['axonops']['server']['listen_port']}"
    end
  when 'rhel', 'fedora'
    execute 'firewall-cmd-allow-axonops' do
      command "firewall-cmd --permanent --add-port=#{node['axonops']['server']['listen_port']}/tcp && firewall-cmd --reload"
      not_if "firewall-cmd --list-ports | grep -q #{node['axonops']['server']['listen_port']}"
    end
  end
end

# Wait for Elasticsearch to be ready
ruby_block 'wait_for_elasticsearch' do
  block do
    require 'net/http'
    require 'uri'
    
    uri = URI.parse(node['axonops']['server']['elasticsearch']['url'])
    retries = 30
    
    begin
      response = Net::HTTP.get_response(uri)
      unless response.code.to_i == 200
        raise "Elasticsearch not ready: #{response.code}"
      end
    rescue => e
      if retries > 0
        retries -= 1
        Chef::Log.info("Waiting for Elasticsearch... (#{e.message})")
        sleep 5
        retry
      else
        raise "Elasticsearch failed to start: #{e.message}"
      end
    end
  end
  only_if { node['axonops']['server']['elasticsearch']['install'] }
end

# Start and enable AxonOps server
service 'axon-server' do
  supports status: true, restart: true, reload: true
  action [:enable, :start]
end

# Initialize AxonOps database schema
execute 'initialize-axonops-schema' do
  command '/usr/bin/axon-server --init-schema'
  user 'axonops'
  group 'axonops'
  environment(
    'JAVA_HOME' => '/usr/lib/jvm/zulu17',
    'AXONOPS_HOME' => '/usr/share/axonops'
  )
  not_if { ::File.exist?('/var/lib/axonops/server/.schema_initialized') }
  notifies :create, 'file[/var/lib/axonops/server/.schema_initialized]', :immediately
end

file '/var/lib/axonops/server/.schema_initialized' do
  owner 'axonops'
  group 'axonops'
  mode '0644'
  action :nothing
end

# Create default admin user if needed
ruby_block 'create_default_admin' do
  block do
    # This would typically use the AxonOps API to create a default admin user
    # For now, we'll just log that manual setup is required
    Chef::Log.info('AxonOps server installed. Please create admin user via the web interface.')
  end
  only_if { node['axonops']['server']['create_default_admin'] }
end

# Log installation info
log 'axonops-server-installation' do
  message "AxonOps server installed and running at http://#{node['axonops']['server']['listen_address']}:#{node['axonops']['server']['listen_port']}"
  level :info
end