#
# Cookbook:: axonops
# Recipe:: multi_node_cassandra_real
#
# Deploys Cassandra with real AxonOps agent for multi-node testing
#

Chef::Log.info("Setting up Cassandra node with REAL AxonOps agent at #{node['ipaddress']}")

# Set up for offline installation with real packages
node.override['axonops']['offline_install'] = true
node.override['axonops']['offline_packages_dir'] = '/vagrant/offline_packages'

# Common setup
include_recipe 'axonops::_common'

# Install Java first
include_recipe 'axonops::java'

# Install and configure Cassandra for the application
Chef::Log.info("Installing Cassandra for application use...")
include_recipe 'axonops::install_cassandra_tarball'
include_recipe 'axonops::configure_cassandra'

# Update apt cache for dependencies
execute 'apt-update' do
  command 'apt-get update'
  action :run
end

# Install dependencies
package %w[adduser procps python3] do
  action :install
end

# Install real AxonOps Agent package
agent_deb = Dir.glob("#{node['axonops']['offline_packages_dir']}/axon-agent_*.deb").first
if agent_deb
  Chef::Log.info("Installing real AxonOps Agent from #{agent_deb}")
  
  execute 'install-axon-agent' do
    command "dpkg --force-architecture --force-depends -i #{agent_deb}"
    action :run
    not_if "dpkg -l | grep -q '^ii  axon-agent '"
  end
  
  # Configure agent to connect to AxonOps server
  file '/etc/axonops/axon-agent.yml' do
    content <<-YAML
agent:
  name: #{node['hostname']}
  
server:
  hosts: ["#{node['axonops']['multi_node']['server_ip']}:8080"]
  
cassandra:
  hosts: ["localhost:9042"]
  jmx_host: localhost
  jmx_port: 7199
  
monitoring:
  interval: 60
  
logging:
  level: INFO
  file: /var/log/axonops/agent.log
YAML
    owner 'axonops'
    group 'axonops'
    mode '0640'
    notifies :restart, 'service[axon-agent]'
  end
  
  service 'axon-agent' do
    action [:enable, :start]
  end
else
  Chef::Log.error("axon-agent package not found in #{node['axonops']['offline_packages_dir']}")
end

# Install Java agent for Cassandra monitoring
java_agent_jar = Dir.glob("#{node['axonops']['offline_packages_dir']}/axon-cassandra*-agent*.jar").first ||
                 Dir.glob("#{node['axonops']['offline_packages_dir']}/axon-cassandra*-agent*.deb").first

if java_agent_jar
  Chef::Log.info("Found Java agent: #{java_agent_jar}")
  
  if java_agent_jar.end_with?('.deb')
    # It's a deb package, install it
    execute "install-java-agent" do
      command "dpkg --force-architecture -i #{java_agent_jar}"
      action :run
      not_if "dpkg -l | grep -q '^ii  axon-cassandra.*-agent'"
    end
    
    # Find the installed jar
    java_agent_path = "/usr/share/axonops/axon-cassandra-agent.jar"
  else
    # It's a jar file, copy it
    java_agent_path = "/usr/share/axonops/axon-cassandra-agent.jar"
    file java_agent_path do
      content lazy { ::File.read(java_agent_jar) }
      owner 'axonops'
      group 'axonops'
      mode '0644'
    end
  end
  
  # Add Java agent to Cassandra JVM options
  cassandra_jvm_options = "#{node['cassandra']['install_dir']}/conf/jvm-server.options"
  
  ruby_block 'add-axonops-java-agent' do
    block do
      if ::File.exist?(cassandra_jvm_options)
        content = ::File.read(cassandra_jvm_options)
        agent_line = "-javaagent:#{java_agent_path}"
        
        unless content.include?(agent_line)
          ::File.open(cassandra_jvm_options, 'a') do |f|
            f.puts "\n# AxonOps Java Agent"
            f.puts agent_line
          end
          Chef::Log.info("Added AxonOps Java agent to Cassandra JVM options")
        end
      end
    end
    notifies :restart, 'service[cassandra]', :delayed
  end
else
  Chef::Log.warn("No Java agent found in #{node['axonops']['offline_packages_dir']}")
end

# Ensure Cassandra is running
service 'cassandra' do
  action [:enable, :start]
end

# Log success
log 'cassandra-agent-info' do
  message <<-MSG
  
  Cassandra node configured with REAL AxonOps agent!
  ==================================================
  
  Components installed:
  - Cassandra: localhost:9042 (cluster: #{node['cassandra']['cluster_name']})
  - AxonOps Agent: Monitoring Cassandra
  - Java Agent: Integrated with Cassandra JVM
  
  Agent configured to report to:
  - AxonOps Server: http://#{node['axonops']['multi_node']['server_ip']}:8080
  
  Note: Agent may fail to start on ARM64 with AMD64 binary.
  Check logs in /var/log/axonops/ for details.
  
  MSG
  level :info
end