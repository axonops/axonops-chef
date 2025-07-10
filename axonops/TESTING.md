# Testing Guide for AxonOps Chef Cookbook

This document provides detailed information about testing the AxonOps Chef cookbook.

## Test Environment Requirements

### Required Software

1. **Vagrant** (2.3.0+)
   - Manages virtual machines for testing
   - Install: `brew install vagrant` or download from vagrantup.com

2. **VirtualBox** (7.0+)
   - Free virtualization provider
   - Install: `brew install --cask virtualbox` or download from virtualbox.org
   - Alternative: VMware Fusion/Workstation (requires vagrant-vmware plugin)

3. **Chef Workstation**
   - Includes Test Kitchen and other Chef tools
   - Install: `brew install --cask chef-workstation`

4. **Ruby** (via bundler)
   - Install dependencies: `bundle install`

## Known Issues and Solutions

### Bundler/Vagrant Conflict

If you encounter errors like "Could not find chef-17.10.0" when running kitchen commands, this is due to a conflict between your Ruby environment and Vagrant's embedded Ruby.

**Solution**: The cookbook includes a vagrant wrapper script that's automatically used via `.kitchen.local.yml`:

```yaml
driver:
  vagrant_binary: /path/to/cookbook/bin/vagrant-wrapper
```

The wrapper strips bundler environment variables before calling vagrant.

### Test Architecture

The cookbook uses a multi-tiered testing approach:

1. **Linting** - Ruby and Chef style checks
2. **Unit Tests** - ChefSpec tests (if present)
3. **Integration Tests** - Test Kitchen with real VMs

## Integration Test Suites

### Agent Test (`test/integration/agent/`)
Tests the AxonOps agent installation and configuration:
- Agent package installation
- User/group creation
- Directory permissions
- Configuration file generation
- Systemd service creation
- Port verification

### Server Test (`test/integration/server/`)
Tests the self-hosted AxonOps server:
- Server binary installation
- Elasticsearch dependency
- Cassandra storage setup
- API endpoint configuration
- Service management

### Dashboard Test (`test/integration/dashboard/`)
Tests the AxonOps web UI:
- Dashboard package installation
- Web server configuration
- Static asset setup
- Service configuration

### Cassandra Test (`test/integration/cassandra/`)
Tests Apache Cassandra 5.0 installation:
- Java 17 installation (Azul Zulu)
- Cassandra package/tarball installation
- Directory structure
- Configuration files
- Service setup

### Configure Test (`test/integration/configure/`)
Tests API-based configuration:
- Alert rule creation
- Notification endpoint setup
- Backup configuration
- Service check configuration

### Offline Test (`test/integration/offline/`)
Tests airgapped installation:
- Local package installation
- No external repository access
- Offline Java installation
- Configuration for internal networks

### Full-Stack Test (`test/integration/full-stack/`)
Tests complete deployment:
- All components together
- Inter-component connectivity
- End-to-end functionality

## Running Tests

### Using Make (Recommended)

```bash
# Show all available commands
make help

# Run specific test suite
make test-agent
make test-server
make test-dashboard

# Run all tests
make test-all

# Quick tests (don't destroy VM)
make test-agent-quick

# Clean up
make destroy-all
```

### Using Kitchen Directly

```bash
# List all test suites
kitchen list

# Run complete test cycle
kitchen test agent-ubuntu-2204

# Run tests step by step
kitchen create agent-ubuntu-2204    # Create VM
kitchen converge agent-ubuntu-2204  # Run Chef
kitchen verify agent-ubuntu-2204    # Run tests
kitchen destroy agent-ubuntu-2204   # Clean up

# Debug failed tests
kitchen login agent-ubuntu-2204     # SSH into VM
```

### Test Platforms

Each suite runs on multiple platforms:
- `ubuntu-2004` - Ubuntu 20.04 LTS
- `ubuntu-2204` - Ubuntu 22.04 LTS
- `ubuntu-2404` - Ubuntu 24.04 LTS
- `debian-11` - Debian 11 (Bullseye)
- `debian-12` - Debian 12 (Bookworm)
- `almalinux-8` - AlmaLinux 8
- `almalinux-9` - AlmaLinux 9
- `rockylinux-8` - Rocky Linux 8
- `rockylinux-9` - Rocky Linux 9

### Verification Scripts

Each test suite includes a `verify.sh` script that checks:
- User and group creation
- Directory structure and permissions
- File contents
- Service definitions
- Port availability
- Process status

## Writing Tests

### Adding a New Test Suite

1. Create directory: `test/integration/my-suite/`
2. Add verification script: `test/integration/my-suite/verify.sh`
3. Add to `.kitchen.yml`:
   ```yaml
   suites:
     - name: my-suite
       run_list:
         - recipe[axonops::my_recipe]
       verifier:
         name: shell
         command: test/integration/my-suite/verify.sh
   ```

### Test Recipe Pattern

For complex recipes, create a simplified test version:

```ruby
# recipes/my_recipe_test.rb
# Simplified version for testing that avoids external dependencies

include_recipe 'axonops::_common'

# Create mock resources instead of real installations
file '/usr/bin/my-component' do
  content "#!/bin/bash\necho 'Test mode'\n"
  mode '0755'
end

# Create test configurations
file '/etc/axonops/my-component.yml' do
  content "test: true"
  owner 'axonops'
  group 'axonops'
  mode '0640'
end
```

## Continuous Integration

For CI/CD pipelines:

```bash
# Run linting
bundle exec cookstyle

# Run specific platform tests
bundle exec kitchen test agent-ubuntu-2204

# Run tests in parallel
bundle exec kitchen test -c 4

# Run tests matching pattern
bundle exec kitchen test "agent-ubuntu*"
```

## Troubleshooting

### Common Issues

1. **VM Won't Start**
   - Check VirtualBox is installed and running
   - Ensure virtualization is enabled in BIOS
   - Check for port conflicts (VirtualBox -> Preferences -> Network)

2. **Chef Run Fails**
   - Check `kitchen diagnose` output
   - Look at Chef logs: `kitchen login` then check `/tmp/kitchen/`
   - Verify attributes are set correctly

3. **Tests Fail**
   - SSH into VM: `kitchen login suite-platform`
   - Run verification manually: `bash /tmp/verifier/suites/serverspec/verify.sh`
   - Check component logs in `/var/log/`

### Debug Mode

Enable debug output:
```bash
export KITCHEN_LOG_LEVEL=debug
kitchen test agent-ubuntu-2204
```

## Performance Tips

1. **Keep VMs Running**: Use `kitchen converge` and `kitchen verify` instead of `kitchen test`
2. **Test Single Platform**: Focus on one platform during development
3. **Use Snapshots**: Some providers support VM snapshots for faster testing
4. **Concurrent Testing**: Use `-c` flag to run tests in parallel

## Best Practices

1. Always run tests before committing changes
2. Test on at least Ubuntu and one RHEL-based platform
3. Keep test recipes simple and focused
4. Use meaningful test descriptions in verify scripts
5. Clean up test VMs regularly with `kitchen destroy`