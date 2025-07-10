# AxonOps Chef Cookbook

A comprehensive Chef cookbook for deploying and configuring the AxonOps monitoring platform for Apache Cassandra. This cookbook supports both SaaS and self-hosted deployments, with API-based configuration management and full offline/airgapped installation capabilities.

## Features

- **Modular Design**: Install only the components you need
- **Non-Invasive**: Monitor existing Cassandra clusters without modifying them
- **Deployment Flexibility**: Support for both SaaS and self-hosted deployments
- **API-Driven Configuration**: Manage alerts, backups, and monitoring via AxonOps API
- **Offline/Airgapped Support**: Full installation capability without internet access
- **Comprehensive Testing**: Full integration test coverage with Test Kitchen
- **Multi-Platform**: Support for Ubuntu, Debian, RHEL, AlmaLinux, and Rocky Linux
- **Java 17**: Uses Azul Zulu Java 17 for optimal performance

## Requirements

### Platform Requirements

- Ubuntu 20.04, 22.04, 24.04
- Debian 11, 12
- AlmaLinux 8, 9
- Rocky Linux 8, 9
- RHEL 8, 9

### Chef Requirements

- Chef Infra Client 14.0+

### Cookbook Dependencies

- Java installation is handled internally (Azul Zulu Java 17)
- No external cookbook dependencies required

## Installation

### From Chef Supermarket (Coming Soon)

```bash
knife cookbook site install axonops
```

### From GitHub

```bash
git clone https://github.com/axonops/axonops-chef-cookbook.git
cd axonops
```

### Using Berkshelf

Add to your `Berksfile`:
```ruby
cookbook 'axonops', git: 'https://github.com/axonops/axonops-chef-cookbook.git'
```

### Using Policyfile

Add to your `Policyfile.rb`:
```ruby
cookbook 'axonops', git: 'https://github.com/axonops/axonops-chef-cookbook.git', branch: 'main'
```

## Overview

This cookbook provides:
- **AxonOps Agent** - Monitor existing Cassandra clusters without modifying them
- **AxonOps Server** - Self-hosted AxonOps deployment (optional)
- **Apache Cassandra** - Install Cassandra 5.0 for your applications (optional)
- **API Configuration** - Manage alerts, backups, and monitoring via AxonOps API
- **Offline Support** - Full airgapped installation capability

## Cookbook Structure

```
axonops/
├── attributes/          # Configuration attributes
├── recipes/            # Chef recipes
├── templates/          # Configuration file templates
├── files/              # Static files
├── test/
│   ├── integration/    # Integration test suites
│   │   ├── agent/      # Agent installation tests
│   │   ├── server/     # Server installation tests
│   │   └── ...         # Other test suites
│   └── fixtures/       # Test helper cookbooks
├── .kitchen.yml        # Test Kitchen configuration
├── .kitchen.local.yml  # Local Kitchen overrides (uses vagrant wrapper)
├── Makefile           # Convenient test commands
├── metadata.rb        # Cookbook metadata
└── bin/
    └── vagrant-wrapper # Wrapper to fix bundler conflicts
```

## Quick Start

### Scenario 1: Monitor Existing Cassandra with AxonOps SaaS

```ruby
# In your Chef recipe or attributes
node.override['axonops']['deployment_mode'] = 'saas'
node.override['axonops']['api']['key'] = 'your-api-key'
node.override['axonops']['api']['organization'] = 'your-org'

# Install just the agent
include_recipe 'axonops::agent'
```

### Scenario 2: Self-Hosted AxonOps with Existing Infrastructure

```ruby
# Use your existing Elasticsearch and Cassandra
node.override['axonops']['deployment_mode'] = 'self-hosted'
node.override['axonops']['server']['enabled'] = true
node.override['axonops']['server']['elasticsearch']['install'] = false
node.override['axonops']['server']['elasticsearch']['url'] = 'http://my-elastic:9200'
node.override['axonops']['server']['cassandra']['install'] = false
node.override['axonops']['server']['cassandra']['hosts'] = ['cassandra1', 'cassandra2']

include_recipe 'axonops::server'
include_recipe 'axonops::dashboard'
include_recipe 'axonops::agent'
```

### Scenario 3: Complete Self-Hosted Stack

```ruby
# Install everything needed for AxonOps
node.override['axonops']['deployment_mode'] = 'self-hosted'
node.override['axonops']['server']['enabled'] = true
node.override['axonops']['dashboard']['enabled'] = true

include_recipe 'axonops::server'     # Includes dependencies
include_recipe 'axonops::dashboard'
include_recipe 'axonops::agent'
```

### Scenario 4: Install Apache Cassandra 5.0 for Applications

```ruby
# Install Cassandra for your applications (separate from AxonOps internal storage)
node.override['cassandra']['install'] = true
node.override['cassandra']['cluster_name'] = 'Production Cluster'
node.override['cassandra']['seeds'] = ['10.0.0.1', '10.0.0.2']

include_recipe 'axonops::cassandra'
include_recipe 'axonops::agent'  # Monitor it with AxonOps
```

## API Configuration

Configure monitoring, alerts, and backups via the AxonOps API:

```ruby
# Configure alert endpoints
node.override['axonops']['alerts']['endpoints']['slack_critical'] = {
  'type' => 'slack',
  'webhook_url' => 'https://hooks.slack.com/...',
  'channel' => '#alerts'
}

# Configure alert rules
node.override['axonops']['alerts']['rules']['high_cpu'] = {
  'metric' => 'cpu_usage',
  'threshold' => 90,
  'duration' => '5m',
  'severity' => 'critical'
}

# Configure backups
node.override['axonops']['backups']['daily_backup'] = {
  'type' => 's3',
  'schedule' => '0 2 * * *',
  'retention' => 7,
  'destination' => 's3://my-bucket/cassandra-backups'
}

# Apply configuration
include_recipe 'axonops::configure'
```

## Offline/Airgapped Installation

### 1. Download packages on internet-connected machine:

```bash
# Use the official AxonOps downloader
git clone https://github.com/axonops/axonops-installer-packages-downloader
cd axonops-installer-packages-downloader
# Follow instructions to download packages

# Or use the cookbook helper
chef-client -o axonops::offline_download_helper
```

### 2. Transfer packages to target environment

Copy all downloaded packages to `/opt/axonops-packages/` on target servers.

### 3. Configure for offline installation:

```ruby
node.override['axonops']['offline_install'] = true
node.override['axonops']['offline_packages_path'] = '/opt/axonops-packages'

# Specify package files
node.override['axonops']['packages']['agent'] = 'axon-agent_2.0.4_amd64.deb'
node.override['axonops']['packages']['server'] = 'axon-server_1.0.0_amd64.deb'
node.override['axonops']['packages']['dashboard'] = 'axon-dash_1.0.0_amd64.deb'
node.override['axonops']['packages']['java_agent'] = 'axon-cassandra5.0-agent-jdk17-1.0.10.jar'
node.override['axonops']['packages']['cassandra_tarball'] = 'apache-cassandra-5.0.4-bin.tar.gz'
node.override['axonops']['packages']['elasticsearch_tarball'] = 'elasticsearch-7.17.16-linux-x86_64.tar.gz'
node.override['axonops']['packages']['zulu_jdk_tarball'] = 'zulu17.46.19-ca-jdk17.0.9-linux_x64.tar.gz'
```

## Recipes

### Main Recipes
- `default` - Entry point (does nothing by itself, include specific recipes as needed)
- `agent` - Installs AxonOps agent to monitor Cassandra clusters
- `server` - Installs AxonOps server (self-hosted mode only)
- `dashboard` - Installs AxonOps web dashboard
- `cassandra` - Installs Apache Cassandra 5.0 for your applications
- `configure` - Configures AxonOps monitoring, alerts, and backups via API
- `offline` - Sets up for offline/airgapped installation

### Supporting Recipes
- `repo` - Configures AxonOps package repository (online mode)
- `java` - Installs Azul Zulu Java 17
- `elasticsearch` - Installs Elasticsearch for AxonOps storage
- `_common` - Common setup for all AxonOps components (internal use)

## Custom Resources (Coming Soon)

The following custom resources are planned for future releases:
- `axonops_alert_rule` - Manage alert rules
- `axonops_notification` - Manage notification endpoints
- `axonops_service_check` - Manage service checks
- `axonops_backup` - Manage backup configurations

Currently, use the `configure` recipe with attributes for API-based configuration.

## Attributes

See `attributes/` directory for all available attributes. Key attribute files:
- `default.rb` - Core AxonOps configuration
- `cassandra.rb` - Apache Cassandra installation settings
- `server.rb` - AxonOps server settings
- `java.rb` - Java/JDK configuration

## Important Notes

### Java Installation
This cookbook installs **Azul Zulu Java 17** by default. This is the recommended Java version for both Cassandra 5.0 and AxonOps components. The cookbook will:
- Add the Azul repository
- Install the `zulu17-jdk` package
- Configure JAVA_HOME appropriately

### Existing Cassandra Clusters
**This cookbook will NOT reinstall or modify your existing Cassandra installations.** The agent recipe only installs the AxonOps monitoring agent, which connects to your existing Cassandra nodes without any modifications.

### System Tuning
The cookbook applies recommended system settings for optimal performance:
- Increases file descriptor limits
- Adjusts virtual memory settings
- Configures network keepalive parameters

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for your changes
4. Ensure all tests pass
5. Submit a pull request

## License

Apache License 2.0

## Authors

- AxonOps Team

## Testing

This cookbook includes comprehensive integration tests using Test Kitchen with Vagrant and VirtualBox.

### Test Environment Setup

1. **Install Required Software**:
   ```bash
   # macOS with Homebrew
   brew install vagrant
   brew install --cask virtualbox
   brew install --cask chef-workstation
   
   # Install Ruby dependencies
   bundle install
   ```

2. **Fix Bundler/Vagrant Conflicts** (if needed):
   If you encounter Ruby/bundler conflicts with Vagrant, the cookbook includes a wrapper script:
   ```bash
   # The cookbook automatically uses bin/vagrant-wrapper for Test Kitchen
   ```

3. **Verify Setup**:
   ```bash
   vagrant --version
   VBoxManage --version
   chef --version
   kitchen --version
   ```

### Running Tests

```bash
# Use the Makefile for common operations
make help                    # Show all available commands
make test-agent             # Test agent installation
make test-all               # Run all test suites

# Or use Kitchen directly
kitchen list                # List all test suites
kitchen test agent-ubuntu-2204     # Full test cycle
kitchen converge agent-ubuntu-2204 # Just converge (keep VM running)
kitchen verify agent-ubuntu-2204   # Just verify
kitchen login agent-ubuntu-2204    # SSH into test VM

# Run multiple suites
kitchen test -c              # Run all tests concurrently
```

### Test Suites

Each test suite verifies different aspects of the cookbook:

- **`default`** - Validates the default recipe (minimal, just logs)
- **`agent`** - Tests AxonOps agent installation and configuration
- **`server`** - Tests self-hosted AxonOps server with storage backends
- **`dashboard`** - Tests AxonOps web UI installation
- **`cassandra`** - Tests Apache Cassandra 5.0 installation
- **`configure`** - Tests API-based configuration management
- **`offline`** - Tests airgapped/offline installation capability
- **`full-stack`** - Tests complete AxonOps deployment (all components)

### Test Platforms

Tests run on multiple platforms to ensure compatibility:
- Ubuntu 20.04, 22.04, 24.04
- Debian 11, 12
- AlmaLinux 8, 9
- Rocky Linux 8, 9

### Verification Scripts

Each test suite includes comprehensive verification scripts that check:
- User and group creation
- Directory structure and permissions
- Package installation
- Configuration files
- Service definitions
- Port availability
- System settings

### Quick Test Commands (Makefile)

The included Makefile provides convenient shortcuts:

```bash
make test-agent             # Test agent only
make test-server            # Test server only
make test-dashboard         # Test dashboard only
make test-cassandra         # Test Cassandra installation
make test-configure         # Test configuration management
make test-offline           # Test offline installation
make test-full-stack        # Test complete stack
make test-all               # Run all tests

# Keep VMs running (faster for iterative testing)
make test-agent-quick       # Converge and verify only
make destroy-all            # Clean up all test VMs
```

### Troubleshooting Tests

1. **Bundler/Vagrant conflicts**: The cookbook includes `bin/vagrant-wrapper` that strips bundler environment variables
2. **VM startup issues**: Ensure VirtualBox is properly installed and you have sufficient resources
3. **Package download failures**: The test recipes use simplified mock installations to avoid external dependencies

### Development Notes

This cookbook was developed with the following considerations:

1. **Test-First Approach**: All recipes have corresponding integration tests
2. **Minimal Dependencies**: No external cookbook dependencies to reduce complexity
3. **Mock Testing**: Test recipes use simplified mock installations to ensure reliable testing
4. **Platform Coverage**: Tests run on all supported platforms using Test Kitchen
5. **Java 17 Standard**: Azul Zulu Java 17 is used throughout for consistency and performance

For more detailed testing information, see [TESTING.md](TESTING.md).

## Support

- [GitHub Issues](https://github.com/axonops/axonops-cookbook/issues)
- [AxonOps Documentation](https://docs.axonops.com)