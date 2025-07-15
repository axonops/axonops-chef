#
# Cookbook:: axonops
# Recipe:: install_axonops_agent
#
# Installs AxonOps agent on Cassandra nodes
#

# Detect if we have an existing Cassandra installation
cassandra_home = node['axonops']['agent']['cassandra_home']
cassandra_config = node['axonops']['agent']['cassandra_config']

# Auto-detect Cassandra if not specified
if cassandra_home.nil?
  # Check common installation paths
  %w[
    /opt/cassandra/cassandra
    /opt/cassandra
    /usr/share/cassandra
    /var/lib/cassandra
    /etc/cassandra
  ].each do |path|
    if ::File.exist?("#{path}/bin/cassandra") || ::File.exist?("#{path}/conf/cassandra.yaml")
      cassandra_home = path
      break
    end
  end
  
  if cassandra_home.nil?
    raise "Cannot find Cassandra installation. Please set node['axonops']['agent']['cassandra_home']"
  end
end

# Find Cassandra config directory if not specified
if cassandra_config.nil?
  %w[
    conf
    etc/cassandra
    etc/cassandra/conf
  ].each do |conf_path|
    full_path = "#{cassandra_home}/#{conf_path}"
    if ::File.exist?("#{full_path}/cassandra.yaml")
      cassandra_config = full_path
      break
    elsif ::File.exist?("/etc/cassandra/conf/cassandra.yaml")
      cassandra_config = "/etc/cassandra/conf"
      break
    elsif ::File.exist?("/etc/cassandra/cassandra.yaml")
      cassandra_config = "/etc/cassandra"
      break
    end
  end
  
  if cassandra_config.nil?
    raise "Cannot find Cassandra configuration directory. Please set node['axonops']['agent']['cassandra_config']"
  end
end

Chef::Log.info("Found Cassandra installation at: #{cassandra_home}")
Chef::Log.info("Found Cassandra config at: #{cassandra_config}")

# Determine Cassandra version to select appropriate agent
cassandra_version = nil
if ::File.exist?("#{cassandra_home}/bin/cassandra")
  version_cmd = Mixlib::ShellOut.new("#{cassandra_home}/bin/cassandra -v", env: { 'JAVA_HOME' => node['java']['java_home'] })
  version_cmd.run_command
  if version_cmd.exitstatus == 0
    version_output = version_cmd.stdout.strip
    if version_output =~ /^(\d+\.\d+)/
      cassandra_version = $1
    end
  end
end

# Determine appropriate agent package based on Cassandra version
agent_package = case cassandra_version
                when /^5\.0/
                  'axon-cassandra5-agent'
                when /^4\.1/
                  'axon-cassandra41-agent'
                when /^4\.0/
                  'axon-cassandra40-agent'
                when /^3\.11/
                  'axon-cassandra311-agent'
                when /^3\./
                  'axon-cassandra3-agent'
                else
                  # Default to latest
                  'axon-cassandra5-agent'
                end

# Java agent package for JVM integration
java_agent_package = case cassandra_version
                     when /^5\.0/
                       'axon-cassandra5.0-agent-jdk17'
                     when /^4\./
                       'axon-cassandra4-agent-jdk11'
                     when /^3\./
                       'axon-cassandra3-agent-jdk8'
                     else
                       node['axonops']['java_agent']['package']
                     end

# Create AxonOps user and group
group node['axonops']['agent']['group'] do
  system true
  action :create
end

user node['axonops']['agent']['user'] do
  group node['axonops']['agent']['group']
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
  /var/log/axonops
  /usr/share/axonops
].each do |dir|
  directory dir do
    owner node['axonops']['agent']['user']
    group node['axonops']['agent']['group']
    mode '0755'
    recursive true
  end
end

# Install AxonOps agent
if node['axonops']['offline_install']
  # Offline installation
  case node['platform_family']
  when 'debian'
    # Install from local DEB package
    dpkg_package agent_package do
      source ::File.join(node['axonops']['offline_packages_path'], "#{agent_package}_latest_all.deb")
      action :install
    end
    
    dpkg_package java_agent_package do
      source ::File.join(node['axonops']['offline_packages_path'], "#{java_agent_package}_latest_all.deb")
      action :install
    end
  when 'rhel', 'fedora'
    # Install from local RPM package
    rpm_package agent_package do
      source ::File.join(node['axonops']['offline_packages_path'], "#{agent_package}-latest.noarch.rpm")
      action :install
    end
    
    rpm_package java_agent_package do
      source ::File.join(node['axonops']['offline_packages_path'], "#{java_agent_package}-latest.noarch.rpm")
      action :install
    end
  end
else
  # Online installation - Add repository if enabled
  if node['axonops']['repository']['enabled']
    case node['platform_family']
    when 'debian'
      # Add AxonOps APT repository
      apt_repository 'axonops' do
        uri "#{node['axonops']['repository']['url']}/apt"
        components ['main']
        distribution 'axonops'
        key "#{node['axonops']['repository']['url']}/apt/repo-signing.key"
        action :add
      end
      
      # Update apt cache
      apt_update 'axonops' do
        action :update
      end
      
      # Install packages
      package [agent_package, java_agent_package] do
        action :install
      end
    when 'rhel', 'fedora'
      # Add AxonOps YUM repository
      yum_repository 'axonops' do
        description 'AxonOps Repository'
        baseurl "#{node['axonops']['repository']['url']}/yum"
        gpgkey "#{node['axonops']['repository']['url']}/yum/repo-signing.key"
        gpgcheck true
        enabled true
        action :create
      end
      
      # Install packages
      package [agent_package, java_agent_package] do
        action :install
      end
    end
  end
end

# Configure AxonOps agent
template '/etc/axonops/axon-agent.yml' do
  source 'axon-agent.yml.erb'
  owner node['axonops']['agent']['user']
  group node['axonops']['agent']['group']
  mode '0640'
  variables(
    deployment_mode: node['axonops']['deployment_mode'],
    api_key: node['axonops']['api']['key'],
    organization: node['axonops']['api']['organization'],
    hosts: node['axonops']['agent']['hosts'],
    port: node['axonops']['agent']['port'],
    disable_command_exec: node['axonops']['agent']['disable_command_exec'],
    cassandra_home: cassandra_home,
    cassandra_config: cassandra_config,
    cassandra_version: cassandra_version
  )
  notifies :restart, 'service[axon-agent]', :delayed
end

# Update Cassandra JVM options to include AxonOps Java agent
ruby_block 'add_axonops_java_agent' do
  block do
    jvm_options_file = "#{cassandra_config}/jvm-server.options"
    jvm11_options_file = "#{cassandra_config}/jvm11-server.options"
    jvm8_options_file = "#{cassandra_config}/jvm8-server.options"
    
    # Determine which JVM options file to use
    jvm_file = if ::File.exist?(jvm_options_file)
                 jvm_options_file
               elsif ::File.exist?(jvm11_options_file)
                 jvm11_options_file
               elsif ::File.exist?(jvm8_options_file)
                 jvm8_options_file
               else
                 # Try cassandra-env.sh as fallback
                 "#{cassandra_config}/cassandra-env.sh"
               end
    
    if ::File.exist?(jvm_file)
      content = ::File.read(jvm_file)
      agent_jar = node['axonops']['java_agent']['jar_path']
      
      # Check if agent is already configured
      unless content.include?('axon-cassandra-agent')
        Chef::Log.info("Adding AxonOps Java agent to #{jvm_file}")
        
        if jvm_file.end_with?('.sh')
          # For cassandra-env.sh
          agent_line = "JVM_OPTS=\"$JVM_OPTS -javaagent:#{agent_jar}\""
          ::File.open(jvm_file, 'a') do |f|
            f.puts "\n# AxonOps Java Agent"
            f.puts agent_line
          end
        else
          # For JVM options files
          agent_line = "-javaagent:#{agent_jar}"
          ::File.open(jvm_file, 'a') do |f|
            f.puts "\n# AxonOps Java Agent"
            f.puts agent_line
          end
        end
      end
    else
      Chef::Log.warn("Could not find JVM options file for Cassandra")
    end
  end
  notifies :restart, 'service[cassandra]', :delayed if node['cassandra']['auto_restart']
end

# Create systemd service for AxonOps agent
systemd_unit 'axon-agent.service' do
  content(
    Unit: {
      Description: 'AxonOps Agent',
      After: 'network.target'
    },
    Service: {
      Type: 'simple',
      User: node['axonops']['agent']['user'],
      Group: node['axonops']['agent']['group'],
      ExecStart: '/usr/bin/axon-agent',
      Restart: 'on-failure',
      RestartSec: '10',
      StandardOutput: 'journal',
      StandardError: 'journal',
      SyslogIdentifier: 'axon-agent'
    },
    Install: {
      WantedBy: 'multi-user.target'
    }
  )
  action [:create, :enable]
  notifies :restart, 'service[axon-agent]', :delayed
end

# Start and enable AxonOps agent service
service 'axon-agent' do
  supports status: true, restart: true, reload: true
  action [:enable, :start]
end

# Log installation info
log 'axonops-agent-installation' do
  message "AxonOps agent installed and configured for Cassandra #{cassandra_version} at #{cassandra_home}"
  level :info
end