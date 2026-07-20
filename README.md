<p align="center">
  <a href="https://axonops.com">
    <img src="https://axonops.com/wp-content/uploads/2024/02/logo.svg" alt="AxonOps" width="300">
  </a>
</p>

<p align="center">
  <em>Built and maintained by <a href="https://axonops.com">AxonOps</a></em>
</p>

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

Also monitors an existing **DataStax Enterprise (DSE)** install (5.1, 6.7, 6.8, 6.9) — auto-detected, never
installed or reinstalled. See [docs/DSE.md](docs/DSE.md).

### Deploy Self-Hosted AxonOps Server

```ruby
# Full server stack with dashboard
include_recipe 'axonops::server'
include_recipe 'axonops::dashboard'
```

### Install Apache Cassandra

```ruby
# Fresh Cassandra 5.0.5 installation (default)
include_recipe 'axonops::cassandra'
```

Select the version via the `version` attribute — Java is chosen automatically:

```ruby
# Cassandra 3.11 → Java 8
node.override['axonops']['cassandra']['version'] = '3.11.17'
include_recipe 'axonops::cassandra'

# Cassandra 5.0 → Java 17 (default)
node.override['axonops']['cassandra']['version'] = '5.0.5'
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

## Cassandra Version Support

The cookbook supports Apache Cassandra **3.11.x, 4.1.x, and 5.0.x**. Set the version with `node['axonops']['cassandra']['version']` (default: `5.0.5`).

### Version matrix

| Cassandra | Java | `cassandra.yaml` schema | JVM option files |
|-----------|------|-------------------------|------------------|
| 3.11.x | 8 | Legacy — integer `*_in_ms` / `*_in_mb` / `*_in_kb`, Thrift/RPC keys, megabit streaming | `jvm.options` |
| 4.1.x | 11 | Modern — string-unit values (`32MiB`, `5000ms`, …) | `jvm-server.options` + `jvm11-server.options` |
| 5.0.x | 17 | Modern (same as 4.1) | `jvm-server.options` + `jvm17-server.options` |

Java is selected automatically by `AxonOpsCassandra.java_major(version)` in `libraries/cassandra_version.rb`. You can override with `node['java']['version']` if you manage Java yourself (also set `node['axonops']['cassandra']['skip_java_install'] = true`).

### Cassandra 3.11 example

```ruby
node.override['axonops']['cassandra']['version']      = '3.11.17'
node.override['axonops']['cassandra']['cluster_name'] = 'Legacy Cluster'
node.override['axonops']['cassandra']['heap_size']    = '4G'
node.override['axonops']['cassandra']['gc_type']      = 'G1GC'  # Shenandoah needs Java 11+

# Disable client TLS until a JKS keystore is provided (see docs/CASSANDRA.md#ssl-caveat)
node.override['axonops']['cassandra']['client_encryption_options'] = { 'enabled' => false }

include_recipe 'axonops::cassandra'
```

### Cassandra 5.0 example

```ruby
node.override['axonops']['cassandra']['version']      = '5.0.5'
node.override['axonops']['cassandra']['cluster_name'] = 'Production Cluster'
node.override['axonops']['cassandra']['heap_size']    = '8G'
node.override['axonops']['cassandra']['gc_type']      = 'Shenandoah'

include_recipe 'axonops::cassandra'
```

### SSL caveat

By default `client_encryption_options.enabled` is `true` and expects a JKS keystore at `/opt/cassandra/conf/keystore.jks`. The self-signed cert helper produces PEM files, not JKS, so native transport (CQL/9042) will fail to start until you either:
- Disable client encryption: `node.override['axonops']['cassandra']['client_encryption_options'] = { 'enabled' => false }`
- Provide a JKS keystore at the configured path

See [docs/CASSANDRA.md](docs/CASSANDRA.md#ssl-caveat) for details. PEM-based TLS is tracked in issue #26.

## Documentation

Detailed documentation for each component:

- 📘 **[AxonOps Server Guide](docs/SERVER.md)** - Deploy and configure the AxonOps server
- 📗 **[AxonOps Agent Guide](docs/AGENT.md)** - Install agents on Cassandra, DSE, or Kafka nodes
- 📙 **[Cassandra Installation](docs/CASSANDRA.md)** - Apache Cassandra deployment options
- 🗄️ **[DataStax Enterprise Monitoring](docs/DSE.md)** - Monitor an existing DSE cluster (5.1, 6.7, 6.8, 6.9)
- 📨 **[Kafka Installation](docs/KAFKA.md)** - Apache Kafka deployment options
- 📕 **[Elasticsearch Setup](docs/ELASTIC.md)** - Configure Elasticsearch for AxonOps
- 🔔 **[Alert Rules & Service Checks](docs/ALERTS.md)** - Configure alerts, checks, and notifications via API

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

### [cassandra-311-pkg-node.json](examples/nodes/cassandra-311-pkg-node.json)
Apache Cassandra 3.11 installed from the RPM package repository (rather than
tarball), with AxonOps agent monitoring. Includes:
- `install_format: 'pkg'` — installs from `packages.axonops.com`/the 3.11
  JFrog mirror instead of downloading a tarball
- `start_on_install: true` — starts Cassandra immediately after converge

```bash
# Upload and apply configuration
knife node from file examples/nodes/cassandra-311-pkg-node.json
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
# Configure agent to connect to AxonOps SaaS (default hosts/port need no override)
node.override['axonops']['agent']['org_key']  = 'your-org-key'
node.override['axonops']['agent']['org_name'] = 'your-org-name'

include_recipe 'axonops::agent'
```

Also monitors an existing DataStax Enterprise (DSE) install (5.1, 6.7, 6.8, 6.9) automatically —
see [docs/AGENT.md](docs/AGENT.md) and [docs/DSE.md](docs/DSE.md) for more
examples (self-hosted mode, TLS/mTLS, Kafka monitoring, offline install).

### 2. Self-Hosted AxonOps with External Services

```ruby
# Use existing Elasticsearch and Cassandra
node.override['axonops']['server']['elastic']['install'] = false

# For axon-server >= 2.0.4, use the new search_db format
node.override['axonops']['server']['search_db']['hosts'] = ['http://elastic:9200/']
node.override['axonops']['server']['search_db']['username'] = 'elastic'
node.override['axonops']['server']['search_db']['password'] = 'secure-password'

# The cookbook automatically handles older versions using elastic_host/elastic_port

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

# Package filenames are defined in attributes/default.rb. 'cassandra' is the
# tarball (tar install_format, and axonops::server's own metrics-storage
# Cassandra, which is always tar); 'cassandra_pkg' is the separate RPM/deb
# used by axonops::cassandra's pkg install_format — never the same file.
# default['axonops']['offline_packages'] = {
#   'elasticsearch' => 'elasticsearch-7.17.29-linux-x86_64.tar.gz',
#   'cassandra' => 'apache-cassandra-5.0.5-bin.tar.gz',
#   'cassandra_pkg' => 'cassandra-5.0.5-1.noarch.rpm',
#   'java' => 'zulu17-ca-jdk-headless-17.0.16-1.x86_64.rpm',
#   'agent' => 'axon-agent-2.0.6-1.x86_64.rpm',
#   'server' => 'axon-server-2.0.5-1.x86_64.rpm',
#   'dashboard' => 'axon-dash-2.0.10-1.x86_64.rpm',
#   'java_agent' => 'axon-cassandra5.0-agent-jdk17-1.0.10-1.noarch.rpm'
# }

include_recipe 'axonops::server'
```

Covered by `offline_install`: `axonops::agent`, `axonops::server`, `axonops::cassandra`,
`axonops::kafka`, `axonops::elasticsearch`, and their shared `axonops::java` dependency —
setting the single flag above is enough for all of them.

**Not covered:** `axonops::chef_workstation` always downloads Chef Workstation from
`packages.chef.io`. It installs developer/operator tooling (knife, chef-workstation,
berkshelf) on a workstation or bastion host used to *drive* Chef runs — it is not part of
the target-node install path, so it is intentionally excluded from airgapped support.

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
default['axonops']['agent']['hosts']   = 'agents.axonops.cloud'
default['axonops']['agent']['port']    = 443
default['axonops']['agent']['org_key']  = nil
default['axonops']['agent']['org_name'] = nil

# Server configuration
default['axonops']['server']['listen_address'] = '0.0.0.0'
default['axonops']['server']['listen_port'] = 8080

# Cassandra settings
default['axonops']['cassandra']['version']         = '5.0.5'  # 3.11.x / 4.1.x / 5.0.x
default['axonops']['cassandra']['cluster_name']    = 'AxonOps Cluster'
default['axonops']['cassandra']['heap_size']       = '2G'
default['axonops']['cassandra']['gc_type']         = 'Shenandoah'  # or 'G1GC' (required for 3.11)
default['axonops']['cassandra']['install_format']  = 'tar'  # or 'pkg' (apt/yum; not available for 3.11 on Debian)
default['axonops']['cassandra']['start_on_install'] = false  # Chef only starts Cassandra if true — leave false for controlled multi-node bootstraps
default['axonops']['cassandra']['redhat_repository_url_311x'] = 'https://apache.jfrog.io/artifactory/cassandra-rpm/311x/'  # 3.11 RPM mirror (Apache dropped it from the official repo)

# Java options — overridden automatically by axonops::cassandra based on Cassandra version
# (3.11 -> 8, 4.1 -> 11, 5.0 -> 17). Override only when skip_java_install is true.
default['java']['version'] = 17

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

### Unit tests (RSpec)

```bash
# Run the full spec suite
chef exec rspec

# Run a single spec file directly
rspec --options /dev/null spec/unit/libraries/cassandra_version_spec.rb
rspec --options /dev/null spec/unit/templates/cassandra_3_11_yaml_spec.rb
```

### BDD feature files

Gherkin scenarios describing version selection and install behaviour live under `features/`:

```
features/cassandra_install.feature
features/cassandra_version_support.feature
```

### Integration tests (Test Kitchen)

Suites run via the Dokken driver against Ubuntu 22.04, Rocky Linux 9, Amazon
Linux 2, and Amazon Linux 2023:

| Suite | Cassandra version | Notes |
|-------|-------------------|-------|
| `cassandra-3-11` | 3.11.17 | |
| `cassandra-default` | 5.0.5 | |
| `cassandra-offline` | 5.0.5 | `offline_install: true`, agent disabled — see [docs/CASSANDRA.md](docs/CASSANDRA.md) |

```bash
# Converge and verify Cassandra 3.11 on Ubuntu
kitchen converge cassandra-3-11-ubuntu-2204
kitchen verify   cassandra-3-11-ubuntu-2204

# Full cycle for 5.0 default on Rocky Linux
kitchen test cassandra-default-rockylinux-9

# Full cycle for 5.0 default on Amazon Linux 2023
kitchen test cassandra-default-amazonlinux-2023

# Destroy all containers
kitchen destroy
```

InSpec controls are under `test/integration/`. CI runs the unit suite on every pull request via `.github/workflows/ci.yml`.

## License

This cookbook is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.

## Contact

This project is maintained by [AxonOps](https://axonops.com). For support, visit [axonops.com/contact](https://axonops.com/contact).

Additional resources:

- [AxonOps Documentation](https://docs.axonops.com/)
- [Issue Tracker](https://github.com/axonops/axonops-chef/issues)

---

*AxonOps is a registered trademark of AxonOps Limited. Apache, Apache Cassandra, Cassandra, Apache Kafka and Kafka are either registered trademarks or trademarks of the Apache Software Foundation or its subsidiaries in Canada, the United States and/or other countries. Elasticsearch is a trademark of Elasticsearch B.V. Docker is a trademark or registered trademark of Docker, Inc.*

## Testing

To run unit tests:
```bash
bundle exec rspec spec/
```

To run Kitchen tests:
```bash
bundle exec kitchen test
```

By default, Kitchen uses Vagrant. You can select Docker with:
```bash
KITCHEN_DRIVER=docker bundle exec kitchen test
```

Docker-driven Kitchen runs boot real systemd inside the container (see
`test/docker/Dockerfile.systemd-ubuntu`/`Dockerfile.systemd-rockylinux`) —
AxonOps packages call `systemctl` in their postinst scripts, which needs an
actual init system kitchen-docker's stock containers don't provide.

`chefignore` keeps this repo's own dev/test tooling (`Gemfile`, `spec/`,
`test/`, `kitchen.yml`, etc.) out of what Chef treats as "the cookbook" —
without it, Chef auto-bundle-installs the dev `Gemfile` on every converge.
