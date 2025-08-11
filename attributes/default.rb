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
default['axonops']['server']['package'] = 'axon-server'

# Server Dependencies
default['axonops']['server']['elasticsearch']['install'] = true
default['axonops']['server']['elasticsearch']['url'] = 'http://127.0.0.1:9200'
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

# Offline Installation Support
default['axonops']['offline_install'] = false
default['axonops']['offline_packages_path'] = '/opt/axonops-packages'

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

# Offline installation settings
default['axonops']['offline_install'] = false
default['axonops']['offline_packages_path'] = '/opt/axonops/offline'

# Package names
default['axonops']['packages'] = {
  'elasticsearch_tarball' => nil,  # Auto-detected based on version
  'cassandra_tarball' => nil,      # Auto-detected based on version
  'java_tarball' => nil,           # Auto-detected based on version
  'agent' => nil,                  # Auto-detected
  'server' => nil,                 # Auto-detected
  'dashboard' => nil,              # Auto-detected
  'java_agent' => nil              # Auto-detected based on Java/Cassandra version
}

# Chef Workstation Configuration
default['axonops']['chef_workstation']['enabled'] = false
default['axonops']['chef_workstation']['version'] = 'latest'
default['axonops']['chef_workstation']['install_chef_workstation'] = true
default['axonops']['chef_workstation']['install_additional_gems'] = true
default['axonops']['chef_workstation']['update_cache'] = true
