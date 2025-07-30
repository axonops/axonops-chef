# AxonOps Server Installation Guide

This guide covers the installation and configuration of AxonOps Server for self-hosted deployments using the Chef cookbook.

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Installation Methods](#installation-methods)
- [Configuration Options](#configuration-options)
  - [Server Configuration](#server-configuration)
  - [Elasticsearch Configuration](#elasticsearch-configuration)
  - [Cassandra Configuration](#cassandra-configuration)
  - [TLS/SSL Configuration](#tlsssl-configuration)
  - [Data Retention](#data-retention)
  - [Dashboard Configuration](#dashboard-configuration)
- [Installation Examples](#installation-examples)
- [Post-Installation](#post-installation)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)

## Overview

The AxonOps Server is the central component of a self-hosted AxonOps deployment. It:
- Collects metrics and logs from AxonOps agents
- Stores data in Elasticsearch (logs/events) and Cassandra (metrics)
- Provides APIs for configuration and data access
- Serves the web dashboard for monitoring and management

## Architecture

The AxonOps Server deployment consists of:

```
┌─────────────────────────────────────────────────┐
│                  AxonOps Server                  │
│                                                  │
│  ┌──────────────┐  ┌──────────────┐            │
│  │   AxonOps    │  │   AxonOps    │            │
│  │    Core      │  │  Dashboard   │            │
│  │  (port 8080) │  │ (port 3000)  │            │
│  └──────┬───────┘  └──────────────┘            │
│         │                                        │
│  ┌──────┴───────┐  ┌──────────────┐            │
│  │Elasticsearch │  │  Cassandra   │            │
│  │ (port 9200)  │  │ (port 9042)  │            │
│  └──────────────┘  └──────────────┘            │
└─────────────────────────────────────────────────┘
```

## Requirements

- **Operating System**: Linux (Ubuntu, CentOS, RHEL)
- **Memory**: Minimum 8GB RAM (16GB+ recommended for production)
- **Disk**: 
  - 50GB+ for system and software
  - Additional space for data retention (depends on cluster size)
  - SSD recommended for better performance
- **CPU**: 4+ cores recommended
- **Network**: Open ports 8080 (API), 3000 (Dashboard)
- **Java**: Java 17 (automatically installed by cookbook)

## Installation Methods

### Method 1: Full Stack Installation (Recommended)

Installs AxonOps Server with embedded Elasticsearch and Cassandra:

```ruby
include_recipe 'axonops::server'
include_recipe 'axonops::dashboard'
```

### Method 2: Using External Dependencies

Use existing Elasticsearch and/or Cassandra installations:

```ruby
# Use external Elasticsearch
node.override['axonops']['server']['elastic']['install'] = false
node.override['axonops']['server']['search_db']['hosts'] = ['http://elastic.example.com:9200/']

# Use external Cassandra
node.override['axonops']['server']['cassandra']['install'] = false
node.override['axonops']['server']['cassandra']['hosts'] = ['cassandra1.example.com', 'cassandra2.example.com']

include_recipe 'axonops::server'
```

### Method 3: Offline Installation

For air-gapped environments:

```ruby
node.override['axonops']['offline_install'] = true
node.override['axonops']['offline_packages_path'] = '/path/to/packages'
# For offline install, specify the full RPM/DEB filename
node.override['axonops']['server']['package'] = 'axon-server-2.0.3-1.x86_64.rpm'

include_recipe 'axonops::server'
```

## Configuration Options

### Server Configuration

Core AxonOps Server settings:

| Attribute | Default | Description |
|-----------|---------|-------------|
| `['axonops']['server']['listen_address']` | `0.0.0.0` | IP address for API server |
| `['axonops']['server']['listen_port']` | `8080` | Port for API server |
| `['axonops']['server']['package']` | `axon-server` | Package name (use full filename for offline) |
| `['axonops']['server']['version']` | `latest` | Version to install (online mode) |

### Elasticsearch Configuration

Settings for embedded Elasticsearch:

| Attribute | Default | Description |
|-----------|---------|-------------|
| `['axonops']['server']['elastic']['install']` | `true` | Install embedded Elasticsearch |
| `['axonops']['server']['elastic']['version']` | `7.17.26` | Elasticsearch version |
| `['axonops']['server']['elastic']['heap_size']` | `512m` | JVM heap size |
| `['axonops']['server']['elastic']['cluster_name']` | `axonops-cluster` | Cluster name |
| `['axonops']['server']['elastic']['listen_address']` | `127.0.0.1` | Listen address |
| `['axonops']['server']['elastic']['listen_port']` | `9200` | Listen port |
| `['axonops']['server']['elastic']['data_dir']` | `/var/lib/axonops-search/data` | Data directory |
| `['axonops']['server']['elastic']['logs_dir']` | `/var/log/axonops-search` | Logs directory |

### Search Database Configuration (New Format)

Settings for Elasticsearch connection (new `search_db` format):

| Attribute | Default | Description |
|-----------|---------|-------------|
| `['axonops']['server']['search_db']['hosts']` | `['http://localhost:9200/']` | Array of Elasticsearch hosts |
| `['axonops']['server']['search_db']['username']` | `nil` | Username for authentication |
| `['axonops']['server']['search_db']['password']` | `nil` | Password for authentication |
| `['axonops']['server']['search_db']['skip_verify']` | `false` | Skip SSL/TLS verification |
| `['axonops']['server']['search_db']['replicas']` | `0` | Number of replicas per shard |
| `['axonops']['server']['search_db']['shards']` | `1` | Number of shards per index |

### Cassandra Configuration

Settings for embedded Cassandra (metrics storage):

| Attribute | Default | Description |
|-----------|---------|-------------|
| `['axonops']['server']['cassandra']['install']` | `true` | Install embedded Cassandra |
| `['axonops']['server']['cassandra']['hosts']` | `['127.0.0.1']` | Cassandra hosts (if external) |
| `['axonops']['server']['cassandra']['version']` | `5.0.4` | Cassandra version |
| `['axonops']['server']['cassandra']['dc']` | `axonops` | Datacenter name |
| `['axonops']['server']['cassandra']['username']` | `cassandra` | Username |
| `['axonops']['server']['cassandra']['password']` | `cassandra` | Password |
| `['axonops']['server']['cassandra']['data_dir']` | `/var/lib/axonops-data` | Data directory |

### TLS/SSL Configuration

Security settings for encrypted communications:

| Attribute | Default | Description |
|-----------|---------|-------------|
| `['axonops']['server']['tls']['mode']` | `disabled` | TLS mode: `disabled`, `TLS`, or `mTLS` |
| `['axonops']['server']['tls']['cert_file']` | `nil` | Path to certificate file |
| `['axonops']['server']['tls']['key_file']` | `nil` | Path to private key file |
| `['axonops']['server']['tls']['ca_file']` | `nil` | Path to CA certificate (for mTLS) |

### Data Retention

Configure how long to retain different types of data:

| Attribute | Default | Description |
|-----------|---------|-------------|
| `['axonops']['server']['retention']['events']` | `4` | Event retention (weeks) |
| `['axonops']['server']['retention']['security_events']` | `8` | Security event retention (weeks) |
| `['axonops']['server']['retention']['metrics']['high_resolution']` | `30` | High-res metrics (days) |
| `['axonops']['server']['retention']['metrics']['medium_resolution']` | `24` | Medium-res metrics (weeks) |
| `['axonops']['server']['retention']['metrics']['low_resolution']` | `24` | Low-res metrics (months) |
| `['axonops']['server']['retention']['metrics']['super_low_resolution']` | `3` | Super low-res metrics (years) |
| `['axonops']['server']['retention']['backups']['local']` | `10` | Local backup retention (days) |
| `['axonops']['server']['retention']['backups']['remote']` | `30` | Remote backup retention (days) |

### Dashboard Configuration

Web dashboard settings:

| Attribute | Default | Description |
|-----------|---------|-------------|
| `['axonops']['dashboard']['listen_address']` | `node['ipaddress']` | Dashboard listen address |
| `['axonops']['dashboard']['listen_port']` | `3000` | Dashboard port |
| `['axonops']['dashboard']['server_endpoint']` | `http://127.0.0.1:8080` | AxonOps server API endpoint |
| `['axonops']['dashboard']['context_path']` | `''` | URL context path |
| `['axonops']['dashboard']['package']` | `axon-dash` | Dashboard package name |
| `['axonops']['dashboard']['nginx_proxy']` | `false` | Enable Nginx reverse proxy |

#### Nginx Proxy Configuration (Optional)

If using Nginx as a reverse proxy:

| Attribute | Default | Description |
|-----------|---------|-------------|
| `['axonops']['dashboard']['nginx']['server_name']` | `node['fqdn']` | Server name |
| `['axonops']['dashboard']['nginx']['listen_port']` | `80` | HTTP port |
| `['axonops']['dashboard']['nginx']['ssl_enabled']` | `false` | Enable SSL |
| `['axonops']['dashboard']['nginx']['ssl_port']` | `443` | HTTPS port |
| `['axonops']['dashboard']['nginx']['ssl_certificate']` | `nil` | SSL certificate path |
| `['axonops']['dashboard']['nginx']['ssl_certificate_key']` | `nil` | SSL key path |

## Installation Examples

### Example 1: Basic Installation

Simple self-hosted deployment with all defaults:

```ruby
# This installs everything with default settings
include_recipe 'axonops::server'
include_recipe 'axonops::dashboard'
```

### Example 2: Production Deployment

Production-ready configuration with increased resources:

```ruby
# Increase Elasticsearch heap for production
node.override['axonops']['server']['elastic']['heap_size'] = '4g'

# Configure data directories on dedicated disks
node.override['axonops']['server']['elastic']['data_dir'] = '/data/elasticsearch'
node.override['axonops']['server']['cassandra']['data_dir'] = '/data/cassandra'

# Set retention policies
node.override['axonops']['server']['retention']['events'] = 8  # 8 weeks
node.override['axonops']['server']['retention']['metrics']['high_resolution'] = 60  # 60 days

# Enable TLS
node.override['axonops']['server']['tls']['mode'] = 'TLS'
node.override['axonops']['server']['tls']['cert_file'] = '/etc/ssl/certs/axonops.crt'
node.override['axonops']['server']['tls']['key_file'] = '/etc/ssl/private/axonops.key'

include_recipe 'axonops::server'
include_recipe 'axonops::dashboard'
```

### Example 3: External Dependencies

Using existing Elasticsearch and Cassandra clusters:

```ruby
# Don't install embedded services
node.override['axonops']['server']['elastic']['install'] = false
node.override['axonops']['server']['cassandra']['install'] = false

# Point to external services using new search_db format
node.override['axonops']['server']['search_db']['hosts'] = [
  'http://elastic-cluster.internal:9200/',
  'http://elastic-cluster2.internal:9200/'
]
node.override['axonops']['server']['search_db']['username'] = 'elastic'
node.override['axonops']['server']['search_db']['password'] = 'secure_password'
node.override['axonops']['server']['search_db']['skip_verify'] = true  # For self-signed certs

node.override['axonops']['server']['cassandra']['hosts'] = [
  'cassandra1.internal',
  'cassandra2.internal',
  'cassandra3.internal'
]
node.override['axonops']['server']['cassandra']['dc'] = 'metrics-dc'
node.override['axonops']['server']['cassandra']['username'] = 'axonops'
node.override['axonops']['server']['cassandra']['password'] = 'secure_password'

include_recipe 'axonops::server'
```

### Example 4: High Availability Setup

For HA deployments (requires external load balancer):

```ruby
# Server 1 configuration
node.override['axonops']['server']['listen_address'] = '10.0.1.10'

# Use shared external storage
node.override['axonops']['server']['elastic']['install'] = false
node.override['axonops']['server']['cassandra']['install'] = false
node.override['axonops']['server']['search_db']['hosts'] = ['http://elastic-vip:9200/']
node.override['axonops']['server']['cassandra']['hosts'] = ['cassandra-vip']

# Enable mTLS for inter-service communication
node.override['axonops']['server']['tls']['mode'] = 'mTLS'
node.override['axonops']['server']['tls']['cert_file'] = '/etc/ssl/axonops/server.crt'
node.override['axonops']['server']['tls']['key_file'] = '/etc/ssl/axonops/server.key'
node.override['axonops']['server']['tls']['ca_file'] = '/etc/ssl/axonops/ca.crt'

include_recipe 'axonops::server'
```

### Example 5: Nginx Reverse Proxy

Setting up with Nginx for SSL termination:

```ruby
# Enable Nginx proxy
node.override['axonops']['dashboard']['nginx_proxy'] = true
node.override['axonops']['dashboard']['nginx']['server_name'] = 'axonops.example.com'
node.override['axonops']['dashboard']['nginx']['ssl_enabled'] = true
node.override['axonops']['dashboard']['nginx']['ssl_certificate'] = '/etc/ssl/certs/axonops.crt'
node.override['axonops']['dashboard']['nginx']['ssl_certificate_key'] = '/etc/ssl/private/axonops.key'

# Dashboard listens only on localhost when using proxy
node.override['axonops']['dashboard']['listen_address'] = '127.0.0.1'

include_recipe 'axonops::server'
include_recipe 'axonops::dashboard'
```

## Post-Installation

### 1. Access the Dashboard

After installation, access the AxonOps dashboard:
- URL: `http://<server-ip>:3000`
- Default credentials: Set during initial login

### 2. Configure Organizations

Create your organization and users via the dashboard or API.

### 3. Add Cassandra Clusters

Configure your Cassandra clusters to be monitored:
1. Install AxonOps agents on Cassandra nodes
2. Configure agents to connect to your AxonOps server
3. Verify agents appear in the dashboard

### 4. Set Up Alerts

Configure alerting rules and notification channels via the dashboard or API configuration recipes.

## Troubleshooting

### Service Status

Check all services are running:

```bash
# AxonOps Server
systemctl status axon-server

# Dashboard
systemctl status axon-dash

# Elasticsearch (if embedded)
systemctl status axonops-search

# Cassandra (if embedded)
systemctl status cassandra
```

### Log Locations

- **AxonOps Server**: `/var/log/axonops/axon-server.log`
- **Dashboard**: `/var/log/axonops/axon-dash.log`
- **Elasticsearch**: `/var/log/axonops-search/`
- **Cassandra**: `/var/log/cassandra/`

### Common Issues

1. **Cannot access dashboard**
   - Check firewall rules for port 3000
   - Verify dashboard service is running
   - Check server endpoint configuration

2. **Server fails to start**
   - Verify Elasticsearch and Cassandra are accessible
   - Check TLS certificate paths if TLS is enabled
   - Review server logs for specific errors

3. **High memory usage**
   - Adjust Elasticsearch heap size
   - Review retention policies
   - Consider using external storage services

4. **Agent connection issues**
   - Verify server is listening on accessible address (not just localhost)
   - Check firewall rules for port 8080
   - Verify TLS configuration matches between server and agents

### Health Check

Verify server health:

```bash
# Check API health
curl -X GET "http://localhost:8080/health"

# Check Elasticsearch
curl -X GET "http://localhost:9200/_cluster/health?pretty"

# Check Cassandra
nodetool -h localhost status
```

## Maintenance

### Backup

1. **Configuration backup**:
   ```bash
   # Backup configuration files
   tar -czf axonops-config-backup.tar.gz /etc/axonops/
   ```

2. **Data backup**:
   - Elasticsearch: Use snapshot API
   - Cassandra: Use nodetool snapshot or AxonOps backup feature

### Updates

To update AxonOps Server:

```ruby
# Update to specific version
node.override['axonops']['server']['version'] = '2.1.0'
include_recipe 'axonops::server'
```

### Monitoring

Monitor these key metrics:
- CPU and memory usage
- Disk space (especially data directories)
- Service availability
- API response times
- Agent connection count

### Scaling Considerations

As your deployment grows:
1. Consider external Elasticsearch/Cassandra clusters
2. Implement load balancing for multiple servers
3. Adjust retention policies based on storage capacity
4. Monitor and tune JVM heap sizes
5. Use dedicated hardware for better performance

## Security Best Practices

1. **Enable TLS**: Always use TLS in production
2. **Change default passwords**: Update Cassandra credentials immediately
3. **Firewall rules**: Restrict access to necessary ports only
4. **Regular updates**: Keep AxonOps and dependencies updated
5. **Audit logging**: Enable audit features for compliance
6. **Backup encryption**: Encrypt backups at rest

## Additional Resources

- [AxonOps Documentation](https://docs.axonops.com/)
- [AxonOps API Reference](https://docs.axonops.com/api/)
- [Troubleshooting Guide](https://docs.axonops.com/troubleshooting/)