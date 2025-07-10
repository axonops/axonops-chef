#
# Cookbook:: axonops
# Attributes:: cassandra
#
# Attributes for Apache Cassandra 5.0 installation (NOT for AxonOps internal use)
#

# Cassandra Installation
default['cassandra']['install'] = false # Set to true to install Cassandra
default['cassandra']['version'] = '5.0.4'
default['cassandra']['install_format'] = 'tarball' # 'tarball' or 'package'
default['cassandra']['install_dir'] = '/opt/cassandra'
default['cassandra']['user'] = 'cassandra'
default['cassandra']['group'] = 'cassandra'
default['cassandra']['skip_java_install'] = false

# Data Directories
default['cassandra']['data_root'] = '/data/cassandra'
default['cassandra']['directories']['data'] = ["#{node['cassandra']['data_root']}/data"]
default['cassandra']['directories']['hints'] = "#{node['cassandra']['data_root']}/hints"
default['cassandra']['directories']['saved_caches'] = "#{node['cassandra']['data_root']}/saved_caches"
default['cassandra']['directories']['commitlog'] = "#{node['cassandra']['data_root']}/commitlog"
default['cassandra']['directories']['logs'] = '/var/log/cassandra'

# Network Configuration
default['cassandra']['cluster_name'] = 'My Cluster'
default['cassandra']['seeds'] = []
default['cassandra']['listen_address'] = nil # Uses node IP if nil
default['cassandra']['rpc_address'] = nil # Uses node IP if nil
default['cassandra']['broadcast_address'] = nil
default['cassandra']['broadcast_rpc_address'] = nil
default['cassandra']['native_transport_port'] = 9042
default['cassandra']['storage_port'] = 7000
default['cassandra']['ssl_storage_port'] = 7001

# Security
default['cassandra']['authenticator'] = 'AllowAllAuthenticator'
default['cassandra']['authorizer'] = 'AllowAllAuthorizer'

# Cluster Configuration
default['cassandra']['endpoint_snitch'] = 'GossipingPropertyFileSnitch'
default['cassandra']['dc'] = 'dc1'
default['cassandra']['rack'] = 'rack1'
default['cassandra']['num_tokens'] = 16

# Performance
default['cassandra']['concurrent_reads'] = 32
default['cassandra']['concurrent_writes'] = 32
default['cassandra']['concurrent_counter_writes'] = 32
default['cassandra']['max_heap_size'] = nil # Auto-calculated if nil
default['cassandra']['heap_newsize'] = nil # Auto-calculated if nil

# Download URLs
default['cassandra']['tarball_url'] = nil # Auto-generated if nil
default['cassandra']['tarball_checksum'] = nil

# System Tuning
default['cassandra']['system_tuning']['enabled'] = true
