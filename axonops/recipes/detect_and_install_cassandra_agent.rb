#
# Cookbook:: axonops
# Recipe:: detect_and_install_cassandra_agent
#
# Detects installed JDK version and installs appropriate Cassandra agent
#

# Get offline packages directory
offline_dir = node['axonops']['offline_packages_dir'] || File.join(Chef::Config[:file_cache_path], 'offline_packages')

# Detect Java version
ruby_block 'detect_java_version' do
  block do
    # Try to detect Java version
    java_cmd = nil
    java_version = nil
    
    # Check common Java locations
    possible_java_paths = [
      '/usr/bin/java',
      '/usr/local/bin/java',
      '/opt/java/bin/java',
      '/usr/lib/jvm/default-java/bin/java',
      '/usr/lib/jvm/java-17-openjdk-amd64/bin/java',
      '/usr/lib/jvm/java-11-openjdk-amd64/bin/java',
      '/usr/lib/jvm/java-8-openjdk-amd64/bin/java'
    ]
    
    # Also check if JAVA_HOME is set
    if ENV['JAVA_HOME']
      possible_java_paths.unshift("#{ENV['JAVA_HOME']}/bin/java")
    end
    
    # Check Cassandra's java.home system property if Cassandra is running
    if File.exist?('/etc/cassandra/cassandra-env.sh')
      cassandra_java = `grep -E "JAVA_HOME|JRE_HOME" /etc/cassandra/cassandra-env.sh 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"'`.strip
      if !cassandra_java.empty? && File.exist?("#{cassandra_java}/bin/java")
        possible_java_paths.unshift("#{cassandra_java}/bin/java")
      end
    end
    
    # Find first working Java
    possible_java_paths.each do |path|
      if File.exist?(path)
        java_cmd = path
        break
      end
    end
    
    # If still not found, try which
    java_cmd ||= `which java 2>/dev/null`.strip
    
    if java_cmd && !java_cmd.empty?
      # Get Java version
      version_output = `#{java_cmd} -version 2>&1`
      
      # Parse version - handles different formats:
      # openjdk version "17.0.2" 2022-01-18
      # java version "1.8.0_312"
      # openjdk version "11.0.13" 2021-10-19
      if version_output =~ /version\s+"(\d+)\.(\d+)\.(\d+)/
        major = $1.to_i
        minor = $2.to_i
        
        # Handle old versioning (1.8 = Java 8, 1.7 = Java 7)
        if major == 1
          java_version = minor
        else
          java_version = major
        end
      elsif version_output =~ /version\s+"(\d+)"/
        java_version = $1.to_i
      end
      
      Chef::Log.info("Detected Java #{java_version} at: #{java_cmd}")
      node.run_state['detected_java_version'] = java_version
      node.run_state['detected_java_path'] = java_cmd
    else
      Chef::Log.warn("Could not detect Java installation")
      # Default to Java 17 if we can't detect
      node.run_state['detected_java_version'] = 17
    end
  end
  action :run
end

# Install appropriate Cassandra Java agent based on detected version
ruby_block 'install_cassandra_java_agent' do
  block do
    java_version = node.run_state['detected_java_version'] || 17
    cassandra_version = node['cassandra']['version'] || '5.0'
    cassandra_major = cassandra_version.split('.')[0..1].join('.')
    
    # Determine which agent package to use based on Java version
    agent_package_name = if java_version >= 17
                          "axon-cassandra#{cassandra_major}-agent-jdk17"
                        elsif java_version >= 11
                          "axon-cassandra#{cassandra_major}-agent-jdk11"
                        elsif java_version >= 8
                          # Some versions use jdk8, some use default
                          if cassandra_major.to_f >= 4.0
                            "axon-cassandra#{cassandra_major}-agent-jdk8"
                          else
                            "axon-cassandra#{cassandra_major}-agent"
                          end
                        else
                          "axon-cassandra#{cassandra_major}-agent"
                        end
    
    # Find the package file
    agent_pattern = "#{agent_package_name}_*.deb"
    agent_deb = Dir.glob("#{offline_dir}/#{agent_pattern}").first
    
    if agent_deb
      Chef::Log.info("Installing Cassandra agent for Java #{java_version}: #{File.basename(agent_deb)}")
      
      # Install the package
      require 'chef/mixin/shell_out'
      extend Chef::Mixin::ShellOut
      
      install_cmd = shell_out!("dpkg -i #{agent_deb}")
      Chef::Log.info("Agent installation output: #{install_cmd.stdout}")
      
      # Store the installed agent info
      node.run_state['installed_cassandra_agent'] = agent_package_name
      node.run_state['cassandra_agent_jar_path'] = "/usr/share/axonops/axon-cassandra#{cassandra_major}-agent.jar"
    else
      # If specific version not found, try fallback
      Chef::Log.warn("Specific agent package not found: #{agent_pattern}")
      
      # Try generic agent as fallback
      fallback_pattern = "axon-cassandra#{cassandra_major}-agent_*.deb"
      fallback_deb = Dir.glob("#{offline_dir}/#{fallback_pattern}").reject { |f| f.include?('jdk') }.first
      
      if fallback_deb
        Chef::Log.info("Using fallback agent: #{File.basename(fallback_deb)}")
        install_cmd = shell_out!("dpkg -i #{fallback_deb}")
        node.run_state['installed_cassandra_agent'] = "axon-cassandra#{cassandra_major}-agent"
        node.run_state['cassandra_agent_jar_path'] = "/usr/share/axonops/axon-cassandra#{cassandra_major}-agent.jar"
      else
        Chef::Log.error("No suitable Cassandra agent found for Cassandra #{cassandra_major} with Java #{java_version}")
      end
    end
  end
  action :run
  only_if { node['axonops']['agent']['java_agent']['enabled'] }
end

# Configure Cassandra to use the Java agent
ruby_block 'configure_cassandra_java_agent' do
  block do
    if node.run_state['cassandra_agent_jar_path']
      jar_path = node.run_state['cassandra_agent_jar_path']
      
      # Update Cassandra JVM options to include the agent
      jvm_options_file = '/etc/cassandra/jvm-server.options'
      if File.exist?(jvm_options_file)
        current_content = File.read(jvm_options_file)
        
        # Check if agent is already configured
        unless current_content.include?('-javaagent:/usr/share/axonops')
          # Add the Java agent option
          agent_option = "-javaagent:#{jar_path}"
          
          File.open(jvm_options_file, 'a') do |f|
            f.puts "\n# AxonOps Java Agent"
            f.puts agent_option
          end
          
          Chef::Log.info("Added AxonOps Java agent to Cassandra JVM options: #{agent_option}")
          
          # Mark that Cassandra needs restart
          node.run_state['cassandra_needs_restart'] = true
        else
          Chef::Log.info("AxonOps Java agent already configured in Cassandra JVM options")
        end
      else
        Chef::Log.warn("Cassandra JVM options file not found: #{jvm_options_file}")
      end
    end
  end
  action :run
  only_if { node.run_state['cassandra_agent_jar_path'] }
end

# Restart Cassandra if needed
service 'cassandra' do
  action :restart
  only_if { node.run_state['cassandra_needs_restart'] }
end

# Log summary
ruby_block 'log_agent_installation_summary' do
  block do
    Chef::Log.info("=== AxonOps Cassandra Agent Installation Summary ===")
    Chef::Log.info("Detected Java Version: #{node.run_state['detected_java_version'] || 'unknown'}")
    Chef::Log.info("Java Path: #{node.run_state['detected_java_path'] || 'unknown'}")
    Chef::Log.info("Installed Agent: #{node.run_state['installed_cassandra_agent'] || 'none'}")
    Chef::Log.info("Agent JAR Path: #{node.run_state['cassandra_agent_jar_path'] || 'none'}")
  end
end