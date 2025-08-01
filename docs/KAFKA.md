# Apache Kafka Installation and Configuration

This document describes how to use the AxonOps Chef cookbook to install and configure Apache Kafka.

## Overview

The `axonops::kafka` recipe installs Apache Kafka from the official Apache archives. It supports:

- Apache Kafka 3.5.1+ (configurable)
- Both Zookeeper-based and KRaft mode deployments
- SSL/TLS encryption
- SASL authentication
- Kafka Connect (optional)
- Online and offline installation modes
- Integration with AxonOps monitoring

## Prerequisites

- Java 11 or higher (automatically installed via `axonops::java` recipe)
- Sufficient disk space for Kafka logs and data
- Network connectivity to Apache archives (for online installation)

## Basic Usage

### Simple Installation

```ruby
# In your run list or recipe
include_recipe 'axonops::kafka'
```

This will install Kafka with default settings:
- Kafka 3.9.1 with Scala 2.13
- Single broker configuration
- Plaintext listeners on port 9092
- Local Zookeeper on port 2181

### Installation with AxonOps Monitoring

```ruby
# Install Kafka first, then the agent
include_recipe 'axonops::kafka'
include_recipe 'axonops::agent'
```

## Configuration

### Node Attributes

#### Basic Configuration

```ruby
# Kafka version
node.override['axonops']['kafka']['version'] = '3.9.1'
node.override['axonops']['kafka']['scala_version'] = '2.13'

# Installation directory
node.override['axonops']['kafka']['install_dir'] = '/opt/kafka'

# User and group
node.override['axonops']['kafka']['user'] = 'kafka'
node.override['axonops']['kafka']['group'] = 'kafka'

# Broker configuration
node.override['axonops']['kafka']['broker_id'] = 1
node.override['axonops']['kafka']['port'] = 9092
node.override['axonops']['kafka']['advertised_hostname'] = node['ipaddress']

# Data directories
node.override['axonops']['kafka']['data_dir'] = '/var/lib/kafka/data'
node.override['axonops']['kafka']['log_dir'] = '/var/log/kafka'
```

#### Network Configuration

```ruby
# Listeners
node.override['axonops']['kafka']['listeners'] = 'PLAINTEXT://0.0.0.0:9092'
node.override['axonops']['kafka']['advertised_listeners'] = "PLAINTEXT://#{node['fqdn']}:9092"

# Network threads
node.override['axonops']['kafka']['num_network_threads'] = 3
node.override['axonops']['kafka']['num_io_threads'] = 8
```

#### JVM Settings

```ruby
# Heap size
node.override['axonops']['kafka']['heap_size'] = '2G'

# JVM performance options
node.override['axonops']['kafka']['jvm_performance_opts'] = '-server -XX:+UseG1GC -XX:MaxGCPauseMillis=20'
```

### Advanced Configurations

#### Multi-Broker Setup

```ruby
# For a 3-broker cluster
node.override['axonops']['kafka']['broker_id'] = 1  # Unique per broker
node.override['axonops']['kafka']['default_replication_factor'] = 3
node.override['axonops']['kafka']['min_insync_replicas'] = 2
node.override['axonops']['kafka']['zookeeper_connect'] = 'zk1:2181,zk2:2181,zk3:2181/kafka'
```

#### SSL/TLS Configuration

```ruby
# Enable SSL
node.override['axonops']['kafka']['ssl']['enabled'] = true

# Listeners for SSL
node.override['axonops']['kafka']['listeners'] = 'SSL://0.0.0.0:9093'
node.override['axonops']['kafka']['advertised_listeners'] = "SSL://#{node['fqdn']}:9093"

# SSL certificates
node.override['axonops']['kafka']['ssl']['keystore_location'] = '/opt/kafka/ssl/kafka.keystore.jks'
node.override['axonops']['kafka']['ssl']['keystore_password'] = 'your-keystore-password'
node.override['axonops']['kafka']['ssl']['key_password'] = 'your-key-password'
node.override['axonops']['kafka']['ssl']['truststore_location'] = '/opt/kafka/ssl/kafka.truststore.jks'
node.override['axonops']['kafka']['ssl']['truststore_password'] = 'your-truststore-password'

# Client authentication
node.override['axonops']['kafka']['ssl']['client_auth'] = 'required'  # none, requested, required
node.override['axonops']['kafka']['ssl']['enabled_protocols'] = 'TLSv1.2,TLSv1.3'
```

#### SASL Authentication

```ruby
# Enable SASL
node.override['axonops']['kafka']['sasl']['enabled'] = true
node.override['axonops']['kafka']['sasl']['mechanism'] = 'SCRAM-SHA-256'  # PLAIN, SCRAM-SHA-256, SCRAM-SHA-512

# Combined SSL + SASL
node.override['axonops']['kafka']['listeners'] = 'SASL_SSL://0.0.0.0:9094'
node.override['axonops']['kafka']['advertised_listeners'] = "SASL_SSL://#{node['fqdn']}:9094"
node.override['axonops']['kafka']['sasl']['interbroker_protocol'] = 'SASL_SSL'
```

#### KRaft Mode (Zookeeper-less)

```ruby
# Enable KRaft mode
node.override['axonops']['kafka']['kraft_mode'] = true
node.override['axonops']['kafka']['node_id'] = 1
node.override['axonops']['kafka']['process_roles'] = 'broker,controller'

# For a 3-node KRaft cluster
node.override['axonops']['kafka']['controller_quorum_voters'] = '1@node1:9093,2@node2:9093,3@node3:9093'
```

#### Kafka Connect

```ruby
# Enable Kafka Connect
node.override['axonops']['kafka']['connect']['enabled'] = true
node.override['axonops']['kafka']['connect']['port'] = 8083
node.override['axonops']['kafka']['connect']['plugin_path'] = '/opt/kafka/connect-plugins'

# Connect cluster settings
node.override['axonops']['kafka']['connect']['group_id'] = 'connect-cluster'
node.override['axonops']['kafka']['connect']['offset_storage_topic'] = 'connect-offsets'
node.override['axonops']['kafka']['connect']['config_storage_topic'] = 'connect-configs'
node.override['axonops']['kafka']['connect']['status_storage_topic'] = 'connect-status'
```

### Offline Installation

For environments without internet access:

```ruby
# Enable offline mode
node.override['axonops']['offline_install'] = true
node.override['axonops']['offline_packages_path'] = '/path/to/offline/packages'

# Specify the Kafka tarball name
node.override['axonops']['packages']['kafka_tarball'] = 'kafka_2.13-3.9.1.tgz'
```

Ensure the Kafka tarball is present in the offline packages directory before running the recipe.

## Log Retention and Storage

### Configure Log Retention

```ruby
# Log retention
node.override['axonops']['kafka']['log_retention_hours'] = 168  # 7 days
node.override['axonops']['kafka']['log_segment_bytes'] = 1073741824  # 1GB
node.override['axonops']['kafka']['log_retention_check_interval_ms'] = 300000  # 5 minutes

# Log directories (can be multiple for performance)
node.override['axonops']['kafka']['data_dir'] = '/data1/kafka,/data2/kafka,/data3/kafka'
```

## Performance Tuning

### Operating System Settings

The recipe automatically configures:
- `vm.swappiness=1` for better performance
- File descriptor limits (default: 1048576)
- Process limits

### JVM Tuning

```ruby
# For production workloads
node.override['axonops']['kafka']['heap_size'] = '6G'
node.override['axonops']['kafka']['jvm_performance_opts'] = <<-EOF
  -server 
  -XX:+UseG1GC 
  -XX:MaxGCPauseMillis=20 
  -XX:InitiatingHeapOccupancyPercent=35 
  -XX:+ExplicitGCInvokesConcurrent 
  -XX:MaxInlineLevel=15 
  -Djava.awt.headless=true
EOF
```

## Monitoring with AxonOps

When used with `axonops::agent`, the following metrics are automatically collected:

- Broker metrics (requests, bytes in/out, partitions)
- Topic metrics (messages, bytes)
- Consumer group lag
- JVM metrics (heap, GC, threads)
- System metrics (CPU, memory, disk, network)

## Service Management

The recipe creates systemd services:

```bash
# Kafka broker
sudo systemctl start kafka
sudo systemctl stop kafka
sudo systemctl restart kafka
sudo systemctl status kafka

# Kafka Connect (if enabled)
sudo systemctl start kafka-connect
sudo systemctl stop kafka-connect
sudo systemctl restart kafka-connect
sudo systemctl status kafka-connect
```

## Directory Structure

After installation:

```
/opt/kafka/                    # Installation directory
├── bin/                       # Kafka scripts and binaries
├── config/                    # Configuration files
│   ├── server.properties      # Main Kafka configuration
│   ├── log4j.properties       # Logging configuration
│   └── connect-distributed.properties  # Connect configuration
├── libs/                      # Kafka JAR files
├── logs/                      # Application logs (symlink to /var/log/kafka)
└── ssl/                       # SSL certificates directory

/var/lib/kafka/data/          # Kafka data/log segments
/var/log/kafka/               # Kafka logs
/var/tmp/kafka/               # Temporary files
```

## Troubleshooting

### Common Issues

1. **Broker fails to start**
   - Check `/var/log/kafka/server.log` for errors
   - Verify Zookeeper is running (if not using KRaft)
   - Ensure ports are not already in use

2. **Cannot connect to broker**
   - Verify `advertised.listeners` is correctly set
   - Check firewall rules
   - Test with `kafka-broker-api-versions.sh --bootstrap-server localhost:9092`

3. **High memory usage**
   - Adjust heap size based on workload
   - Monitor GC logs in `/var/log/kafka/`
   - Consider tuning JVM parameters

### Logging

Kafka logs are managed by log4j and written to `/var/log/kafka/`:
- `server.log` - Main broker log
- `controller.log` - Controller-specific logs
- `state-change.log` - Partition state changes
- `kafka-request.log` - Request logging (if enabled)

## Security Best Practices

1. **Always use authentication in production**
   - Enable SSL/TLS for encryption
   - Use SASL for authentication
   - Configure ACLs for authorization

2. **Secure the installation**
   - Restrict file permissions
   - Use dedicated service accounts
   - Enable audit logging

3. **Network security**
   - Use internal networks for inter-broker communication
   - Implement firewall rules
   - Consider network segmentation

## Example Configurations

### Development Environment

```ruby
include_recipe 'axonops::kafka'
```

### Production Cluster Node

```ruby
# Node-specific settings
node.override['axonops']['kafka']['broker_id'] = 1
node.override['axonops']['kafka']['rack'] = 'us-east-1a'

# Cluster settings
node.override['axonops']['kafka']['zookeeper_connect'] = 'zk1:2181,zk2:2181,zk3:2181/kafka'
node.override['axonops']['kafka']['default_replication_factor'] = 3
node.override['axonops']['kafka']['min_insync_replicas'] = 2

# Performance settings
node.override['axonops']['kafka']['heap_size'] = '8G'
node.override['axonops']['kafka']['num_network_threads'] = 8
node.override['axonops']['kafka']['num_io_threads'] = 16

# Security
node.override['axonops']['kafka']['ssl']['enabled'] = true
node.override['axonops']['kafka']['sasl']['enabled'] = true

include_recipe 'axonops::kafka'
include_recipe 'axonops::agent'
```

## Integration with Other AxonOps Components

The Kafka installation can be monitored alongside Cassandra:

```ruby
# Install both Cassandra and Kafka with monitoring
include_recipe 'axonops::cassandra'
include_recipe 'axonops::kafka'
include_recipe 'axonops::agent'  # Will detect and monitor both
```

## Support

For issues related to:
- Kafka installation or configuration: Check Apache Kafka documentation
- AxonOps monitoring: Contact AxonOps support
- Chef cookbook: File an issue in the cookbook repository