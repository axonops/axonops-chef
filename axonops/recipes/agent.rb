#
# Cookbook:: axonops
# Recipe:: agent
#
# Installs and configures AxonOps monitoring agent
# Works with existing Cassandra installations
#

# Add AxonOps repository unless offline
unless node['axonops']['offline_install']
  include_recipe 'axonops::repo'
end

# Create axonops user and group
group node['axonops']['agent']['group'] do
  system true
end

user node['axonops']['agent']['user'] do
  group node['axonops']['agent']['group']
  system true
  shell '/bin/false'
  home '/var/lib/axonops'
  manage_home true
end

# Create necessary directories
%w(
  /etc/axonops
  /var/log/axonops
  /var/lib/axonops
  /usr/share/axonops
).each do |dir|
  directory dir do
    owner node['axonops']['agent']['user']
    group node['axonops']['agent']['group']
    mode '0755'
  end
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
  node['cassandra']['install_dir'],
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
  if node['axonops']['packages']['agent'].nil?
    raise('Offline installation requested but axonops.packages.agent not specified')
  end

  package_path = ::File.join(node['axonops']['offline_packages_path'], node['axonops']['packages']['agent'])

  unless ::File.exist?(package_path)
    raise("Offline package not found: #{package_path}")
  end

  case node['platform_family']
  when 'debian'
    dpkg_package 'axon-agent' do
      source package_path
      action :install
      notifies :restart, 'service[axon-agent]', :delayed
    end
  when 'rhel', 'fedora'
    rpm_package 'axon-agent' do
      source package_path
      action :install
      notifies :restart, 'service[axon-agent]', :delayed
    end
  end
else
  # Online installation from repository
  package 'axon-agent' do
    version node['axonops']['agent']['version'] unless node['axonops']['agent']['version'] == 'latest'
    action :install
    notifies :restart, 'service[axon-agent]', :delayed
  end
end

# Install AxonOps Java agent
java_agent_filename = node['axonops']['packages']['java_agent'] || "#{node['axonops']['java_agent']['package']}-#{node['axonops']['java_agent']['version']}.jar"
java_agent_target = "/usr/share/axonops/#{java_agent_filename}"

if node['axonops']['offline_install']
  # Copy from local packages directory
  java_agent_source = ::File.join(node['axonops']['offline_packages_path'], java_agent_filename)

  unless ::File.exist?(java_agent_source)
    raise("Offline Java agent package not found: #{java_agent_source}")
  end

  file java_agent_target do
    content lazy { ::File.read(java_agent_source) }
    owner node['axonops']['agent']['user']
    group node['axonops']['agent']['group']
    mode '0644'
    action :create
  end
else
  # Download from repository
  remote_file java_agent_target do
    source "#{node['axonops']['repository']['url']}/files/java-agent/#{node['axonops']['java_agent']['version']}/#{node['axonops']['java_agent']['package']}.jar"
    owner node['axonops']['agent']['user']
    group node['axonops']['agent']['group']
    mode '0644'
    action :create
  end
end

# Create symlink for Java agent
link node['axonops']['java_agent']['jar_path'] do
  to java_agent_target
  owner node['axonops']['agent']['user']
  group node['axonops']['agent']['group']
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
  mode '0600'
  variables lazy {
    {
      api_key: node['axonops']['agent']['api_key'],
      org_name: node['axonops']['agent']['org_name'],
      agent_host: agent_host,
      agent_port: agent_port,
      disable_command_exec: node['axonops']['agent']['disable_command_exec'],
      cassandra_home: node.run_state['cassandra_home'] || node['axonops']['agent']['cassandra_home'],
      cassandra_config: node.run_state['cassandra_config'] || node['axonops']['agent']['cassandra_config'],
      cassandra_logs: node['cassandra']['directories']['logs'],
      node_address: node['cassandra']['listen_address'] || node['ipaddress'],
      node_dc: node['cassandra']['dc'],
      node_rack: node['cassandra']['rack'],
    }
  }
  notifies :restart, 'service[axon-agent]', :delayed
  sensitive true if node['axonops']['agent']['api_key']
end

# Configure Cassandra JVM for AxonOps Java agent if Cassandra is detected
ruby_block 'configure-cassandra-jvm-agent' do
  block do
    cassandra_home = node.run_state['cassandra_home']
    return unless cassandra_home

    # Look for JVM options file (varies by Cassandra version)
    jvm_files = [
      "#{cassandra_home}/conf/jvm-server.options",
      "#{cassandra_home}/conf/jvm.options",
      "#{cassandra_home}/conf/cassandra-env.sh",
    ]

    jvm_files.each do |jvm_file|
      next unless ::File.exist?(jvm_file)
      content = ::File.read(jvm_file)
      agent_line = "-javaagent:#{node['axonops']['java_agent']['jar_path']}"

      unless content.include?(agent_line)
        if jvm_file.end_with?('.sh')
          # For cassandra-env.sh, add to JVM_OPTS
          content.sub!(/^JVM_OPTS="\$JVM_OPTS/, "JVM_OPTS=\"$JVM_OPTS #{agent_line}")
        else
          # For .options files, just append
          ::File.open(jvm_file, 'a') do |f|
            f.puts "\n# AxonOps Java Agent"
            f.puts agent_line
          end
        end
      end

      Chef::Log.info("Added AxonOps Java agent to #{jvm_file}")
      break
    end
  end
  notifies :restart, 'service[cassandra]', :delayed
  only_if { node.run_state['cassandra_home'] }
end

# Create systemd service override directory
directory '/etc/systemd/system/axon-agent.service.d' do
  owner 'root'
  group 'root'
  mode '0755'
end

# Create systemd override for service configuration
template '/etc/systemd/system/axon-agent.service.d/override.conf' do
  source 'systemd-override.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    user: node['axonops']['agent']['user'],
    group: node['axonops']['agent']['group'],
    limits: {
      'LimitNOFILE' => '65536',
    }
  )
  notifies :run, 'execute[systemctl-daemon-reload-agent]', :immediately
  notifies :restart, 'service[axon-agent]', :delayed
end

# Reload systemd
execute 'systemctl-daemon-reload-agent' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Enable and start AxonOps agent
service 'axon-agent' do
  supports status: true, restart: true, reload: true
  action [:enable, :start]
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
