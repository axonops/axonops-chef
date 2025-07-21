#
# Cookbook:: cassandra-ops
# Recipe:: axonops_repo
#
# Configures AxonOps package repository
#

# Skip repository configuration for offline installations
return if node['axonops']['offline_install']

return unless node['axonops']['repository']['enabled']

case node['platform_family']
when 'debian'
  # Install prerequisites
  package %w(apt-transport-https ca-certificates curl gnupg apt-utils)

  # Add AxonOps GPG key
  execute 'add-axonops-apt-key' do
    command 'curl -L https://packages.axonops.com/apt/repo-signing-key.gpg | gpg --dearmor -o /usr/share/keyrings/axonops.gpg'
    not_if { ::File.exists?('/usr/share/keyrings/axonops.gpg') }
  end

  # Configure APT repository
  file '/etc/apt/sources.list.d/axonops.list' do
    content 'deb [arch=arm64,amd64 trusted=yes signed-by=/usr/share/keyrings/axonops.gpg] https://packages.axonops.com/apt axonops-apt main'
    mode '0644'
    action :create
  end

  execute 'update-apt-cache' do
    command 'apt-get update'
    action :run
  end

when 'rhel', 'fedora'
  # Add AxonOps YUM repository
  yum_repository 'axonops' do
    description 'AxonOps Repository'
    baseurl "https://packages.axonops.com/yum/"
    enabled true
    gpgcheck false
    action :create
  end
else
  Chef::Log.warn("Platform family #{node['platform_family']} is not supported for AxonOps repository configuration")
end
