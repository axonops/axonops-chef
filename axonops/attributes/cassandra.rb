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
default['cassandra']['force_fresh_install'] = false # DANGEROUS: Override safety check for existing installations

# Data Directories
default['cassandra']['data_root'] = '/var/lib/cassandra'
default['cassandra']['directories']['data'] = '/var/lib/cassandra/data'
default['cassandra']['directories']['hints'] = '/var/lib/cassandra/hints'
default['cassandra']['directories']['saved_caches'] = '/var/lib/cassandra/saved_caches'
default['cassandra']['directories']['commitlog'] = '/var/lib/cassandra/commitlog'
default['cassandra']['directories']['logs'] = '/var/log/cassandra'
default['cassandra']['directories']['gc_logs'] = '/var/log/cassandra/gc'

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

# JVM Settings
default['cassandra']['jvm']['heap_size'] = nil # Auto-calculated if nil
default['cassandra']['jvm']['new_size'] = nil # Auto-calculated if nil

# JMX Settings
default['cassandra']['jmx_port'] = 7199
default['cassandra']['jmx_authentication'] = false

# Additional Performance Settings
default['cassandra']['concurrent_materialized_view_writes'] = 32
default['cassandra']['disk_optimization_strategy'] = 'ssd'
default['cassandra']['memtable_allocation_type'] = 'heap_buffers'
default['cassandra']['memtable_cleanup_threshold'] = 0.11
default['cassandra']['memtable_flush_writers'] = 2
default['cassandra']['compaction_throughput_mb_per_sec'] = 64
default['cassandra']['stream_throughput_outbound_megabits_per_sec'] = 200
default['cassandra']['inter_dc_stream_throughput_outbound_megabits_per_sec'] = 200

# Logging
default['cassandra']['log_level'] = 'INFO'

# Audit logging
default['cassandra']['audit_log']['enabled'] = false

# DC and Rack for property file snitch
default['cassandra']['datacenter'] = 'dc1'
default['cassandra']['rack'] = 'rack1'

# Service management
default['cassandra']['wait_for_start'] = true

# Java home
default['java']['java_home'] = '/usr/lib/jvm/zulu17'
