# AxonOps Chef Cookbook Documentation

Welcome to the AxonOps Chef cookbook documentation. This cookbook provides comprehensive installation and configuration management for the entire AxonOps ecosystem.

## Documentation Index

### Getting Started
- [Quick Start Guide](../README.md) - Basic usage and examples
- [Installation Guide](../INSTALL.md) - Detailed installation instructions
- [Testing Guide](../TESTING_SUMMARY.md) - How to test the cookbook

### Configuration
- [Default Configurations](DEFAULT_CONFIGURATIONS.md) - All default settings explained
- [Attributes Reference](ATTRIBUTES_REFERENCE.md) - Complete list of available attributes
- [Configuration Examples](CONFIGURATION_EXAMPLES.md) - Real-world deployment scenarios

### Development
- [Contributing Guide](../CONTRIBUTING.md) - How to contribute to the cookbook
- [Checkpoint Documentation](../CHECKPOINT.md) - Development status and TODOs

## Quick Links

### For Users
1. **Installing AxonOps Agent on existing Cassandra**
   - See: [Configuration Examples - Basic SaaS Agent](CONFIGURATION_EXAMPLES.md#basic-saas-agent-deployment)

2. **Self-hosted AxonOps deployment**
   - See: [Configuration Examples - Self-Hosted Full Stack](CONFIGURATION_EXAMPLES.md#self-hosted-full-stack)

3. **Offline/Airgapped installation**
   - See: [Configuration Examples - Offline Installation](CONFIGURATION_EXAMPLES.md#offlineairgapped-installation)

### For Operators
1. **Production Cassandra cluster setup**
   - See: [Configuration Examples - Production Cluster](CONFIGURATION_EXAMPLES.md#production-cassandra-cluster)

2. **Multi-datacenter configuration**
   - See: [Configuration Examples - Multi-DC Setup](CONFIGURATION_EXAMPLES.md#multi-datacenter-setup)

3. **Performance tuning**
   - See: [Configuration Examples - High Performance](CONFIGURATION_EXAMPLES.md#high-performance-configuration)

### For Security Teams
1. **Security hardening**
   - See: [Configuration Examples - Security Hardened](CONFIGURATION_EXAMPLES.md#security-hardened-setup)

2. **SSL/TLS configuration**
   - See: [Default Configurations - Security](DEFAULT_CONFIGURATIONS.md#system-configuration-defaults)

## Component Overview

### AxonOps Components
- **Agent** - Monitors Cassandra nodes and sends metrics
- **Server** - Collects metrics and provides API (self-hosted only)
- **Dashboard** - Web UI for monitoring and management
- **Java Agent** - JVM-level monitoring for Cassandra

### Supporting Components
- **Apache Cassandra** - NoSQL database (optional installation)
- **Elasticsearch** - Search and analytics for AxonOps data
- **Java/Zulu JDK** - Java runtime environment

## Default Ports

| Service | Port | Protocol |
|---------|------|----------|
| AxonOps Server | 8080 | HTTP |
| AxonOps Dashboard | 3000 | HTTP |
| Elasticsearch | 9200 | HTTP |
| Cassandra CQL | 9042 | TCP |
| Cassandra JMX | 7199 | TCP |

## Testing Status

All cookbook components have been thoroughly tested:

✅ **Unit Tests** - ChefSpec tests for all recipes
✅ **Integration Tests** - Test Kitchen with InSpec
✅ **Multi-node Tests** - Distributed deployment testing
✅ **Real Package Tests** - Verified with official AxonOps packages
✅ **Cross-platform** - Ubuntu 20.04, 22.04, 24.04

See [TESTING_SUMMARY.md](../TESTING_SUMMARY.md) for detailed test results.

## Support Matrix

### Operating Systems
- Ubuntu 20.04 LTS
- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- Debian 11 (planned)
- RHEL 8/9 (planned)

### Cassandra Versions
- Apache Cassandra 3.0.x
- Apache Cassandra 3.11.x
- Apache Cassandra 4.0.x
- Apache Cassandra 4.1.x
- Apache Cassandra 5.0.x

### Java Versions
- JDK 8 (Cassandra 3.x)
- JDK 11 (Cassandra 4.x)
- JDK 17 (Cassandra 5.x)

## Common Tasks

### Override Default Settings
```ruby
# In your wrapper cookbook
node.override['cassandra']['heap_size'] = '8G'
node.override['axonops']['agent']['hosts'] = 'axonops.internal'
```

### Add Custom Alerts
```ruby
axonops_alert_rule 'high_cpu' do
  metric 'cpu.usage'
  threshold 90
  duration '5m'
  severity 'critical'
end
```

### Configure Backups
```ruby
axonops_backup_config 'daily' do
  type 's3'
  schedule '0 2 * * *'
  retention_days 30
  s3_bucket 'my-backups'
end
```

## Getting Help

1. Check the [Attributes Reference](ATTRIBUTES_REFERENCE.md)
2. Review [Configuration Examples](CONFIGURATION_EXAMPLES.md)
3. See the [AxonOps Documentation](https://docs.axonops.com)
4. Open an issue on GitHub

## License

This cookbook is licensed under the Apache 2.0 License. See [LICENSE](../LICENSE) for details.