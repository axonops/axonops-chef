#
# Cookbook:: axonops
# Recipe:: chef_workstation
#
# Installs prerequisites for running knife and chef commands on a node
# Supports: RHEL/CentOS/Rocky, Ubuntu/Debian, Amazon Linux
#

# Update package cache based on platform
case node['platform_family']
when 'rhel', 'fedora', 'amazon'
  execute 'update-package-cache' do
    command 'yum makecache' if node['platform_version'].to_i < 8
    command 'dnf makecache' if node['platform_version'].to_i >= 8
    action :run
    only_if { node['axonops']['chef_workstation']['update_cache'] }
  end
when 'debian'
  execute 'update-package-cache' do
    command 'apt-get update'
    action :run
    only_if { node['axonops']['chef_workstation']['update_cache'] }
  end
end

# Install development tools based on platform
case node['platform_family']
when 'rhel', 'fedora'
  if node['platform_version'].to_i >= 8
    # RHEL 8+ / Rocky / AlmaLinux
    package 'dnf-plugins-core'
    
    # Enable PowerTools/CRB repository
    execute 'enable-powertools' do
      command if node['platform'] == 'rocky'
                'dnf config-manager --set-enabled powertools || dnf config-manager --set-enabled crb'
              else
                'dnf config-manager --set-enabled powertools'
              end
      not_if 'dnf repolist | grep -i powertools || dnf repolist | grep -i crb'
    end
    
    # Install development tools group
    execute 'install-development-tools' do
      command 'dnf groupinstall -y "Development Tools"'
      not_if 'dnf group list installed | grep -i "Development Tools"'
    end
  else
    # RHEL 7 / CentOS 7
    execute 'install-development-tools' do
      command 'yum groupinstall -y "Development Tools"'
      not_if 'yum group list installed | grep -i "Development Tools"'
    end
  end
  
  # Install EPEL repository
  package 'epel-release' do
    action :install
    not_if 'rpm -qa | grep -q epel-release'
  end
  
when 'amazon'
  # Amazon Linux
  execute 'install-development-tools' do
    command 'yum groupinstall -y "Development Tools"'
    not_if 'yum group list installed | grep -i "Development Tools"'
  end
  
  # Enable EPEL for Amazon Linux 2
  execute 'enable-epel' do
    command 'amazon-linux-extras install epel -y'
    only_if { node['platform_version'].to_i == 2 }
    not_if 'rpm -qa | grep -q epel-release'
  end
  
when 'debian'
  # Ubuntu/Debian
  package %w(build-essential software-properties-common curl) do
    action :install
  end
end

# Install Ruby and development packages
ruby_packages = case node['platform_family']
                when 'rhel', 'fedora', 'amazon'
                  %w(ruby ruby-devel rubygems gcc gcc-c++ make)
                when 'debian'
                  %w(ruby-full ruby-dev gcc g++ make)
                end

package ruby_packages do
  action :install
end

# Install additional dependencies
common_packages = %w(git wget curl tar gzip)

package common_packages do
  action :install
end

# Install Chef Workstation if enabled
if node['axonops']['chef_workstation']['install_chef_workstation']
  chef_workstation_version = node['axonops']['chef_workstation']['version']
  
  case node['platform_family']
  when 'rhel', 'fedora', 'amazon'
    if chef_workstation_version == 'latest'
      remote_file '/tmp/chef-workstation.rpm' do
        source "https://packages.chef.io/files/stable/chef-workstation/latest/el/#{node['platform_version'].to_i}/chef-workstation-latest.el#{node['platform_version'].to_i}.x86_64.rpm"
        action :create
        not_if 'which chef'
      end
    else
      remote_file '/tmp/chef-workstation.rpm' do
        source "https://packages.chef.io/files/stable/chef-workstation/#{chef_workstation_version}/el/#{node['platform_version'].to_i}/chef-workstation-#{chef_workstation_version}-1.el#{node['platform_version'].to_i}.x86_64.rpm"
        action :create
        not_if 'which chef'
      end
    end
    
    package 'chef-workstation' do
      source '/tmp/chef-workstation.rpm'
      action :install
      not_if 'which chef'
    end
    
  when 'debian'
    apt_arch = node['kernel']['machine'] == 'x86_64' ? 'amd64' : 'i386'
    
    if chef_workstation_version == 'latest'
      remote_file '/tmp/chef-workstation.deb' do
        source "https://packages.chef.io/files/stable/chef-workstation/latest/ubuntu/#{node['platform_version']}/chef-workstation_latest-1_#{apt_arch}.deb"
        action :create
        not_if 'which chef'
      end
    else
      remote_file '/tmp/chef-workstation.deb' do
        source "https://packages.chef.io/files/stable/chef-workstation/#{chef_workstation_version}/ubuntu/#{node['platform_version']}/chef-workstation_#{chef_workstation_version}-1_#{apt_arch}.deb"
        action :create
        not_if 'which chef'
      end
    end
    
    dpkg_package 'chef-workstation' do
      source '/tmp/chef-workstation.deb'
      action :install
      not_if 'which chef'
    end
  end
  
  # Add chef shell-init to profile
  file '/etc/profile.d/chef-workstation.sh' do
    content <<-EOH
# Chef Workstation shell initialization
eval "$(chef shell-init bash)"
export PATH="/opt/chef-workstation/bin:$PATH"
    EOH
    mode '0644'
  end
end

# Install knife via gem if Chef Workstation not installed
execute 'install-knife-gem' do
  command 'gem install knife -N'
  not_if { node['axonops']['chef_workstation']['install_chef_workstation'] }
  not_if 'which knife'
end

# Install additional useful gems
%w(berkshelf test-kitchen kitchen-vagrant).each do |gem_name|
  gem_package gem_name do
    action :install
    only_if { node['axonops']['chef_workstation']['install_additional_gems'] }
  end
end

# Create chef configuration directory
directory '/root/.chef' do
  owner 'root'
  group 'root'
  mode '0700'
  action :create
end

# Create a basic knife.rb template if one doesn't exist
file '/root/.chef/knife.rb' do
  content <<-EOH
# Knife configuration file
# Update these values with your Chef Server details

chef_server_url   'https://your-chef-server/organizations/your-org'
node_name         'your-username'
client_key        '/root/.chef/your-username.pem'
ssl_verify_mode   :verify_peer
cookbook_path     ['#{Chef::Config[:cookbook_path].join("','")}']

# Optional settings
# knife[:editor] = 'vim'
# knife[:default_attribute] = 'ipaddress'
  EOH
  mode '0600'
  action :create_if_missing
end

log 'Chef Workstation prerequisites installed successfully' do
  level :info
end

log 'IMPORTANT: Update /root/.chef/knife.rb with your Chef Server configuration' do
  level :warn
  not_if { ::File.exist?('/root/.chef/admin.pem') }
end