#
# Cookbook:: axonops
# Attributes:: default
#

# AxonOps Deployment Mode
default['axonops']['deployment_mode'] = 'saas' # 'saas' or 'self-hosted'

# AxonOps API Configuration
default['axonops']['api']['key'] = nil # Required for SaaS mode
default['axonops']['api']['organization'] = nil # Required for SaaS mode
default['axonops']['api']['base_url'] = nil # Override API endpoint if needed

# AxonOps Agent Configuration
# See attributes/agent.rb for all agent-related settings

# AxonOps Server Configuration (Self-Hosted)
default['axonops']['server']['enabled'] = false
default['axonops']['server']['version'] = 'latest'
default['axonops']['server']['listen_address'] = '0.0.0.0'
default['axonops']['server']['listen_port'] = 8080

# Server Dependencies
default['axonops']['server']['cassandra']['install'] = true
default['axonops']['server']['cassandra']['hosts'] = ['127.0.0.1']

# AxonOps Dashboard
default['axonops']['dashboard']['enabled'] = false
default['axonops']['dashboard']['version'] = 'latest'
default['axonops']['dashboard']['listen_address'] = '127.0.0.1'
default['axonops']['dashboard']['listen_port'] = 3000

# Repository Configuration
default['axonops']['repository']['enabled'] = true
default['axonops']['repository']['url'] = 'https://packages.axonops.com'
default['axonops']['repository']['beta'] = false

# Alert Configuration (via API)
default['axonops']['alerts']['endpoints'] = {}
default['axonops']['alerts']['rules'] = {}
default['axonops']['alerts']['routes'] = {}

# Service Checks Configuration
default['axonops']['service_checks'] = {}

# Backup Configuration
default['axonops']['backups'] = {}

# Log Parsing Rules
default['axonops']['log_rules'] = {}

# Offline installation settings.
# offline_packages_path accepts a local directory (default) or an http(s)://
# base URL — package files are then downloaded via remote_file into Chef's
# file cache. axonops::java's package-chain/tarball auto-discovery still
# requires a local directory since it globs for dependent files by pattern.
default['axonops']['offline_install'] = false
default['axonops']['offline_packages_path'] = '/opt/axonops/offline'

# Package names. 'cassandra' is the tarball used by axonops::cassandra's
# tar install_format (also axonops::server's own metrics-storage Cassandra,
# which is tar-only regardless of install_format); 'cassandra_pkg' is the
# separate RPM/deb used by axonops::cassandra's pkg install_format
# (recipes/install_cassandra_pkg.rb) — the two are never the same file.
default['axonops']['offline_packages'] = {
  'opensearch' => 'opensearch-3.6.0-linux-x64.rpm',
  'cassandra' => 'apache-cassandra-5.0.5-bin.tar.gz',
  'cassandra_pkg' => 'cassandra-5.0.5-1.noarch.rpm',
  'java' => 'zulu17-ca-jdk-headless-17.0.16-1.x86_64.rpm',
  'agent' => 'axon-agent-2.0.6-1.x86_64.rpm',
  'server' => 'axon-server-2.0.5-1.x86_64.rpm',
  'dashboard' => 'axon-dash-2.0.10-1.x86_64.rpm',
  'java_agent' => 'axon-cassandra5.0-agent-jdk17-1.0.10-1.noarch.rpm'
}

# Chef Workstation Configuration
default['axonops']['chef_workstation']['enabled'] = false
default['axonops']['chef_workstation']['version'] = 'latest'
default['axonops']['chef_workstation']['install_chef_workstation'] = true
default['axonops']['chef_workstation']['install_additional_gems'] = true
default['axonops']['chef_workstation']['update_cache'] = true
