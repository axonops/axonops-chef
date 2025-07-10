#
# Cookbook:: axonops
# Recipe:: java_simple
#
# Simple Java installation for testing
#

# Install Azul Zulu Java 17
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