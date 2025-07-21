# Test Kitchen Configuration Examples

This directory contains example Test Kitchen configurations for different testing scenarios. Copy and modify these files according to your needs.

## Available Examples

### 1. `.kitchen.minimal.yml` - Getting Started
The simplest configuration to test AxonOps agent installation:
- Single platform (Ubuntu 22.04)
- Minimal resource requirements
- Tests agent connection to AxonOps SaaS

**Use this when:**
- You're new to Test Kitchen
- You want to quickly test the agent installation
- You have limited system resources

**To use:**
```bash
cp examples/kitchen/.kitchen.minimal.yml .kitchen.yml
# Edit the org, org_key, and cluster_name
kitchen test agent
```

### 2. `.kitchen.docker.yml` - Fast Container Testing
Docker-based testing for faster iterations:
- Uses containers instead of VMs
- Much faster startup/teardown
- Good for CI/CD pipelines

**Use this when:**
- You need fast feedback during development
- You're running tests in CI/CD
- You don't need full systemd functionality

**To use:**
```bash
cp examples/kitchen/.kitchen.docker.yml .kitchen.yml
docker pull ubuntu:22.04  # Pre-pull images
kitchen test agent
```

### 3. `.kitchen.production-like.yml` - Realistic Testing
Production-like deployment scenarios:
- Multiple platforms (Ubuntu, AlmaLinux)
- Higher resource allocations
- Tests both SaaS and self-hosted deployments
- Uses environment variables for secrets

**Use this when:**
- You're preparing for production deployment
- You need to test on multiple platforms
- You want to test the full stack

**To use:**
```bash
cp examples/kitchen/.kitchen.production-like.yml .kitchen.yml
export AXONOPS_ORG_KEY="your-actual-key"
kitchen test existing-cassandra
```

### 4. `.kitchen.offline-testing.yml` - Airgapped Environments
Testing without internet access:
- Simulates offline/airgapped environments
- Uses local package directory
- Tests tarball installations

**Use this when:**
- Your production environment has no internet access
- You need to test offline installation procedures
- You're preparing deployment packages

**To use:**
```bash
# First download packages
./scripts/download_offline_packages.py --all
# Then test
cp examples/kitchen/.kitchen.offline-testing.yml .kitchen.yml
kitchen test offline-agent
```

### 5. `.kitchen.apple-silicon.yml` - Apple M1/M2/M3 Development
Special configuration for ARM64 development machines:
- Handles architecture mismatches
- Uses ARM64-compatible boxes
- Tests cross-architecture installations

**Use this when:**
- You're developing on Apple Silicon
- You need to test x86_64 packages on ARM64
- You want to use native ARM64 packages

**To use:**
```bash
cp examples/kitchen/.kitchen.apple-silicon.yml .kitchen.yml
kitchen test agent-arm64
```

## Customizing Configurations

### Common Modifications

1. **Change VM Resources:**
```yaml
customize:
  memory: 4096  # MB
  cpus: 4
```

2. **Add More Platforms:**
```yaml
platforms:
  - name: debian-11
    driver:
      box: bento/debian-11
  - name: rocky-9
    driver:
      box: bento/rockylinux-9
```

3. **Use Environment Variables:**
```yaml
attributes:
  axonops:
    agent:
      org_key: "<%= ENV['AXONOPS_ORG_KEY'] %>"
```

4. **Add Custom Recipes:**
```yaml
run_list:
  - recipe[my_cookbook::prepare]
  - recipe[axonops::agent]
  - recipe[my_cookbook::validate]
```

### Network Configuration

For multi-node testing, configure static IPs:
```yaml
driver:
  network:
    - ["private_network", {ip: "192.168.33.10"}]
```

### Synced Folders

Mount local directories into VMs:
```yaml
synced_folders:
  - ["./data", "/opt/data", "type: 'virtualbox'"]
```

## Tips and Best Practices

1. **Start Simple**: Begin with `.kitchen.minimal.yml` and add complexity as needed

2. **Use .kitchen.local.yml**: Create a `.kitchen.local.yml` for personal overrides:
   ```bash
   cp examples/kitchen/.kitchen.minimal.yml .kitchen.local.yml
   # .kitchen.local.yml is gitignored
   ```

3. **Resource Management**: Destroy VMs when not in use:
   ```bash
   kitchen destroy all
   ```

4. **Debugging**: Keep VMs running for investigation:
   ```bash
   kitchen test --no-destroy
   kitchen login suite-name
   ```

5. **Platform Selection**: Test on your target production platform:
   ```bash
   kitchen test agent-ubuntu-2204  # Specific platform
   ```

## Troubleshooting

### "No provider available"
Install VirtualBox or configure Docker:
```bash
brew install --cask virtualbox
# or
brew install docker
```

### "Architecture mismatch"
Use the Apple Silicon configuration or force architecture:
```yaml
attributes:
  axonops:
    force_architecture: true
```

### "Network timeout"
Increase timeouts or check proxy settings:
```yaml
driver:
  vm_hostname: false
  boot_timeout: 600
```

## Further Reading

- [Test Kitchen Documentation](https://kitchen.ci/)
- [Main Testing Guide](../../TESTING.md)
- [Kitchen Quick Start](../../docs/KITCHEN_QUICKSTART.md)