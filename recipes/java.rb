#
# Cookbook:: axonops
# Recipe:: java
#
# Installs Java - either Azul Zulu Java 17 or OpenJDK based on configuration
#
if node["java"]["skip_install"]
  Chef::Log.info("Skipping Java installation as per configuration")
  return
end

# Determine installation method
install_from_tarball = node['java']['install_from_package'] == false || node['java']['offline_install']
install_zulu = node['java']['zulu'] != false

if node['java']['offline_install'] && node['java']['package']
  offline_dir = node['axonops']['offline_packages_path'] || '/tmp/offline_packages'

  # Install from specified package path
  package_path = ::File.join(node['axonops']['offline_packages_path'], node['java']['package'])

  if !::File.exist?(package_path)
    raise Chef::Exceptions::FileNotFound, "Java package not found at specified path: #{package_path}"
  end

  case node['platform_family']
  when 'debian'
    dpkg_package package_path do
      action :install
    end
  when 'rhel', 'fedora'
    rpm_package package_path do
      action :install
    end
  end

  java_home = node['java']['java_home'] || node['java']['zulu_home'] || node['java']['openjdk_home']
elsif install_from_tarball
  # Install from tarball (offline mode)
  java_home = node['java']['java_home']

  # Find Java tarball dynamically if not specified
  if node['java']['tarball_path'] && ::File.exist?(node['java']['tarball_path'])
    tarball_path = node['java']['tarball_path']
  else
    # Look for Zulu Java tarball in offline packages directory
    offline_dir = node['axonops']['offline_packages_path'] || '/tmp/offline_packages'

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

elsif install_zulu && !node['java']['offline_install']
  # Install Azul Zulu from package repository (online mode)
  case node['platform_family']
  when 'debian'
    # Install prerequisites
    package %w(gnupg curl apt-transport-https) do
      action :install
    end

    # Download and convert the Azul GPG key
    execute 'add-azul-repo-key' do
      command 'curl -s https://repos.azul.com/azul-repo.key | gpg --dearmor -o /usr/share/keyrings/azul.gpg'
      not_if { ::File.exist?('/usr/share/keyrings/azul.gpg') }
      action :run
    end

    file '/etc/apt/sources.list.d/zulu.list' do
      content "deb [signed-by=/usr/share/keyrings/azul.gpg] https://repos.azul.com/zulu/deb stable main"
      mode '0644'
      notifies :run, 'execute[apt-update-azul]', :immediately
    end

    execute 'apt-update-azul' do
      command 'apt-get update'
      action :nothing
    end

    package node['java']['zulu_pkg'] do
      action :install
    end

    java_home = node['java']['zulu_home']

  when 'rhel', 'fedora'
    # Add Zulu repository
    rpm_package 'zulu-repo' do
      source node['java']['zulu_pkg_rpm']
      action :install
      not_if 'rpm -qa | grep -q zulu-repo'
    end

    # Install Zulu JDK 17
    package node['java']['zulu_pkg'] do
      action :install
    end

    java_home = node['java']['zulu_home']
  end

else
  # Install OpenJDK (when zulu is false or fallback)
  Chef::Log.info("Installing OpenJDK as Zulu is disabled")

  package node['java']['openjdk_pkg'] do
    action :install
  end

  # Set JAVA_HOME based on platform
  if ::File.exist?(node["java"]["java_home"])
    java_home = node["java"]["java_home"]
  elsif node['java']['zulu']
    java_home = node['java']['zulu_home']
  else
    java_home = node['java']['openjdk_home']
  end
end

# Set JAVA_HOME environment variable
file '/etc/profile.d/java.sh' do
  content <<-EOH
export JAVA_HOME=#{java_home}
export PATH=$JAVA_HOME/bin:$PATH
EOH
  mode '0644'
  only_if { java_home }
end

# Log Java installation info
log 'java-installation-complete' do
  message lazy {
    if defined?(java_home) && java_home
      "Java installation complete with JAVA_HOME=#{java_home}"
    else
      "Java installation complete"
    end
  }
  level :info
end
