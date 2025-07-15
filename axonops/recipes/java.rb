#
# Cookbook:: axonops
# Recipe:: java
#
# Installs Azul Zulu Java 17
#

# Check if offline installation with tarball
if node['java']['install_from_package'] == false
  # Install from tarball (offline mode)
  java_home = node['java']['java_home']
  
  # Find Java tarball dynamically if not specified
  if node['java']['tarball_path'] && ::File.exist?(node['java']['tarball_path'])
    tarball_path = node['java']['tarball_path']
  else
    # Look for Zulu Java tarball in offline packages directory
    offline_dir = node['axonops']['offline_packages_dir'] || '/tmp/offline_packages'
    
    # Determine architecture
    arch = node['kernel']['machine'] == 'aarch64' ? 'aarch64' : 'x64'
    
    # Find the latest Zulu Java 17 tarball for the architecture
    tarball_pattern = "#{offline_dir}/zulu*jdk*linux_#{arch}.tar.gz"
    tarballs = Dir.glob(tarball_pattern).sort
    
    if tarballs.empty?
      raise Chef::Exceptions::FileNotFound, "No Java tarball found matching pattern: #{tarball_pattern}"
    end
    
    tarball_path = tarballs.last
    Chef::Log.info("Found Java tarball: #{tarball_path}")
  end
  
  # Create Java directory
  directory ::File.dirname(java_home) do
    owner 'root'
    group 'root'
    mode '0755'
    recursive true
  end
  
  # Extract Java
  execute 'extract-java' do
    command "tar -xzf #{tarball_path} -C #{::File.dirname(java_home)}"
    creates java_home
    notifies :run, 'ruby_block[create-java-symlink]', :immediately
  end
  
  # Find the extracted directory name and create symlink
  ruby_block 'create-java-symlink' do
    block do
      # Find the extracted directory (e.g., zulu17.54.21-ca-jdk17.0.13-linux_x64)
      parent_dir = ::File.dirname(java_home)
      extracted_dirs = Dir.glob("#{parent_dir}/zulu*").select { |f| File.directory?(f) }
      
      if extracted_dirs.empty?
        raise "No Zulu directory found after extraction"
      end
      
      extracted_dir = extracted_dirs.sort.last # Get the latest if multiple
      
      # Create symlink if it doesn't exist or points to wrong location
      unless ::File.symlink?(java_home) && ::File.readlink(java_home) == extracted_dir
        ::File.unlink(java_home) if ::File.exist?(java_home)
        ::File.symlink(extracted_dir, java_home)
      end
    end
    notifies :run, 'execute[update-java-alternatives]', :immediately
    action :nothing
  end
  
  # Set up alternatives
  execute 'update-java-alternatives' do
    command <<-EOH
      update-alternatives --install /usr/bin/java java #{java_home}/bin/java 1000
      update-alternatives --install /usr/bin/javac javac #{java_home}/bin/javac 1000
      update-alternatives --install /usr/bin/jar jar #{java_home}/bin/jar 1000
      update-alternatives --set java #{java_home}/bin/java
      update-alternatives --set javac #{java_home}/bin/javac
      update-alternatives --set jar #{java_home}/bin/jar
    EOH
    action :nothing
  end
  
  # Set JAVA_HOME
  file '/etc/profile.d/java.sh' do
    content <<-EOH
export JAVA_HOME=#{java_home}
export PATH=$JAVA_HOME/bin:$PATH
EOH
    mode '0644'
  end
  
else
  # Install from package repository (online mode)
  case node['platform_family']
  when 'debian'
    # Add Azul repository
    execute 'add-azul-repo-key' do
      command 'curl -s https://repos.azul.com/azul-repo.key | apt-key add -'
      not_if 'apt-key list | grep -q Azul'
    end
    
    file '/etc/apt/sources.list.d/zulu.list' do
      content "deb https://repos.azul.com/zulu/deb stable main"
      mode '0644'
    end
    
    execute 'apt-update-azul' do
      command 'apt-get update'
      action :run
    end
    
    package 'zulu17-jdk' do
      action :install
    end
    
    java_home = '/usr/lib/jvm/zulu17'
  when 'rhel', 'fedora'
    # For RHEL/CentOS
    execute 'add-azul-repo' do
      command 'rpm --import https://repos.azul.com/azul-repo.key'
      not_if 'rpm -qa | grep -q zulu17'
    end
    
    remote_file '/etc/yum.repos.d/zulu.repo' do
      source 'https://repos.azul.com/zulu/rpm/zulu.repo'
      mode '0644'
    end
    
    package 'zulu17-jdk' do
      action :install
    end
    
    java_home = '/usr/lib/jvm/zulu17'
  end
  
  # Set JAVA_HOME
  file '/etc/profile.d/java.sh' do
    content <<-EOH
export JAVA_HOME=#{java_home}
export PATH=$JAVA_HOME/bin:$PATH
EOH
    mode '0644'
  end
end