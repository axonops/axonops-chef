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
default['axonops']['agent']['enabled'] = true
default['axonops']['agent']['version'] = 'latest'
default['axonops']['agent']['user'] = 'axonops'
default['axonops']['agent']['group'] = 'axonops'

# SaaS Mode Connection
default['axonops']['agent']['hosts'] = 'agents.axonops.cloud'
default['axonops']['agent']['port'] = 443

# Agent Configuration
default['axonops']['agent']['disable_command_exec'] = false
default['axonops']['agent']['cassandra_home'] = nil # Auto-detected if nil
default['axonops']['agent']['cassandra_config'] = nil # Auto-detected if nil

# Java Agent
default['axonops']['java_agent']['version'] = '1.0.10'
default['axonops']['java_agent']['package'] = 'axon-cassandra5.0-agent-jdk17'
default['axonops']['java_agent']['jar_path'] = '/usr/share/axonops/axon-cassandra-agent.jar'

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
default['axonops']['offline_packages_dir'] = '/opt/axonops/offline'

# Package names
default['axonops']['packages'] = {
  'elasticsearch_tarball' => nil,  # Auto-detected based on version
  'cassandra_tarball' => nil,      # Auto-detected based on version
  'java_tarball' => nil,           # Auto-detected based on version
  'agent' => nil,                  # Auto-detected
  'server' => nil,                 # Auto-detected
  'dashboard' => nil               # Auto-detected
}

# Java agent
default['axonops']['agent']['java_agent'] = {
  'enabled' => true
}