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

### Install Chef Workstation Prerequisites

Before deploying AxonOps, you may need to set up nodes with Chef Workstation tools:

```ruby
# Install knife and chef tools on a management node
include_recipe 'axonops::chef_workstation'
```

This recipe installs:
- Development tools (gcc, make, etc.)
- Ruby and required gems
- Chef Workstation (optional)
- Knife configuration template

Supported platforms:
- RHEL/CentOS/Rocky Linux 7+
- Ubuntu 18.04+
- Amazon Linux 2
- Debian 9+

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

## Chef Server Deployment

### Installing to Chef Server with Berkshelf

First, ensure you have Berkshelf installed:

```bash
gem install berkshelf
```

#### 1. Configure knife.rb

Create or update your `~/.chef/knife.rb` with your Chef server details:

```ruby
# knife.rb
chef_server_url   'https://your-chef-server/organizations/your-org'
node_name         'your-username'
client_key        '/path/to/your-username.pem'
ssl_verify_mode   :verify_none  # Use :verify_peer in production with proper certs
```

#### 2. Install and Upload Cookbooks

```bash
# Install cookbook dependencies locally
berks install

# Upload all cookbooks to Chef Server
berks upload

# Or upload to a specific Chef environment
berks upload --except production

# For air-gapped environments, package cookbooks
berks package cookbooks.tar.gz
# Then on the Chef server:
tar -xzf cookbooks.tar.gz -C /path/to/chef-repo/cookbooks/
```

#### 3. Verify Upload

```bash
# List cookbooks on Chef server
knife cookbook list

# Show specific cookbook details
knife cookbook show axonops
```

## Node Configuration

### Setting Up Nodes with Knife

#### 1. Bootstrap a New Node

```bash
# Bootstrap a node with the axonops::agent recipe
knife bootstrap NODE_IP -x USERNAME -P PASSWORD \
  --node-name cassandra-node-01 \
  --run-list 'recipe[axonops::agent]'

# Or with sudo
knife bootstrap NODE_IP -x USERNAME --sudo \
  --node-name cassandra-node-01 \
  --run-list 'recipe[axonops::agent]'
```

#### 2. Set Node Run List

```bash
# Set a single recipe
knife node run_list set NODE_NAME 'recipe[axonops::agent]'

# Set multiple recipes
knife node run_list set NODE_NAME \
  'recipe[axonops::java]' \
  'recipe[axonops::cassandra]' \
  'recipe[axonops::agent]'

# Add to existing run list
knife node run_list add NODE_NAME 'recipe[axonops::server]'

# Remove from run list
knife node run_list remove NODE_NAME 'recipe[axonops::agent]'
```

#### 3. Set Node Attributes

```bash
# Set individual attributes
knife node attribute set cassandra-node-01 \
  axonops.agent.endpoint 'agents.axonops.cloud'

knife node attribute set cassandra-node-01 \
  axonops.agent.api_key 'your-api-key-here'

# Set nested attributes
knife node attribute set cassandra-node-01 \
  axonops.cassandra.cluster_name 'Production Cluster'

# Set from JSON file
knife node from file nodes/cassandra-node-01.json
```

#### 4. Using Environments

```bash
# Create environment
knife environment create production

# Set node environment
knife node environment set NODE_NAME production

# Upload environment from file
knife environment from file environments/production.json
```

#### 5. Using Roles

```bash
# Create a role for Cassandra nodes
cat > roles/cassandra.json <<EOF
{
  "name": "cassandra",
  "description": "Cassandra database node with AxonOps agent",
  "run_list": [
    "recipe[axonops::java]",
    "recipe[axonops::cassandra]",
    "recipe[axonops::agent]"
  ],
  "default_attributes": {
    "axonops": {
      "cassandra": {
        "heap_size": "8G"
      }
    }
  }
}
EOF

# Upload role
knife role from file roles/cassandra.json

# Assign role to node
knife node run_list set NODE_NAME 'role[cassandra]'
```

#### 6. Check Deployment Status

```bash
# Show node details
knife node show NODE_NAME

# Show node with all attributes
knife node show NODE_NAME -l

# Show specific attributes
knife node show NODE_NAME -a axonops.agent.endpoint
knife node show NODE_NAME -a axonops.cassandra.cluster_name

# List all nodes
knife node list

# Check last chef-client run
knife status
knife status "role:cassandra" --run-list

# Check specific node's last run
knife node show NODE_NAME -a ohai_time
knife node show NODE_NAME -a uptime

# View run list
knife node show NODE_NAME -r

# Check for failed runs
knife search node "ohai_time:[* TO $(date -d '1 hour ago' +%s)] AND NOT chef_environment:_default"

# Search nodes by status
knife search node "platform:ubuntu AND recipes:axonops\\:\\:agent"
knife search node "roles:cassandra AND chef_environment:production"

# SSH into node to check services
knife ssh "name:NODE_NAME" "sudo systemctl status cassandra"
knife ssh "name:NODE_NAME" "sudo systemctl status axon-agent"
knife ssh "name:NODE_NAME" "sudo journalctl -u axon-agent -n 50"

# Run commands on multiple nodes
knife ssh "role:cassandra" "nodetool status" -x ubuntu
knife ssh "recipe:axonops\\:\\:agent" "ps aux | grep axon-agent"

# Check chef-client logs
knife ssh "name:NODE_NAME" "sudo tail -n 100 /var/log/chef-client.log"

# Force chef-client run
knife ssh "name:NODE_NAME" "sudo chef-client" -x USERNAME

# View converge history
knife runs list NODE_NAME

# Check node connectivity
knife node show NODE_NAME -a ipaddress
knife node show NODE_NAME -a platform
knife node show NODE_NAME -a platform_version

# Export node data
knife node show NODE_NAME -F json > node-backup.json

# Verify AxonOps agent connection
knife ssh "name:NODE_NAME" "curl -s http://localhost:9916/metrics | head -20"

# Check Cassandra cluster status from any Cassandra node
knife ssh "role:cassandra" "nodetool describecluster" -x ubuntu | head -50
```

### Troubleshooting Deployment Issues

```bash
# Debug chef-client run
knife ssh "name:NODE_NAME" "sudo chef-client -l debug"

# Check why chef-client failed
knife ssh "name:NODE_NAME" "sudo grep -i error /var/log/chef-client.log | tail -20"

# Verify cookbook versions
knife cookbook show axonops

# Check environment constraints
knife environment show production -F json

# Verify node has latest cookbooks
knife ssh "name:NODE_NAME" "sudo chef-client --why-run"

# Reset node configuration
knife node delete NODE_NAME -y && knife client delete NODE_NAME -y
# Then re-bootstrap the node
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
│   ├── chef_workstation.rb # Chef/Knife prerequisites
│   └── configure_api.rb # API configuration
├── templates/          # Configuration templates
├── files/              # Static files
└── docs/               # Component documentation
```

## Example Node Configuration Files

Example node configuration files are available in the `examples/nodes/` directory:

### [cassandra-node.json](examples/nodes/cassandra-node.json)
Production-ready Cassandra node with AxonOps agent monitoring. Includes:
- Cassandra configuration with proper heap sizes
- AxonOps agent connected to cloud or self-hosted server
- Java 17 with production JVM settings

```bash
# Upload and apply configuration
knife node from file examples/nodes/cassandra-node.json
knife node run_list set cassandra-node-01 'recipe[axonops::java],recipe[axonops::cassandra],recipe[axonops::agent]'
```

### [server-node.json](examples/nodes/server-node.json)
Self-hosted AxonOps server with dashboard and Elasticsearch. Features:
- Full AxonOps server stack
- Integrated Elasticsearch for metrics storage
- Nginx-fronted dashboard with SSL
- Retention policies for metrics and logs

```bash
# Upload and apply configuration
knife node from file examples/nodes/server-node.json
```

### [full-stack-node.json](examples/nodes/full-stack-node.json)
All-in-one development/testing setup. Includes:
- Complete AxonOps stack on single node
- Cassandra, Elasticsearch, Server, and Agent
- Minimal resource requirements for development

```bash
# Perfect for testing or development
knife node from file examples/nodes/full-stack-node.json
```

### [multi-role-node.json](examples/nodes/multi-role-node.json)
Multi-purpose node with various roles. Demonstrates:
- Combining Cassandra with application workloads
- Advanced monitoring and alerting rules
- System tuning and security settings
- Production-grade configurations

```bash
# Upload and apply configuration
knife node from file examples/nodes/multi-role-node.json
```

### [container-node.json](examples/nodes/container-node.json)
Containerized/restricted environment setup. Features:
- System tuning disabled for container compatibility
- vm.max_map_count skipped (managed by orchestrator)
- Kubernetes service discovery DNS names
- External Elasticsearch and Cassandra services
- Minimal run_list for container deployments

```bash
# Perfect for Kubernetes or Docker environments
knife node from file examples/nodes/container-node.json
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
node.override['axonops']['server']['elastic']['install'] = false
node.override['axonops']['server']['search_db']['hosts'] = ['http://elastic:9200/']
node.override['axonops']['server']['search_db']['username'] = 'elastic'
node.override['axonops']['server']['search_db']['password'] = 'secure-password'
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

### 5. Setting Up Chef Workstation on Nodes

```ruby
# Install knife and chef tools for management
node.override['axonops']['chef_workstation']['install_chef_workstation'] = true
node.override['axonops']['chef_workstation']['version'] = 'latest'

include_recipe 'axonops::chef_workstation'
```

Or use it in a run list:

```bash
# Bootstrap a management node with chef workstation
knife bootstrap MANAGEMENT_NODE_IP -x USERNAME --sudo \
  --node-name chef-management-01 \
  --run-list 'recipe[axonops::chef_workstation]'

# Or add to existing node
knife node run_list add chef-management-01 'recipe[axonops::chef_workstation]'
```

### 6. Running in Restricted Environments

```ruby
# Skip vm.max_map_count setting (e.g., in containers or managed environments)
node.override['axonops']['skip_vm_max_map_count'] = true

# Skip vm.swappiness setting (e.g., in containers or managed environments)
node.override['axonops']['skip_vm_swappiness'] = true

# Skip all system tuning
node.override['axonops']['skip_system_tuning'] = true

include_recipe 'axonops::server'
include_recipe 'axonops::agent'
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

# Chef Workstation options
default['axonops']['chef_workstation']['install_chef_workstation'] = true
default['axonops']['chef_workstation']['version'] = 'latest'
default['axonops']['chef_workstation']['install_additional_gems'] = true

# System tuning options
default['axonops']['skip_system_tuning'] = false
default['axonops']['skip_vm_max_map_count'] = false
default['axonops']['skip_vm_swappiness'] = false
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