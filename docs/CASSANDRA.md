# Apache Cassandra 5.0.4 Installation Guide

This guide covers the installation and configuration of Apache Cassandra 5.0.4 using the AxonOps Chef cookbook.

## Table of Contents
- [Overview](#overview)
- [Requirements](#requirements)
- [Basic Installation](#basic-installation)
- [Configuration Options](#configuration-options)
  - [Recipe Options](#recipe-options)
  - [Cluster Configuration](#cluster-configuration)
  - [Network Configuration](#network-configuration)
  - [Performance Tuning](#performance-tuning)
  - [Security Configuration](#security-configuration)
  - [Storage Configuration](#storage-configuration)
  - [JVM Configuration](#jvm-configuration)
  - [Logging Configuration](#logging-configuration)
  - [System Tuning](#system-tuning)
- [Advanced Configurations](#advanced-configurations)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)

## Overview

The AxonOps Chef cookbook provides a flexible and modular approach to installing Apache Cassandra 5.0.4. This recipe can be used independently to deploy a new Cassandra cluster or as part of a larger AxonOps deployment.

Key features:
- Apache Cassandra 5.0.4 installation
- Flexible Java management (can skip Java installation)
- Comprehensive configuration options
- Production-ready default settings
- Support for various deployment scenarios

## Requirements

- **Operating System**: Linux (tested on Ubuntu, CentOS, RHEL)
- **Memory**: Minimum 4GB RAM, recommended 8GB+
- **Disk**: SSD recommended for production
- **Java**: Java 17 (automatically installed unless skipped)
- **Chef**: Chef Infra Client 15.0+

## Basic Installation

To install Cassandra with default settings:

```ruby
include_recipe 'axonops::cassandra'
```

This will:
- Install Java 17 (unless `skip_java_install` is set to true)
- Download and install Apache Cassandra 5.0.4
- Configure Cassandra with production-ready defaults
- Start the Cassandra service

## Configuration Options

All configuration options are defined under the `node['axonops']['cassandra']` namespace.

### Recipe Options

| Attribute | Default | Description |
|-----------|---------|-------------|
| `skip_java_install` | `false` | Skip Java installation if you have your own Java |
| `start_on_boot` | `true` | Enable Cassandra service to start on boot |
| `base_url` | `https://archive.apache.org/dist/cassandra` | Base URL for downloading Cassandra |
| `user` | `cassandra` | System user for running Cassandra |
| `group` | `cassandra` | System group for Cassandra |
| `version` | `5.0.4` | Cassandra version to install |
| `wait_for_start` | `true` | Wait for Cassandra to start after configuration |

### Cluster Configuration

| Attribute | Default | Description |
|-----------|---------|-------------|
| `cluster_name` | `Test Cluster` | Name of your Cassandra cluster |
| `num_tokens` | `16` | Number of tokens per node (vnodes) |
| `allocate_tokens_for_local_replication_factor` | `3` | RF for token allocation |
| `initial_token` | `nil` | Initial token (leave nil for vnodes) |
| `seeds` | `['127.0.0.1']` | List of seed nodes |
| `endpoint_snitch` | `SimpleSnitch` | Snitch implementation |
| `datacenter` | `dc1` | Datacenter name (for GossipingPropertyFileSnitch) |
| `rack` | `rack1` | Rack name (for GossipingPropertyFileSnitch) |

### Network Configuration

| Attribute | Default | Description |
|-----------|---------|-------------|
| `listen_address` | `localhost` | Address to bind for internal communication |
| `rpc_address` | `localhost` | Address to bind for client connections |
| `broadcast_address` | `nil` | Address to broadcast to other nodes |
| `broadcast_rpc_address` | `nil` | Address to broadcast for client connections |
| `storage_port` | `7000` | Port for internal node communication |
| `ssl_storage_port` | `7001` | SSL port for internal communication |
| `native_transport_port` | `9042` | CQL native transport port |
| `jmx_port` | `7199` | JMX monitoring port |

### Performance Tuning

| Attribute | Default | Description |
|-----------|---------|-------------|
| `concurrent_reads` | `32` | Concurrent read operations |
| `concurrent_writes` | `32` | Concurrent write operations |
| `concurrent_counter_writes` | `32` | Concurrent counter write operations |
| `compaction_throughput` | `64MiB/s` | Compaction throughput limit |
| `stream_throughput_outbound` | `24MiB/s` | Outbound streaming throughput |
| `memtable_allocation_type` | `heap_buffers` | Memtable allocation type |
| `file_cache_size` | `nil` | File cache size (auto-calculated if nil) |
| `buffer_pool_use_heap_if_exhausted` | `true` | Use heap if buffer pool exhausted |

### Security Configuration

| Attribute | Default | Description |
|-----------|---------|-------------|
| `authenticator` | `PasswordAuthenticator` | Authentication mechanism |
| `authorizer` | `CassandraAuthorizer` | Authorization mechanism |
| `role_manager` | `CassandraRoleManager` | Role management implementation |
| `network_authorizer` | `AllowAllNetworkAuthorizer` | Network authorization |
| `permissions_validity` | `2000ms` | Permissions cache validity |
| `roles_validity` | `2000ms` | Roles cache validity |
| `credentials_validity` | `2000ms` | Credentials cache validity |

#### Encryption Options

Server encryption (node-to-node):
```ruby
node.override['axonops']['cassandra']['server_encryption_options'] = {
  'internode_encryption' => 'all',  # none, dc, rack, all
  'keystore' => '/etc/cassandra/cassandra.keystore',
  'keystore_password' => 'your_keystore_password',
  'truststore' => '/etc/cassandra/cassandra.truststore',
  'truststore_password' => 'your_truststore_password',
  'protocol' => 'TLS',
  'accepted_protocols' => ['TLSv1.2', 'TLSv1.3'],
  'cipher_suites' => ['TLS_RSA_WITH_AES_256_GCM_SHA384'],
  'require_client_auth' => true,
  'require_endpoint_verification' => true
}
```

Client encryption:
```ruby
node.override['axonops']['cassandra']['client_encryption_options'] = {
  'enabled' => true,
  'keystore' => '/etc/cassandra/cassandra.keystore',
  'keystore_password' => 'your_keystore_password',
  'require_client_auth' => false,
  'protocol' => 'TLS',
  'accepted_protocols' => ['TLSv1.2', 'TLSv1.3']
}
```

### Storage Configuration

| Attribute | Default | Description |
|-----------|---------|-------------|
| `data_file_directories` | `['/var/lib/cassandra/data']` | Data file directories |
| `commitlog_directory` | `/var/lib/cassandra/commitlog` | Commit log directory |
| `hints_directory` | `/var/lib/cassandra/hints` | Hints directory |
| `saved_caches_directory` | `/var/lib/cassandra/saved_caches` | Saved caches directory |
| `disk_optimization_strategy` | `ssd` | Disk optimization (ssd or spinning) |
| `disk_access_mode` | `mmap` | Disk access mode |
| `commitlog_sync` | `periodic` | Commit log sync mode |
| `commitlog_sync_period` | `10000ms` | Commit log sync period |
| `commitlog_segment_size` | `32MiB` | Commit log segment size |

#### CDC (Change Data Capture)
```ruby
node.override['axonops']['cassandra']['cdc_enabled'] = true
node.override['axonops']['cassandra']['cdc_raw_directory'] = '/var/lib/cassandra/cdc_raw'
node.override['axonops']['cassandra']['cdc_total_space'] = '4096MiB'
```

### JVM Configuration

| Attribute | Default | Description |
|-----------|---------|-------------|
| `heap_size` | `2G` | JVM heap size |
| `gc_type` | `G1GC` | Garbage collector type |
| `gc_g1_heap_region_size` | `16m` | G1GC heap region size |
| `gc_g1_max_pause_millis` | `300` | G1GC max pause target |
| `gc_g1_initiating_heap_occupancy_percent` | `70` | G1GC initiating occupancy |
| `local_jmx` | `yes` | Enable local JMX connections |
| `jmx_authentication` | `false` | Enable JMX authentication |

### Logging Configuration

| Attribute | Default | Description |
|-----------|---------|-------------|
| `log_level` | `INFO` | Default log level |
| `log_dir` | `/var/log/cassandra` | Log directory |
| `gc_log_enabled` | `true` | Enable GC logging |
| `gc_log_file_size` | `10M` | GC log file size |
| `gc_log_files` | `10` | Number of GC log files to keep |
| `audit_logging_enabled` | `false` | Enable audit logging |
| `debug_log_enabled` | `true` | Enable debug.log |
| `system_log_level` | `INFO` | System log level |
| `cassandra_log_level` | `DEBUG` | Cassandra log level |

### System Tuning

Resource limits:
```ruby
node.override['axonops']['cassandra']['limits'] = {
  'memlock' => 'unlimited',
  'nofile' => 100000,
  'nproc' => 32768,
  'as' => 'unlimited'
}
```

Sysctl settings:
```ruby
node.override['axonops']['cassandra']['sysctl'] = {
  'vm.max_map_count' => 1048575,
  'net.ipv4.tcp_keepalive_time' => 60,
  'net.ipv4.tcp_keepalive_probes' => 3,
  'net.ipv4.tcp_keepalive_intvl' => 10
}
```

## Advanced Configurations

### Hinted Handoff

```ruby
node.override['axonops']['cassandra']['hinted_handoff_enabled'] = true
node.override['axonops']['cassandra']['max_hint_window'] = '3h'
node.override['axonops']['cassandra']['hinted_handoff_throttle'] = '1024KiB'
node.override['axonops']['cassandra']['max_hints_delivery_threads'] = 2
```

### Compaction Settings

```ruby
node.override['axonops']['cassandra']['concurrent_compactors'] = 4
node.override['axonops']['cassandra']['compaction_throughput'] = '128MiB/s'
node.override['axonops']['cassandra']['sstable_preemptive_open_interval'] = '50MiB'
```

### Query Timeouts

```ruby
node.override['axonops']['cassandra']['read_request_timeout'] = '5000ms'
node.override['axonops']['cassandra']['write_request_timeout'] = '2000ms'
node.override['axonops']['cassandra']['range_request_timeout'] = '10000ms'
node.override['axonops']['cassandra']['request_timeout'] = '10000ms'
```

### Tombstone Settings

```ruby
node.override['axonops']['cassandra']['tombstone_warn_threshold'] = 1000
node.override['axonops']['cassandra']['tombstone_failure_threshold'] = 100000
```

### Cache Configuration

```ruby
# Key cache
node.override['axonops']['cassandra']['key_cache_size'] = '100MiB'
node.override['axonops']['cassandra']['key_cache_save_period'] = '14400s'

# Row cache (usually disabled)
node.override['axonops']['cassandra']['row_cache_size'] = '0MiB'

# Counter cache
node.override['axonops']['cassandra']['counter_cache_size'] = '50MiB'
node.override['axonops']['cassandra']['counter_cache_save_period'] = '7200s'
```

### Storage Attached Index (SAI) Configuration

```ruby
node.override['axonops']['cassandra']['default_secondary_index'] = 'sai'
node.override['axonops']['cassandra']['sai_sstable_indexes_per_query_warn_threshold'] = 32
node.override['axonops']['cassandra']['sai_sstable_indexes_per_query_fail_threshold'] = 64
```

### Full Query Logging

```ruby
node.override['axonops']['cassandra']['full_query_logging_options'] = {
  'log_dir' => '/var/lib/cassandra/fql',
  'roll_cycle' => 'HOURLY',
  'block' => true,
  'max_queue_weight' => 256 * 1024 * 1024,
  'max_log_size' => 17_179_869_184
}
```

### Audit Logging

```ruby
node.override['axonops']['cassandra']['audit_logging_options'] = {
  'enabled' => true,
  'logger' => {
    'class_name' => 'BinAuditLogger'
  },
  'audit_logs_dir' => '/var/lib/cassandra/audit',
  'roll_cycle' => 'HOURLY',
  'included_keyspaces' => 'production_ks',
  'excluded_keyspaces' => 'system,system_schema,system_virtual_schema'
}
```

## Examples

### Example 1: Single Node Development Setup

```ruby
node.override['axonops']['cassandra']['cluster_name'] = 'Development'
node.override['axonops']['cassandra']['heap_size'] = '1G'
node.override['axonops']['cassandra']['authenticator'] = 'AllowAllAuthenticator'
node.override['axonops']['cassandra']['authorizer'] = 'AllowAllAuthorizer'

include_recipe 'axonops::cassandra'
```

### Example 2: Production Cluster Node

```ruby
# Cluster configuration
node.override['axonops']['cassandra']['cluster_name'] = 'Production'
node.override['axonops']['cassandra']['seeds'] = ['10.0.1.10', '10.0.1.11', '10.0.1.12']
node.override['axonops']['cassandra']['listen_address'] = node['ipaddress']
node.override['axonops']['cassandra']['rpc_address'] = '0.0.0.0'
node.override['axonops']['cassandra']['broadcast_rpc_address'] = node['ipaddress']

# Use GossipingPropertyFileSnitch for multi-DC
node.override['axonops']['cassandra']['endpoint_snitch'] = 'GossipingPropertyFileSnitch'
node.override['axonops']['cassandra']['datacenter'] = 'us-east'
node.override['axonops']['cassandra']['rack'] = 'rack1'

# Performance tuning
node.override['axonops']['cassandra']['heap_size'] = '16G'
node.override['axonops']['cassandra']['concurrent_reads'] = 64
node.override['axonops']['cassandra']['concurrent_writes'] = 64
node.override['axonops']['cassandra']['compaction_throughput'] = '128MiB/s'

# Multiple data directories
node.override['axonops']['cassandra']['data_file_directories'] = [
  '/data1/cassandra/data',
  '/data2/cassandra/data',
  '/data3/cassandra/data'
]

# Security
node.override['axonops']['cassandra']['authenticator'] = 'PasswordAuthenticator'
node.override['axonops']['cassandra']['authorizer'] = 'CassandraAuthorizer'

include_recipe 'axonops::cassandra'
```

### Example 3: Using Existing Java Installation

```ruby
# Skip Java installation
node.override['axonops']['cassandra']['skip_java_install'] = true

# Configure Cassandra
node.override['axonops']['cassandra']['cluster_name'] = 'MyCluster'
node.override['axonops']['cassandra']['heap_size'] = '8G'

include_recipe 'axonops::cassandra'
```

### Example 4: Multi-Datacenter Setup

```ruby
# DC1 Configuration
node.override['axonops']['cassandra']['cluster_name'] = 'Global'
node.override['axonops']['cassandra']['endpoint_snitch'] = 'GossipingPropertyFileSnitch'
node.override['axonops']['cassandra']['datacenter'] = 'us-east-1'
node.override['axonops']['cassandra']['rack'] = 'us-east-1a'
node.override['axonops']['cassandra']['prefer_local'] = 'true'

# Seeds from multiple DCs
node.override['axonops']['cassandra']['seeds'] = [
  '10.0.1.10',  # us-east-1
  '10.0.1.11',  # us-east-1
  '10.1.1.10',  # us-west-1
  '10.1.1.11'   # us-west-1
]

# Enable internode encryption for cross-DC traffic
node.override['axonops']['cassandra']['server_encryption_options']['internode_encryption'] = 'dc'

include_recipe 'axonops::cassandra'
```

### Example 5: High-Performance SSD Configuration

```ruby
# Optimize for SSDs
node.override['axonops']['cassandra']['disk_optimization_strategy'] = 'ssd'
node.override['axonops']['cassandra']['concurrent_compactors'] = 8
node.override['axonops']['cassandra']['compaction_throughput'] = '256MiB/s'

# Larger memtables for better write performance
node.override['axonops']['cassandra']['memtable_heap_space'] = '2048MiB'
node.override['axonops']['cassandra']['memtable_offheap_space'] = '2048MiB'

# Tune for low latency
node.override['axonops']['cassandra']['read_request_timeout'] = '2000ms'
node.override['axonops']['cassandra']['write_request_timeout'] = '1000ms'

include_recipe 'axonops::cassandra'
```

## Troubleshooting

### Common Issues

1. **Cassandra fails to start**
   - Check logs in `/var/log/cassandra/system.log`
   - Verify Java 17 is installed: `java -version`
   - Check disk space and permissions
   - Verify network configuration (especially `listen_address` and `rpc_address`)

2. **Cannot connect to Cassandra**
   - Verify `rpc_address` is not set to `localhost` if connecting remotely
   - Check `native_transport_port` (default 9042) is not blocked
   - Ensure `start_native_transport` is true

3. **Performance issues**
   - Review heap size configuration
   - Check GC logs for excessive garbage collection
   - Monitor disk I/O and consider increasing `concurrent_reads`/`concurrent_writes`
   - Review compaction settings

4. **Authentication failures**
   - Default credentials are cassandra/cassandra
   - Change immediately after installation
   - Ensure `authenticator` is set to `PasswordAuthenticator`

### Log Locations

- System log: `/var/log/cassandra/system.log`
- Debug log: `/var/log/cassandra/debug.log`
- GC log: `/var/log/cassandra/gc.log.*`
- Audit log: `/var/lib/cassandra/audit/` (if enabled)

### Useful Commands

```bash
# Check service status
systemctl status cassandra

# View logs
tail -f /var/log/cassandra/system.log

# Connect with cqlsh
cqlsh -u cassandra -p cassandra

# Check cluster status
nodetool status

# Check node info
nodetool info

# View configuration
nodetool describeclusters
```

## Additional Resources

- [Apache Cassandra Documentation](https://cassandra.apache.org/doc/5.0/)
- [AxonOps Documentation](https://docs.axonops.com/)
- [DataStax Cassandra Best Practices](https://docs.datastax.com/en/landing_page/doc/landing_page/planning/planningBestPractices.html)
