# Cassandra 5.0.4 configuration attributes
# Based on cassandra_latest.yaml for optimal performance and features

# Recipe options
default['axonops']['cassandra']['skip_java_install'] = false
default['axonops']['cassandra']['start_on_boot'] = true
default['axonops']['cassandra']['base_url'] = 'https://archive.apache.org/dist/cassandra'
default['axonops']['cassandra']['user'] = 'cassandra'
default['axonops']['cassandra']['group'] = 'cassandra'
default['axonops']['cassandra']['version'] = '5.0.4'
default['axonops']['cassandra']['data_root'] = '/var/lib/cassandra'
default['axonops']['cassandra']['local_jmx'] = 'yes'
default['axonops']['cassandra']['directories'] = {
  'logs' => '/var/log/cassandra',
  'gc_logs' => '/var/log/cassandra'
}

# Cluster Configuration
default['axonops']['cassandra']['cluster_name'] = 'Test Cluster'
default['axonops']['cassandra']['num_tokens'] = 16
default['axonops']['cassandra']['allocate_tokens_for_local_replication_factor'] = 3
default['axonops']['cassandra']['initial_token'] = nil

# Hinted Handoff
default['axonops']['cassandra']['hinted_handoff_enabled'] = true
default['axonops']['cassandra']['hinted_handoff_disabled_datacenters'] = []
default['axonops']['cassandra']['max_hint_window'] = '3h'
default['axonops']['cassandra']['hinted_handoff_throttle'] = '1024KiB'
default['axonops']['cassandra']['max_hints_delivery_threads'] = 2
default['axonops']['cassandra']['hints_flush_period'] = '10000ms'
default['axonops']['cassandra']['max_hints_file_size'] = '128MiB'
default['axonops']['cassandra']['auto_hints_cleanup_enabled'] = false

# Directory Configuration
default['axonops']['cassandra']['install_dir'] = '/opt'
default['axonops']['cassandra']['data_dir'] = '/var/lib/cassandra'
default['axonops']['cassandra']['data_file_directories'] = ['/var/lib/cassandra/data']
default['axonops']['cassandra']['commitlog_directory'] = '/var/lib/cassandra/commitlog'
default['axonops']['cassandra']['hints_directory'] = '/var/lib/cassandra/hints'
default['axonops']['cassandra']['saved_caches_directory'] = '/var/lib/cassandra/saved_caches'

# CDC (Change Data Capture)
default['axonops']['cassandra']['cdc_enabled'] = false
default['axonops']['cassandra']['cdc_raw_directory'] = '/var/lib/cassandra/cdc_raw'
default['axonops']['cassandra']['cdc_total_space'] = '4096MiB'
default['axonops']['cassandra']['cdc_free_space_check_interval'] = '250ms'

# Commitlog Configuration
default['axonops']['cassandra']['commitlog_sync'] = 'periodic'
default['axonops']['cassandra']['commitlog_sync_period'] = '10000ms'
default['axonops']['cassandra']['commitlog_segment_size'] = '32MiB'
default['axonops']['cassandra']['commitlog_compression'] = {
  'class_name' => 'LZ4Compressor'
}
default['axonops']['cassandra']['commitlog_total_space'] = nil
default['axonops']['cassandra']['memtable_flush_writers'] = nil  # Will be calculated based on disks

# Network Configuration
default['axonops']['cassandra']['listen_address'] = 'localhost'
default['axonops']['cassandra']['listen_interface'] = nil
default['axonops']['cassandra']['listen_interface_prefer_ipv6'] = false
default['axonops']['cassandra']['broadcast_address'] = nil
default['axonops']['cassandra']['listen_on_broadcast_address'] = false
default['axonops']['cassandra']['rpc_address'] = 'localhost'
default['axonops']['cassandra']['rpc_interface'] = nil
default['axonops']['cassandra']['rpc_interface_prefer_ipv6'] = false
default['axonops']['cassandra']['broadcast_rpc_address'] = nil

# Port Configuration
default['axonops']['cassandra']['storage_port'] = 7000
default['axonops']['cassandra']['ssl_storage_port'] = 7001
default['axonops']['cassandra']['native_transport_port'] = 9042
default['axonops']['cassandra']['native_transport_port_ssl'] = nil

# Native Transport
default['axonops']['cassandra']['start_native_transport'] = true
default['axonops']['cassandra']['native_transport_allow_older_protocols'] = true
default['axonops']['cassandra']['native_transport_max_threads'] = 128
default['axonops']['cassandra']['native_transport_max_frame_size'] = '16MiB'
default['axonops']['cassandra']['native_transport_frame_block_size'] = '32KiB'
default['axonops']['cassandra']['native_transport_max_concurrent_connections'] = -1
default['axonops']['cassandra']['native_transport_max_concurrent_connections_per_ip'] = -1
default['axonops']['cassandra']['native_transport_flush_in_batches_legacy'] = false
default['axonops']['cassandra']['native_transport_max_concurrent_requests_in_bytes_per_ip'] = nil
default['axonops']['cassandra']['native_transport_max_concurrent_requests_in_bytes'] = nil
default['axonops']['cassandra']['native_transport_receive_queue_capacity_in_bytes'] = '1MiB'

# Seeds Configuration
default['axonops']['cassandra']['seed_provider'] = [
  {
    'class_name' => 'org.apache.cassandra.locator.SimpleSeedProvider',
    'parameters' => [
      {
        'seeds' => '127.0.0.1:7000'
      }
    ]
  }
]

# Disk Optimization
default['axonops']['cassandra']['disk_optimization_strategy'] = 'ssd'
default['axonops']['cassandra']['disk_access_mode'] = 'mmap'

# Performance Tuning
default['axonops']['cassandra']['concurrent_reads'] = 32
default['axonops']['cassandra']['concurrent_writes'] = 32
default['axonops']['cassandra']['concurrent_counter_writes'] = 32
default['axonops']['cassandra']['concurrent_materialized_view_writes'] = 32
default['axonops']['cassandra']['file_cache_size'] = nil
default['axonops']['cassandra']['memtable_heap_space'] = nil
default['axonops']['cassandra']['memtable_offheap_space'] = nil
default['axonops']['cassandra']['memtable_cleanup_threshold'] = nil
default['axonops']['cassandra']['memtable_allocation_type'] = 'heap_buffers'
default['axonops']['cassandra']['commitlog_periodic_queue_size'] = nil

# Index Configuration
default['axonops']['cassandra']['column_index_size'] = '64KiB'
default['axonops']['cassandra']['column_index_cache_size'] = '2KiB'
default['axonops']['cassandra']['concurrent_materialized_view_builders'] = 1
default['axonops']['cassandra']['concurrent_secondary_index_builders'] = 1

# Compaction Configuration
default['axonops']['cassandra']['concurrent_compactors'] = nil
default['axonops']['cassandra']['concurrent_validations'] = 0
default['axonops']['cassandra']['compaction_throughput'] = '64MiB/s'
default['axonops']['cassandra']['sstable_preemptive_open_interval'] = '50MiB'

# Snitch Configuration
default['axonops']['cassandra']['endpoint_snitch'] = 'SimpleSnitch'
default['axonops']['cassandra']['dynamic_snitch_update_interval'] = '100ms'
default['axonops']['cassandra']['dynamic_snitch_reset_interval'] = '600000ms'
default['axonops']['cassandra']['dynamic_snitch_badness_threshold'] = 0.1
default['axonops']['cassandra']['dc'] = nil  # For GossipingPropertyFileSnitch
default['axonops']['cassandra']['rack'] = nil  # For GossipingPropertyFileSnitch
default['axonops']['cassandra']['prefer_local'] = nil  # For GossipingPropertyFileSnitch

# Security Configuration
default['axonops']['cassandra']['authenticator'] = 'PasswordAuthenticator'
default['axonops']['cassandra']['authorizer'] = 'CassandraAuthorizer'
default['axonops']['cassandra']['role_manager'] = 'CassandraRoleManager'
default['axonops']['cassandra']['network_authorizer'] = 'AllowAllNetworkAuthorizer'
default['axonops']['cassandra']['cidr_authorizer'] = 'AllowAllCIDRAuthorizer'
default['axonops']['cassandra']['permissions_validity'] = '2000ms'
default['axonops']['cassandra']['permissions_cache_max_entries'] = 1000
default['axonops']['cassandra']['permissions_update_interval'] = nil
default['axonops']['cassandra']['roles_validity'] = '2000ms'
default['axonops']['cassandra']['roles_cache_max_entries'] = 1000
default['axonops']['cassandra']['roles_update_interval'] = nil
default['axonops']['cassandra']['credentials_validity'] = '2000ms'
default['axonops']['cassandra']['credentials_cache_max_entries'] = 1000
default['axonops']['cassandra']['credentials_update_interval'] = nil
default['axonops']['cassandra']['auth_cache_warming_enabled'] = true

default['axonops']['cassandra']['ssl']['enabled'] = true
# Whether to create a self-signed keystore
default['axonops']['cassandra']['ssl']['self_signed'] = true
default['axonops']['cassandra']['ssl']['skip_verify'] = true
default['axonops']['cassandra']['ssl']['ca_file'] = '/opt/cassandra/ca.pem'
default['axonops']['cassandra']['ssl']['cert_file'] = '/opt/cassandra/cert.pem'
default['axonops']['cassandra']['ssl']['key_file'] = '/opt/cassandra/key.pem'

## path to keytool if required
default['axonops']['cassandra']['ssl']['keytool'] = nil

# Encryption Configuration
default['axonops']['cassandra']['server_encryption_options'] = {
  'internode_encryption' => 'none',
  'legacy_ssl_storage_port_enabled' => false,
  'keystore' => '/opt/cassandra/conf/keystore.jks',
  'keystore_password' => 'cassandra',
  'truststore' => '/opt/cassandra/conf/truststore.jks',
  'truststore_password' => 'cassandra',
  'protocol' => 'TLS',
  'accepted_protocols' => ['TLSv1.2', 'TLSv1.3'],
  'algorithm' => 'SunX509',
  'store_type' => 'JKS',
  'cipher_suites' => ['TLS_RSA_WITH_AES_128_CBC_SHA', 'TLS_RSA_WITH_AES_256_CBC_SHA'],
  'require_client_auth' => false,
  'require_endpoint_verification' => false
}

default['axonops']['cassandra']['client_encryption_options'] = {
  'enabled' => true,
  'keystore' => '/opt/cassandra/conf/keystore.jks',
  'keystore_password' => 'cassandra',
  'require_client_auth' => false,
  'truststore' => '/opt/cassandra/conf/truststore.jks',
  'truststore_password' => 'cassandra',
  'protocol' => 'TLS',
  'accepted_protocols' => ['TLSv1.2', 'TLSv1.3'],
  'algorithm' => 'SunX509',
  'store_type' => 'JKS',
  'cipher_suites' => ['TLS_RSA_WITH_AES_128_CBC_SHA', 'TLS_RSA_WITH_AES_256_CBC_SHA']
}

# Timeouts
default['axonops']['cassandra']['read_request_timeout'] = '5000ms'
default['axonops']['cassandra']['range_request_timeout'] = '10000ms'
default['axonops']['cassandra']['write_request_timeout'] = '2000ms'
default['axonops']['cassandra']['counter_write_request_timeout'] = '5000ms'
default['axonops']['cassandra']['cas_contention_timeout'] = '1000ms'
default['axonops']['cassandra']['truncate_request_timeout'] = '60000ms'
default['axonops']['cassandra']['request_timeout'] = '10000ms'
default['axonops']['cassandra']['startup_checks_timeout'] = '90s'

# Internode Configuration
default['axonops']['cassandra']['internode_send_buff_size'] = nil
default['axonops']['cassandra']['internode_recv_buff_size'] = nil
default['axonops']['cassandra']['internode_compression'] = 'dc'
default['axonops']['cassandra']['internode_tcp_nodelay'] = true
default['axonops']['cassandra']['internode_tcp_user_timeout'] = '30000ms'
default['axonops']['cassandra']['internode_application_send_buffer_in_bytes'] = '4MiB'
default['axonops']['cassandra']['internode_application_send_queue_reserve_endpoint_capacity'] = '128MiB'
default['axonops']['cassandra']['internode_application_send_queue_reserve_global_capacity'] = '512MiB'
default['axonops']['cassandra']['internode_application_receive_queue_reserve_endpoint_capacity'] = '128MiB'
default['axonops']['cassandra']['internode_application_receive_queue_reserve_global_capacity'] = '512MiB'

# Streaming Configuration  
default['axonops']['cassandra']['stream_entire_sstables'] = true
default['axonops']['cassandra']['stream_throughput_outbound'] = '24MiB/s'
default['axonops']['cassandra']['stream_throughput_inbound'] = nil
default['axonops']['cassandra']['streaming_keep_alive_period'] = '30s'
default['axonops']['cassandra']['streaming_slow_events_log_timeout'] = '10s'

# Batch Configuration
default['axonops']['cassandra']['batchlog_replay_throttle'] = '1024KiB'
default['axonops']['cassandra']['batch_size_warn_threshold'] = '5KiB'
default['axonops']['cassandra']['batch_size_fail_threshold'] = '50KiB'
default['axonops']['cassandra']['unlogged_batch_across_partitions_warn_threshold'] = 10
default['axonops']['cassandra']['batchlog_endpoint_strategy'] = 'dynamic_remote'

# Query Configuration
default['axonops']['cassandra']['tombstone_warn_threshold'] = 1000
default['axonops']['cassandra']['tombstone_failure_threshold'] = 100000
default['axonops']['cassandra']['replica_filtering_protection'] = {
  'cached_rows_warn_threshold' => 2000,
  'cached_rows_fail_threshold' => 32000
}

# Index Summary Configuration
default['axonops']['cassandra']['index_summary_capacity'] = nil
default['axonops']['cassandra']['index_summary_resize_interval'] = '60m'

# GC Grace
default['axonops']['cassandra']['gc_grace_seconds'] = 864000  # 10 days

# Phi Convict Threshold
default['axonops']['cassandra']['phi_convict_threshold'] = nil

# Buffer Pool Configuration
default['axonops']['cassandra']['buffer_pool_use_heap_if_exhausted'] = true
default['axonops']['cassandra']['disk_failure_policy'] = 'stop'
default['axonops']['cassandra']['commit_failure_policy'] = 'stop'

# Key Cache Configuration
default['axonops']['cassandra']['key_cache_size'] = nil
default['axonops']['cassandra']['key_cache_save_period'] = '14400s'
default['axonops']['cassandra']['key_cache_keys_to_save'] = nil

# Row Cache Configuration
default['axonops']['cassandra']['row_cache_size'] = '0MiB'
default['axonops']['cassandra']['row_cache_save_period'] = '0s'
default['axonops']['cassandra']['row_cache_keys_to_save'] = nil

# Counter Cache Configuration
default['axonops']['cassandra']['counter_cache_size'] = nil
default['axonops']['cassandra']['counter_cache_save_period'] = '7200s'
default['axonops']['cassandra']['counter_cache_keys_to_save'] = nil

# Networking Cache Configuration
default['axonops']['cassandra']['networking_cache_size'] = '16MiB'

# Prepared Statement Cache Configuration
default['axonops']['cassandra']['prepared_statements_cache_size'] = nil
default['axonops']['cassandra']['cache_load_timeout'] = '30s'

# Continuous Paging Configuration
default['axonops']['cassandra']['continuous_paging'] = {
  'max_concurrent_sessions' => 60,
  'max_session_pages' => 4,
  'max_page_size_mb' => 8,
  'max_local_query_time_ms' => 5000,
  'client_timeout_sec' => 600,
  'cancel_timeout_sec' => 5
}

# Slow Query Configuration
default['axonops']['cassandra']['slow_query_log_timeout'] = '500ms'

# Materialized Views Configuration
default['axonops']['cassandra']['materialized_views_enabled'] = true

# SAI (Storage Attached Index) Configuration
default['axonops']['cassandra']['sai_sstable_indexes_per_query_warn_threshold'] = 32
default['axonops']['cassandra']['sai_sstable_indexes_per_query_fail_threshold'] = 64
default['axonops']['cassandra']['sai_string_term_size_kb'] = 1
default['axonops']['cassandra']['sai_max_frozen_term_size_kb'] = 5
default['axonops']['cassandra']['sai_max_vector_term_size_kb'] = 8
default['axonops']['cassandra']['sai_max_terms_per_query'] = 32

# Transient Replication Configuration
default['axonops']['cassandra']['transient_replication_enabled'] = false

# Drop Compact Storage Configuration
default['axonops']['cassandra']['drop_compact_storage_enabled'] = false

# Secondary Index Configuration
default['axonops']['cassandra']['default_secondary_index'] = 'sai'
default['axonops']['cassandra']['default_secondary_index_enabled'] = true

# UUID SSTable Identifiers
default['axonops']['cassandra']['uuid_sstable_identifiers_enabled'] = true

# Scripted UDFs Configuration
default['axonops']['cassandra']['scripted_user_defined_functions_enabled'] = false

# Full Query Logging Configuration
default['axonops']['cassandra']['full_query_logging_options'] = {
  'log_dir' => nil,
  'roll_cycle' => 'HOURLY',
  'block' => true,
  'max_queue_weight' => 256 * 1024 * 1024,
  'max_log_size' => 17_179_869_184,
  'archive_command' => nil,
  'max_archive_retries' => 10
}

# Audit Logging Configuration
default['axonops']['cassandra']['audit_logging_options'] = {
  'enabled' => false,
  'logger' => {
    'class_name' => 'BinAuditLogger'
  },
  'audit_logs_dir' => '/var/lib/cassandra/audit',
  'archive_command' => nil,
  'max_archive_retries' => 10,
  'block' => true,
  'max_log_size' => 17_179_869_184,
  'max_queue_weight' => 256 * 1024 * 1024,
  'roll_cycle' => 'HOURLY',
  'included_keyspaces' => nil,
  'excluded_keyspaces' => 'system,system_schema,system_virtual_schema',
  'included_categories' => nil,
  'excluded_categories' => nil,
  'included_users' => nil,
  'excluded_users' => nil
}

# Diagnostic Events Configuration
default['axonops']['cassandra']['diagnostic_events_enabled'] = false
default['axonops']['cassandra']['native_transport_flush_in_batches_legacy'] = false
default['axonops']['cassandra']['repair_session_space'] = nil

# Ideal Consistency Level
default['axonops']['cassandra']['ideal_consistency_level'] = nil

# JVM Options Configuration
default['axonops']['cassandra']['heap_size'] = "2G"

# JVM GC Configuration (for Java 17)
default['axonops']['cassandra']['gc_type'] = 'G1GC'
default['axonops']['cassandra']['gc_g1_heap_region_size'] = '16m'
default['axonops']['cassandra']['gc_g1_max_pause_millis'] = 300
default['axonops']['cassandra']['gc_g1_initiating_heap_occupancy_percent'] = 70
default['axonops']['cassandra']['gc_parallel_threads'] = nil  # Will use number of cores
default['axonops']['cassandra']['gc_conc_threads'] = nil  # Will use number of cores

# Logging Configuration
default['axonops']['cassandra']['log_level'] = 'INFO'
default['axonops']['cassandra']['log_dir'] = '/var/log/cassandra'
default['axonops']['cassandra']['gc_log_dir'] = '/var/log/cassandra'
default['axonops']['cassandra']['gc_log_enabled'] = true
default['axonops']['cassandra']['gc_log_file_size'] = '10M'
default['axonops']['cassandra']['gc_log_files'] = 10

# System Resource Limits
default['axonops']['cassandra']['limits']['memlock'] = 'unlimited'
default['axonops']['cassandra']['limits']['nofile'] = 100000
default['axonops']['cassandra']['limits']['nproc'] = 32768
default['axonops']['cassandra']['limits']['as'] = 'unlimited'

# Sysctl Settings
default['axonops']['cassandra']['sysctl']['vm.max_map_count'] = 1048575
default['axonops']['cassandra']['sysctl']['net.ipv4.tcp_keepalive_time'] = 60
default['axonops']['cassandra']['sysctl']['net.ipv4.tcp_keepalive_probes'] = 3
default['axonops']['cassandra']['sysctl']['net.ipv4.tcp_keepalive_intvl'] = 10

# Logback Configuration
default['axonops']['cassandra']['logback_scan'] = 'true'
default['axonops']['cassandra']['logback_scan_period'] = '60 seconds'
default['axonops']['cassandra']['system_log_level'] = 'INFO'
default['axonops']['cassandra']['console_log_level'] = 'INFO'
default['axonops']['cassandra']['root_log_level'] = 'INFO'
default['axonops']['cassandra']['cassandra_log_level'] = 'DEBUG'
default['axonops']['cassandra']['log_pattern'] = '%-5level [%thread] %date{ISO8601} %F:%L - %msg%n'
default['axonops']['cassandra']['log_max_file_size'] = '50MB'
default['axonops']['cassandra']['log_max_history'] = 7
default['axonops']['cassandra']['log_total_size_cap'] = '5GB'
default['axonops']['cassandra']['async_log_queue_size'] = 1024
default['axonops']['cassandra']['async_log_discarding_threshold'] = 0
default['axonops']['cassandra']['debug_log_enabled'] = true
default['axonops']['cassandra']['cql_log_enabled'] = false
default['axonops']['cassandra']['cql_log_level'] = 'WARN'
default['axonops']['cassandra']['audit_logging_enabled'] = false
default['axonops']['cassandra']['audit_log_max_file_size'] = '50MB'
default['axonops']['cassandra']['audit_log_max_history'] = 30
default['axonops']['cassandra']['audit_log_total_size_cap'] = '5GB'

# Rack/DC configuration for GossipingPropertyFileSnitch
default['axonops']['cassandra']['datacenter'] = 'dc1'
default['axonops']['cassandra']['rack'] = 'rack1'
default['axonops']['cassandra']['dc_suffix'] = nil
default['axonops']['cassandra']['prefer_local'] = nil
default['axonops']['cassandra']['ec2_naming_scheme'] = nil
default['axonops']['cassandra']['ec2_metadata_type'] = nil
default['axonops']['cassandra']['ec2_metadata_token_ttl_seconds'] = nil
default['axonops']['cassandra']['azure_api_version'] = nil
default['axonops']['cassandra']['metadata_url'] = nil
default['axonops']['cassandra']['metadata_request_timeout'] = nil

# Additional attributes for templates
default['axonops']['cassandra']['allocate_tokens_for_keyspace'] = nil
default['axonops']['cassandra']['transfer_hints_on_decommission'] = true
default['axonops']['cassandra']['hints_compression'] = nil
default['axonops']['cassandra']['dump_heap_on_uncaught_exception'] = nil
default['axonops']['cassandra']['hint_window_persistent_enabled'] = nil
default['axonops']['cassandra']['seed_provider_class'] = 'org.apache.cassandra.locator.SimpleSeedProvider'
default['axonops']['cassandra']['seeds'] = ['127.0.0.1']

# JVM Configuration
default['axonops']['cassandra']['jvm'] = {
  'heap_size' => nil,  # Will auto-calculate if not set
  'new_size' => nil    # Only for CMS GC
}
default['axonops']['cassandra']['new_heap_size'] = nil
default['axonops']['cassandra']['jmx_port'] = 7199
default['axonops']['cassandra']['jmx_authentication'] = false
default['axonops']['cassandra']['jmx_password'] = 'cassandra'
default['axonops']['cassandra']['jmx_access_file'] = '/etc/jmxremote.access'
default['axonops']['cassandra']['jmx_password_file'] = '/etc/jmxremote.password'

# Additional missing attributes from configure_cassandra.rb
default['axonops']['cassandra']['compaction_throughput_mb_per_sec'] = 64
default['axonops']['cassandra']['stream_throughput_outbound_megabits_per_sec'] = 200
default['axonops']['cassandra']['inter_dc_stream_throughput_outbound_megabits_per_sec'] = 200
default['axonops']['cassandra']['wait_for_start'] = true

# Compaction
default['axonops']['cassandra']['compaction_strategy'] = 'SizeTieredCompactionStrategy'

default['axonops']['cassandra']['compaction_strategy_options']['SizeTieredCompactionStrategy'] = {
  'min_threshold' => 4,
  'max_threshold' => 32,
}

default['axonops']['cassandra']['compaction_strategy_options']['UnifiedCompactionStrategy'] = {
  'max_sstables_to_compact' => 64,
  'scaling_parameters' => "T4",
  'target_sstable_size' => '1GiB',
  'sstable_growth' => 0.3333333333333333,
  'min_sstable_size' => '100MiB',
}

# Additional values
default['axonops']['cassandra']['trickle_fsync'] = true
default['axonops']['cassandra']['trickle_fsync_interval'] = '10MiB'
default['axonops']['cassandra']['snapshot_links_per_second'] = 16384
default['axonops']['cassandra']['entire_sstable_stream_throughput_outbound'] = '24MiB/s'
default['axonops']['cassandra']['entire_sstable_inter_dc_stream_throughput_outbound'] = '24MiB/s'
default['axonops']['cassandra']['inter_dc_stream_throughput_outbound'] = '24MiB/s'
default['axonops']['cassandra']['internode_tcp_connect_timeout'] = '2000ms'
default['axonops']['cassandra']['internode_streaming_tcp_user_timeout'] = '5m'
default['axonops']['cassandra']['gc_log_threshold'] = '500ms'
default['axonops']['cassandra']['gc_warn_threshold'] = '2000ms'
default['axonops']['cassandra']['audit_logging_max_queue_weight'] = 268435456

default['axonops']['cassandra']['default_keyspace_rf'] = 1
default['axonops']['cassandra']['minimum_replication_factor_fail_threshold'] = 1
default['axonops']['cassandra']['maximum_replication_factor_warn_threshold'] = 1

default['axonops']['cassandra']['chunk_length_kb'] = 64
default['axonops']['cassandra']['key_alias'] = 'testing:1'
default['axonops']['cassandra']['auto_snapshot_ttl'] = '30d'
default['axonops']['cassandra']['streaming_state_expires'] = '3d'
default['axonops']['cassandra']['trace_type_query_ttl'] = '1d'

# G1GC settings for Java 17
default['axonops']['cassandra']['gc_g1_max_tenuring_threshold'] = 2
default['axonops']['cassandra']['gc_g1_heap_region_size'] = '16m'
default['axonops']['cassandra']['gc_g1_new_size_percent'] = 50
default['axonops']['cassandra']['gc_g1_rset_updating_pause_time_percent'] = 5
default['axonops']['cassandra']['gc_g1_max_pause_millis'] = 300
default['axonops']['cassandra']['gc_g1_initiating_heap_occupancy_percent'] = 70
default['axonops']['cassandra']['gc_parallel_threads'] = nil
default['axonops']['cassandra']['gc_conc_threads'] = nil
default['axonops']['cassandra']['gc_log_enabled'] = false
default['axonops']['cassandra']['gc_log_files'] = 10
default['axonops']['cassandra']['gc_log_file_size'] = '10M'

# System tuning parameters for Cassandra
default['cassandra']['user'] = 'cassandra'
default['cassandra']['system']['max_map_count'] = 1048575  # Recommended for Cassandra
default['cassandra']['system']['file_descriptor_limit'] = 100000  # High FD limit for SSTable files
default['cassandra']['system']['memlock_limit'] = 'unlimited'  # For JNA memory locking
default['cassandra']['system']['as_limit'] = 'unlimited'  # Address space limit
default['cassandra']['system']['nproc_limit'] = 32768  # Process limit for Cassandra user

# Additional sysctl settings for Cassandra
default['cassandra']['system']['net_core_rmem_max'] = 134217728  # 128MB
default['cassandra']['system']['net_core_wmem_max'] = 134217728  # 128MB
default['cassandra']['system']['net_core_rmem_default'] = 16777216  # 16MB
default['cassandra']['system']['net_core_wmem_default'] = 16777216  # 16MB
default['cassandra']['system']['net_core_optmem_max'] = 40960
default['cassandra']['system']['net_ipv4_tcp_rmem'] = '4096 87380 134217728'
default['cassandra']['system']['net_ipv4_tcp_wmem'] = '4096 65536 134217728'
default['cassandra']['system']['net_ipv4_tcp_keepalive_time'] = 60
default['cassandra']['system']['net_ipv4_tcp_keepalive_probes'] = 3
default['cassandra']['system']['net_ipv4_tcp_keepalive_intvl'] = 10
default['cassandra']['system']['net_ipv4_tcp_fin_timeout'] = 15
default['cassandra']['system']['net_ipv4_tcp_tw_reuse'] = 1
default['cassandra']['system']['net_ipv4_tcp_moderate_rcvbuf'] = 1
default['cassandra']['system']['net_ipv4_tcp_congestion'] = 'cubic'
default['cassandra']['system']['net_ipv4_tcp_syncookies'] = 1
default['cassandra']['system']['net_ipv4_tcp_max_syn_backlog'] = 8192
default['cassandra']['system']['net_core_somaxconn'] = 65535
default['cassandra']['system']['vm_swappiness'] = 1  # Minimize swapping
default['cassandra']['system']['vm_dirty_ratio'] = 10  # Reduced for database workloads
default['cassandra']['system']['vm_dirty_background_ratio'] = 5  # Reduced for database workloads
default['cassandra']['system']['vm_zone_reclaim_mode'] = 0  # Disable zone reclaim for NUMA systems
