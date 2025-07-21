# Elasticsearch Installation Guide for AxonOps

This guide covers the installation and configuration of Elasticsearch as part of the AxonOps server deployment. Elasticsearch is used by AxonOps for storing and searching logs, events, and other operational data.

## Table of Contents
- [Overview](#overview)
- [Requirements](#requirements)
- [Basic Installation](#basic-installation)
- [Configuration Options](#configuration-options)
  - [General Settings](#general-settings)
  - [Network Configuration](#network-configuration)
  - [Storage Configuration](#storage-configuration)
  - [Performance Tuning](#performance-tuning)
  - [System Settings](#system-settings)
- [Usage Scenarios](#usage-scenarios)
- [Integration with AxonOps](#integration-with-axonops)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)

## Overview

The AxonOps Chef cookbook includes an Elasticsearch recipe specifically configured for AxonOps server deployments. This recipe:

- Installs Elasticsearch 7.17.26 (optimized for AxonOps)
- Configures it as a single-node cluster (suitable for AxonOps deployments)
- Sets up proper system tuning for Elasticsearch
- Creates a dedicated systemd service (`axonops-search`)
- Integrates seamlessly with AxonOps server

**Important**: This Elasticsearch installation is specifically for AxonOps internal use. If you have an existing Elasticsearch cluster, you can configure AxonOps to use it instead.

## Requirements

- **Operating System**: Linux (tested on Ubuntu, CentOS, RHEL)
- **Memory**: Minimum 1GB RAM allocated to Elasticsearch heap
- **Disk**: SSD recommended for better performance
- **Java**: Java 17 (automatically installed by the cookbook)
- **System Settings**: vm.max_map_count >= 262144

## Basic Installation

### Option 1: Install with AxonOps Server (Recommended)

```ruby
include_recipe 'axonops::server'
```

This automatically includes Elasticsearch installation.

### Option 2: Install Elasticsearch Only

```ruby
include_recipe 'axonops::elasticsearch'
```

### Option 3: Use External Elasticsearch

```ruby
# Tell AxonOps not to install Elasticsearch
node.override['axonops']['server']['elasticsearch']['install'] = false
node.override['axonops']['server']['elasticsearch']['url'] = 'http://your-elasticsearch:9200'

include_recipe 'axonops::server'
```

## Configuration Options

All Elasticsearch configuration options are under the `node['axonops']['server']['elastic']` namespace.

### General Settings

| Attribute | Default | Description |
|-----------|---------|-------------|
| `version` | `7.17.26` | Elasticsearch version |
| `cluster_name` | `axonops-cluster` | Cluster name |
| `heap_size` | `512m` | JVM heap size (increase for production) |
| `install_dir` | `/opt/axonops-search` | Installation directory |
| `data_dir` | `/var/lib/axonops-search/data` | Data storage directory |
| `logs_dir` | `/var/log/axonops-search` | Log files directory |

### Network Configuration

| Attribute | Default | Description |
|-----------|---------|-------------|
| `listen_address` | `127.0.0.1` | IP address to bind to |
| `listen_port` | `9200` | HTTP port for Elasticsearch |

**Note**: By default, Elasticsearch only listens on localhost for security. Change `listen_address` only if AxonOps server is on a different host.

### Storage Configuration

The recipe automatically creates the following directory structure:

```
/opt/axonops-search/          # Installation directory
/var/lib/axonops-search/      # Data directory
  └── data/                   # Actual data files
/var/log/axonops-search/      # Log files
/etc/axonops-search/          # Configuration files
```

### Performance Tuning

#### JVM Heap Size

The heap size should be set based on available memory:

```ruby
# For development/testing (default)
node.override['axonops']['server']['elastic']['heap_size'] = '512m'

# For small production deployments
node.override['axonops']['server']['elastic']['heap_size'] = '2g'

# For larger deployments
node.override['axonops']['server']['elastic']['heap_size'] = '4g'
```

**Important**: 
- Never exceed 50% of available RAM
- Never exceed 32GB (compressed oops threshold)
- Heap size should match your data volume and query complexity

### System Settings

The recipe automatically configures:

1. **vm.max_map_count**: Set to 262144 (required by Elasticsearch)
2. **Memory locking**: Enabled to prevent swapping
3. **File descriptors**: Handled by systemd service

## Usage Scenarios

### Scenario 1: Small AxonOps Deployment

For monitoring up to 50 Cassandra nodes:

```ruby
node.override['axonops']['server']['elastic']['heap_size'] = '1g'
node.override['axonops']['server']['elastic']['data_dir'] = '/data/axonops-search'

include_recipe 'axonops::server'
```

### Scenario 2: Medium AxonOps Deployment

For monitoring 50-200 Cassandra nodes:

```ruby
node.override['axonops']['server']['elastic']['heap_size'] = '4g'
node.override['axonops']['server']['elastic']['data_dir'] = '/data/axonops-search'
node.override['axonops']['server']['elastic']['listen_address'] = '0.0.0.0'

include_recipe 'axonops::server'
```

### Scenario 3: Large AxonOps Deployment with External Elasticsearch

For monitoring 200+ Cassandra nodes, use a dedicated Elasticsearch cluster:

```ruby
# Don't install Elasticsearch
node.override['axonops']['server']['elasticsearch']['install'] = false

# Point to your Elasticsearch cluster
node.override['axonops']['server']['elasticsearch']['url'] = 'http://elastic-cluster.internal:9200'

include_recipe 'axonops::server'
```

### Scenario 4: Offline Installation

For air-gapped environments:

```ruby
# Enable offline mode
node.override['axonops']['offline_install'] = true
node.override['axonops']['offline_packages_path'] = '/path/to/packages'

# Ensure elasticsearch-7.17.26-linux-x86_64.tar.gz is in the offline packages directory
include_recipe 'axonops::server'
```

### Scenario 5: Custom Installation Path

```ruby
node.override['axonops']['server']['elastic']['install_dir'] = '/opt/custom/elasticsearch'
node.override['axonops']['server']['elastic']['data_dir'] = '/mnt/fast-ssd/elasticsearch/data'
node.override['axonops']['server']['elastic']['logs_dir'] = '/var/log/custom/elasticsearch'

include_recipe 'axonops::elasticsearch'
```

## Integration with AxonOps

### How AxonOps Uses Elasticsearch

AxonOps uses Elasticsearch for:
1. **Log Storage**: Cassandra logs, system logs, and audit logs
2. **Event Storage**: Operational events, alerts, and notifications
3. **Search**: Full-text search across logs and events
4. **Analytics**: Time-series analysis of operational data

### Data Retention

AxonOps automatically manages data retention in Elasticsearch based on the server retention settings:

```ruby
# Configure retention periods (in weeks)
node.override['axonops']['server']['retention']['events'] = 4
node.override['axonops']['server']['retention']['security_events'] = 8
```

### Index Management

AxonOps creates the following indices:
- `axonops-logs-*`: Cassandra and system logs
- `axonops-events-*`: Operational events
- `axonops-security-*`: Security audit events
- `axonops-alerts-*`: Alert history

## Troubleshooting

### Common Issues

1. **Elasticsearch fails to start**
   ```bash
   # Check service status
   systemctl status axonops-search
   
   # Check logs
   tail -f /var/log/axonops-search/axonops-cluster.log
   ```

2. **Out of memory errors**
   - Increase heap size
   - Check for memory pressure: `free -m`
   - Verify no swapping: `swapon -s`

3. **Cannot connect to Elasticsearch**
   ```bash
   # Test connection
   curl -X GET "localhost:9200/_cluster/health?pretty"
   
   # Check if service is running
   systemctl is-active axonops-search
   ```

4. **Bootstrap checks failed**
   ```bash
   # Verify vm.max_map_count
   sysctl vm.max_map_count
   
   # If too low, the recipe should have fixed it, but you can manually set:
   sysctl -w vm.max_map_count=262144
   ```

### Log Locations

- **Elasticsearch logs**: `/var/log/axonops-search/`
  - `axonops-cluster.log`: Main cluster log
  - `axonops-cluster_deprecation.log`: Deprecation warnings
  - `gc.log`: Garbage collection log

### Useful Commands

```bash
# Service management
systemctl start axonops-search
systemctl stop axonops-search
systemctl restart axonops-search

# Check cluster health
curl -X GET "localhost:9200/_cluster/health?pretty"

# Check node info
curl -X GET "localhost:9200/_nodes?pretty"

# List indices
curl -X GET "localhost:9200/_cat/indices?v"

# Check disk usage
curl -X GET "localhost:9200/_cat/allocation?v"
```

## Maintenance

### Backup

While AxonOps data in Elasticsearch is generally reconstructible from Cassandra nodes, you may want to backup:

```bash
# Snapshot repository setup (example with filesystem)
curl -X PUT "localhost:9200/_snapshot/backup" -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/backup/elasticsearch"
  }
}'

# Create snapshot
curl -X PUT "localhost:9200/_snapshot/backup/snapshot_1?wait_for_completion=true"
```

### Monitoring

Monitor these key metrics:
- **Heap usage**: Should stay below 75%
- **Disk usage**: Ensure adequate free space
- **Response times**: Monitor search and indexing latency
- **GC frequency**: Excessive GC indicates heap pressure

### Upgrading

The cookbook handles Elasticsearch upgrades, but always:
1. Backup your data first
2. Test in a non-production environment
3. Review Elasticsearch upgrade notes for breaking changes

### Space Management

If disk space becomes an issue:

```bash
# Delete old indices (be careful!)
curl -X DELETE "localhost:9200/axonops-logs-2023.01*"

# Or use AxonOps retention settings to automatically manage space
```

## Security Considerations

1. **Network Security**: By default, Elasticsearch only listens on localhost
2. **No Authentication**: This installation has security features disabled as it's meant for internal AxonOps use only
3. **Firewall**: If you change `listen_address`, ensure proper firewall rules
4. **File Permissions**: The recipe sets appropriate permissions, do not modify manually

## Additional Resources

- [Elasticsearch 7.17 Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/7.17/index.html)
- [AxonOps Documentation](https://docs.axonops.com/)
- [Elasticsearch Best Practices](https://www.elastic.co/guide/en/elasticsearch/reference/7.17/best_practices.html)