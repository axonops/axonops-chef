#
# Cookbook:: axonops
# Recipe:: java
#
# Installs Java - either Azul Zulu Java 17 or OpenJDK based on configuration
#
if node['java']['skip_install']
  Chef::Log.info('Skipping Java installation as per configuration')
  return
end

# Let the top-level axonops.offline_install flag drive Java's own offline
# switch too, so a single flag airgaps the whole stack (agent/server/cassandra
# -> java). Standalone callers can still set node['java']['offline_install']
# directly. Reading node.override['java']['offline_install'] here (e.g. via
# ||=) would auto-vivify an empty, truthy Mash on first access and get stuck
# — only write to it, never read-then-write through the override chain.
if node['axonops']['offline_install'] && !node['java']['offline_install']
  node.override['java']['offline_install'] = true
end

# Resolve the package names and JAVA_HOME for the requested Java major version
# (8, 11 or 17). The Cassandra recipe sets node['java']['version'] from the
# Cassandra version; standalone callers may override it directly. Explicitly
# set zulu_pkg / zulu_home / openjdk_pkg attributes still win.
java_major = node['java']['version'].to_i
if node['java']['zulu_packages'].key?(java_major)
  node.default['java']['zulu_pkg']  = node['java']['zulu_packages'][java_major]
  node.default['java']['zulu_home'] = node['java']['zulu_homes'][java_major]
end
openjdk_for_family = node['java']['openjdk_packages'][node['platform_family']]
if openjdk_for_family && openjdk_for_family.key?(java_major)
  node.default['java']['openjdk_pkg'] = openjdk_for_family[java_major]
  node.default['java']['java_pkg']    = openjdk_for_family[java_major]
end
Chef::Log.info("Java recipe: installing Java #{java_major} (zulu=#{node['java']['zulu']})")

# Determine installation method
install_from_tarball = node['java']['install_from_package'] == false || node['java']['offline_install']
install_zulu = node['java']['zulu'] != false

if node['java']['offline_install'] && node['java']['package']
  # Install from specified package path
  package_path = ::File.join(node['axonops']['offline_packages_path'], node['axonops']['offline_packages']['java'])

  unless ::File.exist?(package_path)
    raise Chef::Exceptions::FileNotFound, "Java package not found at specified path: #{package_path}"
  end

  case node['platform_family']
  when 'debian'
    dpkg_package package_path do
      action :install
    end
  when 'rhel', 'fedora', 'amazon'
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
        raise 'No Zulu directory found after extraction'
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
      content 'deb [signed-by=/usr/share/keyrings/azul.gpg] https://repos.azul.com/zulu/deb stable main'
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

  when 'rhel', 'fedora', 'amazon'
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

  # Zulu's RPM/deb postinstall registers itself via alternatives with its own
  # priority, so on a box that ends up with multiple Zulu majors installed
  # (e.g. after switching a node between Cassandra versions), `java` on PATH
  # can silently point at the wrong major regardless of which package this
  # converge just asked for — alternatives --auto picks by priority, not by
  # "most recently installed". Force it explicitly so java_major above is
  # actually what runs.
  alternatives_cmd = platform_family?('debian') ? 'update-alternatives' : 'alternatives'
  # alternatives --set matches on the exact path a package registered, which
  # is NOT reliably "<zulu_home>/bin/java" or its realpath — that varies by
  # distro/package (Amazon Linux's Zulu 8 build registers .../jre/bin/java,
  # a symlink target different from its own bin/java; Ubuntu's Zulu 17 deb
  # registers .../zulu17/bin/java directly, whose realpath differs again).
  # Ask alternatives what it actually has instead of guessing a path shape.
  registered_java_bins = begin
    Mixlib::ShellOut.new("#{alternatives_cmd} --list java").tap(&:run_command).stdout.lines.map(&:strip)
  rescue Errno::ENOENT
    []
  end
  # Match by realpath, not the literal registered string — whichever symlink
  # route a package's postinst used to register itself, it and our own
  # "<zulu_home>/bin/java" both resolve to the same physical binary when
  # they're the same JDK.
  desired_java_bin = "#{java_home}/bin/java"
  desired_java_realpath = ::File.exist?(desired_java_bin) ? ::File.realpath(desired_java_bin) : nil
  target_java_bin = registered_java_bins.find do |path|
    desired_java_realpath && ::File.exist?(path) && ::File.realpath(path) == desired_java_realpath
  end

  execute 'select-java-alternative' do
    command "#{alternatives_cmd} --set java #{target_java_bin}"
    not_if { target_java_bin.nil? || (::File.exist?('/usr/bin/java') && ::File.realpath('/usr/bin/java') == desired_java_realpath) }
  end

else
  # Install OpenJDK (when zulu is false or fallback)
  Chef::Log.info('Installing OpenJDK as Zulu is disabled')

  package node['java']['openjdk_pkg'] do
    action :install
  end

  # Set JAVA_HOME based on platform
  java_home = if ::File.exist?(node['java']['java_home'])
                node['java']['java_home']
              elsif node['java']['zulu']
                node['java']['zulu_home']
              else
                node['java']['openjdk_home']
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
      'Java installation complete'
    end
  }
  level :info
end
