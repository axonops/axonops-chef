#
# Cookbook:: axonops
# Recipe:: agent
#
# Installs and configures AxonOps monitoring agent
# Works with existing Cassandra installations
#
# IMPORTANT: This recipe should be run AFTER recipes/cassandra.rb
# if you're installing Cassandra via this cookbook. The agent needs
# Cassandra to be installed first in order to properly detect and
# configure monitoring for the Cassandra installation.
#

# Check for existing Cassandra installation
if ::File.exist?('/etc/cassandra/cassandra.yaml') || 
   ::File.exist?('/etc/cassandra/conf/cassandra.yaml') ||
   ::File.exist?('/usr/bin/cassandra') ||
   ::File.exist?('/opt/cassandra/bin/cassandra')
  cassandra_installed = true
else
  cassandra_installed = false
  Chef::Log.warn("WARNING: No Cassandra installation detected. If you're installing Cassandra via this cookbook, ensure 'axonops::cassandra' recipe runs BEFORE 'axonops::agent'")
end

include_recipe 'axonops::common'

# Add AxonOps repository unless offline
unless node['axonops']['offline_install']
  include_recipe 'axonops::repo'
end

# Detect existing Cassandra installation
cassandra_home = nil
cassandra_config = nil
cassandra_detected = false

# Common Cassandra installation paths
cassandra_search_paths = [
  '/opt/cassandra',
  '/usr/share/cassandra',
  '/var/lib/cassandra',
  '/opt/apache-cassandra*',
  '/opt/dse',
  node['axonops']['cassandra']['install_dir'],
].compact.uniq

# Search for Cassandra installation
ruby_block 'detect-cassandra' do
  block do
    cassandra_search_paths.each do |path|
      expanded_paths = Dir.glob(path)
      expanded_paths.each do |expanded_path|
        next unless ::File.exist?("#{expanded_path}/bin/cassandra")
        cassandra_home = expanded_path
        # Look for config directory
        %w(conf config /etc/cassandra /etc/dse/cassandra).each do |conf_dir|
          full_conf_path = conf_dir.start_with?('/') ? conf_dir : "#{cassandra_home}/#{conf_dir}"
          if ::File.exist?("#{full_conf_path}/cassandra.yaml")
            cassandra_config = full_conf_path
            break
          end
        end
        cassandra_detected = true
        break
      end
      break if cassandra_detected
    end

    # Store in node for use in templates
    node.run_state['cassandra_home'] = cassandra_home || node['axonops']['agent']['cassandra_home']
    node.run_state['cassandra_config'] = cassandra_config || node['axonops']['agent']['cassandra_config']

    Chef::Log.info("Detected Cassandra installation at: #{cassandra_home}") if cassandra_home
    Chef::Log.info("Detected Cassandra config at: #{cassandra_config}") if cassandra_config
  end
end

# Install AxonOps agent package
if node['axonops']['offline_install']
  # Offline installation from local package
  if node['axonops']['agent']['package'].nil?
    raise('Offline installation requested but axonops.packages.agent not specified')
  end

  package_path = ::File.join(node['axonops']['offline_packages_path'], node['axonops']['agent']['package'])

  unless ::File.exist?(package_path)
    raise("Offline package not found: #{package_path}")
  end

  case node['platform_family']
  when 'debian'
    dpkg_package node['axonops']['java_agent']['package'] do
      source ::File.join(node['axonops']['offline_packages_path'], node['axonops']['java_agent']['package'])
      action :install
    end
    dpkg_package 'axon-agent' do
      source package_path
      action :install
      notifies :restart, 'service[axon-agent]', :delayed
    end
  when 'rhel', 'fedora'
    rpm_package node['axonops']['java_agent']['package'] do
      source ::File.join(node['axonops']['offline_packages_path'], node['axonops']['java_agent']['package'])
      action :install
      notifies :restart, 'service[axon-agent]', :delayed
    end
    rpm_package 'axon-agent' do
      source package_path
      action :install
      notifies :restart, 'service[axon-agent]', :delayed
    end
  end
else
  package 'axon-agent' do
    action :install
    notifies :restart, 'service[axon-agent]', :delayed
  end
  package node['axonops']['java_agent']['package'] do
    action :install
  end
end

# Enable and start AxonOps agent
service 'axon-agent' do
  supports status: true, restart: true, reload: true
  action [:enable, :start]
end

# Determine connection settings based on deployment mode
agent_host = node['axonops']['agent']['hosts']
agent_port = node['axonops']['agent']['port']

if node['axonops']['deployment_mode'] == 'self-hosted' && node['axonops']['server']['enabled']
  agent_host = node['axonops']['server']['listen_address']
  agent_port = node['axonops']['server']['listen_port']
end

# Generate agent configuration
template '/etc/axonops/axon-agent.yml' do
  source 'axon-agent.yml.erb'
  owner node['axonops']['agent']['user']
  group node['axonops']['agent']['group']
  mode '0640'
  variables lazy {
    {
      deployment_mode: node['axonops']['deployment_mode'],
      org_key: node['axonops']['agent']['api_key'] || node['axonops']['agent']['org_key'],
      org_name: node['axonops']['agent']['org_name'],
      agent_host: agent_host,
      agent_port: agent_port,
      disable_command_exec: node['axonops']['agent']['disable_command_exec'],
      node_address: node['axonops']['cassandra']['listen_address'] || node['ipaddress'],
      node_dc: node['axonops']['cassandra']['dc'] || 'dc1',
      node_rack: node['axonops']['cassandra']['rack'] || 'rack1',
      pkg: node['axonops']['java_agent']['package'],
      # Additional variables for new template
      cassandra_home: node.run_state['cassandra_home'] || node['axonops']['agent']['cassandra_home'],
      cassandra_config: node.run_state['cassandra_config'] || node['axonops']['agent']['cassandra_config'],
      cassandra_logs: node['axonops']['cassandra']['directories']['logs'],
      org_agent_hostname: node['axonops']['agent']['hostname'] || nil,
      cluster_name: node['axonops']['cassandra']['cluster_name'],
      human_readable_identifier: node['axonops']['agent']['human_readable_identifier'] || nil,
      force_send_all_metrics_prom: node['axonops']['agent']['force_send_all_metrics_prom'] || nil,
      tmp_path: node['axonops']['agent']['tmp_path'] || nil,
      tls_mode: node['axonops']['agent']['tls_mode'] || nil,
      tls_cafile: node['axonops']['agent']['tls_cafile'] || nil,
      tls_certfile: node['axonops']['agent']['tls_certfile'] || nil,
      tls_keyfile: node['axonops']['agent']['tls_keyfile'] || nil,
      tls_skipverify: node['axonops']['agent']['tls_skipverify'] || false,
      backup_purge_interval: node['axonops']['agent']['backup_purge_interval'] || nil,
      scripts_location: node['axonops']['agent']['scripts_location'] || '/var/lib/axonops/scripts/',
      ntp_server: node['axonops']['agent']['ntp_server'] || 'pool.ntp.org',
      ntp_timeout: node['axonops']['agent']['ntp_timeout'] || 6,
      upper_lower_case_dse_template_var: node['axonops']['agent']['upper_lower_case_dse_template_var'] || nil,
      include_service_config: node['axonops']['agent']['include_service_config'] || false,
      warn_threshold_millis: node['axonops']['agent']['warn_threshold_millis'] || 1000,
    }
  }
  notifies :restart, 'service[axon-agent]', :delayed
  sensitive true if node['axonops']['agent']['api_key']
end

ruby_block 'configure-cassandra-jvm-agent' do
  cassandra_home = node.run_state['cassandra_home']
  return unless cassandra_home
  agent_line = ". /usr/share/axonops/axonops-jvm.options"

  block do
    file = Chef::Util::FileEdit.new("#{cassandra_home}/conf/cassandra-env.sh")
    file.insert_line_if_no_match(agent_line)
    file.write_file
  end

  notifies :restart, 'service[cassandra]', :delayed
  only_if { node.run_state['cassandra_home'] }
end

# Log configuration info
log 'axonops-agent-info' do
  message lazy {
    if node.run_state['cassandra_home']
      "AxonOps agent configured to monitor Cassandra at: #{node.run_state['cassandra_home']}"
    else
      'AxonOps agent installed but no Cassandra installation detected. Please configure cassandra_home manually.'
    end
  }
  level :info
end
