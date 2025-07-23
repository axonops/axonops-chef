# AxonOps Chef Cookbook

A comprehensive Chef cookbook for deploying and managing AxonOps - the advanced operations platform for Apache Cassandra.

## Overview

The AxonOps Chef cookbook provides flexible, modular recipes for:

- **AxonOps Server** - Self-hosted monitoring and management platform
- **AxonOps Agent** - Lightweight agents for Cassandra node monitoring
- **Apache Cassandra** - Optional Cassandra installation and configuration
- **Elasticsearch** - Search and analytics engine for AxonOps
- **Java/JDK** - Java runtime management
- **API Configuration** - Automated configuration via AxonOps APIs

## Key Features

- 🔧 **Modular Design** - Use only the components you need
- 🚀 **Production Ready** - Battle-tested configurations and best practices
- 🔌 **Flexible Integration** - Works with existing infrastructure
- 🌐 **Multi-Environment** - Supports online and air-gapped installations
- 📊 **Comprehensive Monitoring** - Full Cassandra cluster observability
- 🔐 **Security First** - TLS/SSL support and authentication

## Quick Start

### Adding the Cookbook to Your Berksfile

Add the axonops cookbook to your Berksfile using one of these methods:

```ruby
# Berksfile
source 'https://supermarket.chef.io'

# Pull from a specific branch
cookbook 'axonops', git: 'https://github.com/axonops/axonops-chef.git', branch: 'testing'

# Or pull from a specific tag
cookbook 'axonops', git: 'https://github.com/axonops/axonops-chef.git', tag: 'v1.0.0'

# Or pull from a specific commit
cookbook 'axonops', git: 'https://github.com/axonops/axonops-chef.git', ref: '2bb38d8'
```

### Install AxonOps Agent on Existing Cassandra

```ruby
# Just the agent - no other components
include_recipe 'axonops::agent'
```

### Deploy Self-Hosted AxonOps Server

```ruby
# Full server stack with dashboard
include_recipe 'axonops::server'
include_recipe 'axonops::dashboard'
```

### Install Apache Cassandra

```ruby
# Fresh Cassandra installation
include_recipe 'axonops::cassandra'
```

## Documentation

Detailed documentation for each component:

- 📘 **[AxonOps Server Guide](docs/SERVER.md)** - Deploy and configure the AxonOps server
- 📗 **[AxonOps Agent Guide](docs/AGENT.md)** - Install agents on Cassandra nodes
- 📙 **[Cassandra Installation](docs/CASSANDRA.md)** - Apache Cassandra deployment options
- 📕 **[Elasticsearch Setup](docs/ELASTIC.md)** - Configure Elasticsearch for AxonOps
- 📓 **[Java Management](docs/JAVA.md)** - Java installation and configuration

## Cookbook Structure

```
axonops/
├── attributes/          # Configuration attributes
│   ├── default.rb      # Global settings
│   ├── agent.rb        # Agent configuration
│   ├── server.rb       # Server settings
│   ├── cassandra.rb    # Cassandra options
│   └── java.rb         # Java settings
├── recipes/            # Chef recipes
│   ├── agent.rb        # Agent installation
│   ├── server.rb       # Server deployment
│   ├── cassandra.rb    # Cassandra setup
│   ├── elasticsearch.rb # Elasticsearch install
│   ├── java.rb         # Java installation
│   └── configure_api.rb # API configuration
├── templates/          # Configuration templates
├── files/              # Static files
└── docs/               # Component documentation
```

## Common Use Cases

### 1. Monitor Existing Cassandra Cluster

```ruby
# Configure agent to connect to AxonOps SaaS
node.override['axonops']['agent']['endpoint'] = 'agents.axonops.cloud'
node.override['axonops']['agent']['api_key'] = 'your-api-key'

include_recipe 'axonops::agent'
```

### 2. Self-Hosted AxonOps with External Services

```ruby
# Use existing Elasticsearch and Cassandra
node.override['axonops']['server']['elasticsearch']['install'] = false
node.override['axonops']['server']['elasticsearch']['url'] = 'http://elastic:9200'
node.override['axonops']['server']['cassandra']['install'] = false
node.override['axonops']['server']['cassandra']['hosts'] = ['cassandra1', 'cassandra2']

include_recipe 'axonops::server'
```

### 3. Complete Stack Installation

```ruby
# Install everything: Java, Elasticsearch, Cassandra, AxonOps
include_recipe 'axonops::java'
include_recipe 'axonops::server'
include_recipe 'axonops::agent'
include_recipe 'axonops::cassandra'
```

### 4. Offline/Air-gapped Installation

```ruby
# Configure for offline installation
node.override['axonops']['offline_install'] = true
node.override['axonops']['offline_packages_path'] = '/path/to/packages'

include_recipe 'axonops::server'
```

## Requirements

- **Chef**: 15.0+
- **Platforms**: Ubuntu, CentOS, RHEL, Amazon Linux
- **Memory**: Varies by component (see individual guides)
- **Network**: Internet access (or offline packages)

## Attributes

Key attributes for customization:

```ruby
# Agent configuration
default['axonops']['agent']['endpoint'] = 'agents.axonops.cloud'
default['axonops']['agent']['api_key'] = nil

# Server configuration
default['axonops']['server']['listen_address'] = '0.0.0.0'
default['axonops']['server']['listen_port'] = 8080

# Cassandra settings
default['axonops']['cassandra']['cluster_name'] = 'Test Cluster'
default['axonops']['cassandra']['heap_size'] = '2G'

# Java options
default['axonops']['java']['version'] = '17'
```

See individual documentation files for complete attribute references.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Testing

Run the test suite:

```bash
# Unit tests
chef exec rspec

# Integration tests
kitchen test
```

## Support

- 📖 [AxonOps Documentation](https://docs.axonops.com/)
- 💬 [Community Forum](https://community.axonops.com/)
- 🐛 [Issue Tracker](https://github.com/axonops/axonops-chef/issues)
- 📧 [Support Email](mailto:support@axonops.com)

## License

This cookbook is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.

## About AxonOps

AxonOps is a comprehensive monitoring and management platform designed specifically for Apache Cassandra. It provides:

- Real-time metrics and alerting
- Automated backups and repairs
- Performance optimization
- Security compliance
- Multi-cluster management

Learn more at [axonops.com](https://axonops.com/)

---

**Note**: This cookbook is designed for Chef Supermarket distribution. For the latest updates and releases, check the [Chef Supermarket](https://supermarket.chef.io/cookbooks/axonops) page.