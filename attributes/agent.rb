#
# Cookbook:: axonops
# Attributes:: agent
#
# AxonOps Agent Configuration
#

# Agent Service Configuration
default['axonops']['agent']['enabled'] = true
default['axonops']['agent']['version'] = 'latest'
default['axonops']['agent']['user'] = 'axonops'
default['axonops']['agent']['group'] = 'axonops'
# Install package from offline directory if offline_install is true
default['axonops']['agent']['package'] = 'axon-agent-2.0.6-1.x86_64.rpm'

# Connection Settings
# For SaaS mode (default)
default['axonops']['agent']['hosts'] = 'agents.axonops.cloud'
default['axonops']['agent']['port'] = 443

# Authentication (required for SaaS mode)
default['axonops']['agent']['org_key'] = nil
default['axonops']['agent']['org_name'] = nil

# disabled, TLS, mTLS. For SaaS mode, use 'tls'
# default['axonops']['agent']['tls_mode'] = 'disabled'

# Agent Security Settings
default['axonops']['agent']['disable_command_exec'] = false # Set to true to disable remote command execution

# Cassandra Integration
# These will be auto-detected if not specified
default['axonops']['agent']['cassandra_home'] = nil    # e.g., '/opt/cassandra'
default['axonops']['agent']['cassandra_config'] = nil  # e.g., '/etc/cassandra'

# Java Agent Configuration
default['axonops']['agent']['java_agent'] = {
  'enabled' => true  # Enable Java agent for JVM metrics
}

# Java Agent Package Details
default['axonops']['java_agent']['version'] = 'latest'
default['axonops']['java_agent']['package'] = 'axon-cassandra5.0-agent-jdk17' # Will be auto-selected based on Cassandra/Java version
default['axonops']['java_agent']['jar_path'] = '/usr/share/axonops/axon-cassandra5.0-agent.jar'
default['axonops']['java_agent']['kafka'] = 'axon-kafka3-agent'

# Note: Package file names can be overridden via:
# - default['axonops']['agent']['package'] = 'axon-agent_2.0.4_amd64.deb'
# - default['axonops']['packages']['java_agent'] = 'axon-cassandra5.0-agent-jdk17-1.0.10.jar'
# These are defined in attributes/default.rb
