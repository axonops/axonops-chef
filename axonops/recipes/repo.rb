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
  package %w(apt-transport-https ca-certificates curl gnupg lsb-release)

  # Add AxonOps GPG key
  execute 'add-axonops-apt-key' do
    command 'curl -fsSL https://packages.axonops.com/apt/axonops.gpg.key | apt-key add -'
    not_if 'apt-key list | grep -i axonops'
  end

  # Configure APT repository
  apt_repository 'axonops' do
    uri node['axonops']['repository']['url'] + '/apt'
    components ['main']
    trusted true
    action :add
  end

  apt_repository 'axonops-beta' do
    uri node['axonops']['repository']['url'] + '/apt'
    components ['beta']
    trusted true
    action node['axonops']['repository']['beta'] ? :add : :remove
  end

when 'rhel', 'fedora'
  # Add AxonOps YUM repository
  yum_repository 'axonops' do
    description 'AxonOps Repository'
    baseurl "#{node['axonops']['repository']['url']}/yum/el$releasever/$basearch/"
    gpgkey "#{node['axonops']['repository']['url']}/yum/RPM-GPG-KEY-axonops"
    enabled true
    gpgcheck true
    action :create
  end

  yum_repository 'axonops-beta' do
    description 'AxonOps Beta Repository'
    baseurl "#{node['axonops']['repository']['url']}/yum-beta/el$releasever/$basearch/"
    gpgkey "#{node['axonops']['repository']['url']}/yum/RPM-GPG-KEY-axonops"
    enabled node['axonops']['repository']['beta']
    gpgcheck true
    action :create
  end

else
  Chef::Log.warn("Platform family #{node['platform_family']} is not supported for AxonOps repository configuration")
end
