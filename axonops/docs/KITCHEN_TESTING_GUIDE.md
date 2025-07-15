# Test Kitchen Guide for AxonOps Cookbook

This guide explains how to use Test Kitchen to test the AxonOps Chef cookbook. Test Kitchen is a tool that creates virtual machines, runs Chef recipes on them, and verifies the results.

## Table of Contents

1. [What is Test Kitchen?](#what-is-test-kitchen)
2. [Prerequisites](#prerequisites)
3. [Kitchen Configuration Files](#kitchen-configuration-files)
4. [Basic Kitchen Commands](#basic-kitchen-commands)
5. [Running Tests](#running-tests)
6. [Understanding Test Output](#understanding-test-output)
7. [Common Testing Scenarios](#common-testing-scenarios)
8. [Troubleshooting](#troubleshooting)

---

## What is Test Kitchen?

Test Kitchen is an integration testing framework that:
- Creates isolated test environments (VMs or containers)
- Installs Chef and runs your recipes
- Verifies the results using InSpec or other testing frameworks
- Cleans up after testing

Think of it as "automated QA for your Chef cookbooks."

---

## Prerequisites

### Required Software

1. **VirtualBox** - For creating test VMs
   ```bash
   # macOS
   brew install --cask virtualbox
   
   # Ubuntu/Debian
   sudo apt-get install virtualbox
   ```

2. **Vagrant** - VM automation tool
   ```bash
   # macOS
   brew install --cask vagrant
   
   # Download from: https://www.vagrantup.com/downloads
   ```

3. **ChefDK/Chef Workstation** - Includes Test Kitchen
   ```bash
   # macOS
   brew install --cask chef-workstation
   
   # Or download from: https://downloads.chef.io/chef-workstation
   ```

### Verify Installation

```bash
# Check all tools are installed
kitchen version
vagrant --version
VBoxManage --version
```

---

## Kitchen Configuration Files

The cookbook includes several `.kitchen.yml` files for different test scenarios:

### Main Configuration Files

| File | Purpose | Use Case |
|------|---------|----------|
| `.kitchen.yml` | Default configuration | Standard single-node tests |
| `.kitchen.multi-node.yml` | Multi-node testing | Tests distributed deployments |
| `.kitchen.offline.yml` | Offline installation | Tests without internet access |
| `.kitchen.real-packages.yml` | Real package testing | Tests with actual AxonOps binaries |
| `.kitchen.simple-test.yml` | Minimal testing | Quick smoke tests |

### Understanding .kitchen.yml Structure

```yaml
---
# Driver: What virtualization to use
driver:
  name: vagrant                    # Use Vagrant (with VirtualBox)
  network:
    - ["private_network", {ip: "192.168.56.10"}]  # Static IP

# Provisioner: How to run Chef
provisioner:
  name: chef_zero                  # Use Chef Zero (in-memory Chef server)
  product_name: chef
  chef_license: accept

# Verifier: How to test results
verifier:
  name: inspec                     # Use InSpec for verification

# Platforms: What OS to test on
platforms:
  - name: ubuntu-22.04
    driver:
      box: bento/ubuntu-22.04      # Vagrant box to use

# Suites: What recipes to test
suites:
  - name: default
    run_list:
      - recipe[axonops::default]   # Recipe to run
    attributes:                    # Chef attributes to set
      axonops:
        agent:
          enabled: true
```

---

## Basic Kitchen Commands

### Essential Commands

| Command | What it does | When to use |
|---------|--------------|-------------|
| `kitchen list` | Shows all test instances | Check test status |
| `kitchen create` | Creates VMs | Set up test environment |
| `kitchen converge` | Runs Chef recipes | Apply configurations |
| `kitchen verify` | Runs tests | Verify results |
| `kitchen destroy` | Deletes VMs | Clean up |
| `kitchen test` | Full test cycle | Complete testing |

### Command Examples

```bash
# List all test suites and their status
kitchen list

# Test everything (create, converge, verify, destroy)
kitchen test

# Test a specific suite
kitchen test agent-ubuntu-2204

# Just run Chef without creating/destroying
kitchen converge agent-ubuntu-2204

# Run verification tests only
kitchen verify agent-ubuntu-2204

# SSH into a test VM
kitchen login agent-ubuntu-2204

# Clean up all VMs
kitchen destroy all
```

---

## Running Tests

### 1. Default Test (Single Node)

Tests basic cookbook functionality:

```bash
# Run all default tests
kitchen test

# Or test specific OS
kitchen test default-ubuntu-2204
```

### 2. Agent Installation Test

Tests AxonOps agent installation on existing Cassandra:

```bash
# Test agent installation
kitchen test agent-ubuntu-2204

# Check what happened
kitchen list
```

### 3. Multi-Node Test

Tests distributed deployment (server + application nodes):

```bash
# Use multi-node configuration
KITCHEN_YAML=.kitchen.multi-node.yml kitchen test

# Create both VMs
KITCHEN_YAML=.kitchen.multi-node.yml kitchen create

# Converge server first, then app
KITCHEN_YAML=.kitchen.multi-node.yml kitchen converge axonops-server
KITCHEN_YAML=.kitchen.multi-node.yml kitchen converge cassandra-app

# Verify both nodes
KITCHEN_YAML=.kitchen.multi-node.yml kitchen verify
```

### 4. Offline Installation Test

Tests installation without internet:

```bash
# First, download packages
cd scripts
./download_offline_packages.py --all

# Run offline test
KITCHEN_YAML=.kitchen.offline.yml kitchen test
```

### 5. Real Package Test

Tests with actual AxonOps binaries:

```bash
# Ensure packages are in offline_packages/
ls offline_packages/

# Run test with real packages
KITCHEN_YAML=.kitchen.real-packages.yml kitchen test
```

---

## Understanding Test Output

### Successful Test Output

```
-----> Starting Test Kitchen
-----> Creating <agent-ubuntu-2204>...
       Bringing machine 'default' up with 'virtualbox' provider...
       ==> default: Machine booted and ready!
-----> Converging <agent-ubuntu-2204>...
       Chef Infra Client, version 18.7.10
       Converging 25 resources
       Recipe: axonops::agent
         * package[axon-agent] action install
           - install version 1.0.50 of package axon-agent
       Running handlers complete
       Infra Phase complete, 25/25 resources updated
-----> Verifying <agent-ubuntu-2204>...
       ✓ Agent service should be installed
       ✓ Configuration file should exist
-----> Destroying <agent-ubuntu-2204>...
       Finished testing <agent-ubuntu-2204> (2m15.3s)
```

### Failed Test Output

```
>>>>>> ------Exception-------
>>>>>> Class: Kitchen::ActionFailed
>>>>>> Message: 1 actions failed.
>>>>>>     Converge failed on instance <agent-ubuntu-2204>
>>>>>> ----------------------
```

### Reading Chef Logs

During converge, you'll see:
- Resources being created/updated
- File content changes
- Service status changes
- Any errors or warnings

---

## Common Testing Scenarios

### Test Specific Recipes

```bash
# Test just the agent recipe
kitchen test agent

# Test just the server components
kitchen test server

# Test full stack deployment
kitchen test full-stack
```

### Test on Different Platforms

```bash
# List available platforms
kitchen list

# Test on Ubuntu 20.04
kitchen test default-ubuntu-2004

# Test on Ubuntu 22.04
kitchen test default-ubuntu-2204
```

### Iterative Development

```bash
# Create VM once
kitchen create agent-ubuntu-2204

# Make changes and re-run Chef (fast)
kitchen converge agent-ubuntu-2204

# Check results
kitchen login agent-ubuntu-2204
sudo systemctl status axon-agent
cat /etc/axonops/axon-agent.yml

# Run tests
kitchen verify agent-ubuntu-2204

# Clean up when done
kitchen destroy agent-ubuntu-2204
```

### Debugging Failed Tests

```bash
# Keep VM running after failure
kitchen test agent-ubuntu-2204 --no-destroy

# Login to investigate
kitchen login agent-ubuntu-2204

# Check Chef logs
sudo cat /tmp/kitchen/cache/chef-stacktrace.out
sudo journalctl -u axon-agent

# Check installed packages
dpkg -l | grep axon

# When done debugging
kitchen destroy agent-ubuntu-2204
```

---

## Test Kitchen Tips & Tricks

### 1. Speed Up Testing

```bash
# Don't destroy VMs between runs
kitchen converge  # Instead of kitchen test

# Test specific suites
kitchen test agent  # Instead of testing all
```

### 2. Using Custom Kitchen Files

```bash
# Set environment variable
export KITCHEN_YAML=.kitchen.multi-node.yml
kitchen list

# Or specify inline
KITCHEN_YAML=.kitchen.offline.yml kitchen test
```

### 3. Parallel Testing

```bash
# Test multiple suites in parallel
kitchen test -c 3  # Run 3 tests concurrently
```

### 4. Check VM Resources

```bash
# See what's running
VBoxManage list runningvms

# Check VM details
kitchen diagnose agent-ubuntu-2204
```

### 5. Clean Up Stuck VMs

```bash
# Force destroy all Kitchen VMs
kitchen destroy all -c

# Or manually with VirtualBox
VBoxManage list vms | grep kitchen
VBoxManage unregistervm <VM-ID> --delete
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. "No such file or directory - bin/vagrant-wrapper"
```bash
# Solution: Clean Kitchen state
rm -rf .kitchen
kitchen create
```

#### 2. "VirtualBox VM won't start"
```bash
# Solution: Check VirtualBox
VBoxManage list runningvms
VBoxManage list vms

# Force cleanup
kitchen destroy all
rm -rf .kitchen
```

#### 3. "Package architecture (amd64) does not match system (arm64)"
```bash
# This is expected on Apple Silicon Macs
# The cookbook handles this with dpkg --force-architecture
```

#### 4. "SSH connection timeout"
```bash
# Solution: Increase timeout
export KITCHEN_SSH_TIMEOUT=60
kitchen create
```

#### 5. "Chef converge fails"
```bash
# Get more details
kitchen converge -l debug

# Check logs
kitchen login
sudo cat /tmp/kitchen/cache/chef-stacktrace.out
```

---

## InSpec Tests

The cookbook includes InSpec tests in `test/integration/`. Here's what they check:

### Agent Tests (`test/integration/agent/`)
- Agent package installed
- Configuration files exist
- Service is enabled
- Correct file permissions

### Server Tests (`test/integration/server/`)
- Server components installed
- API endpoint responding
- Elasticsearch running
- Correct ports open

### Running Individual InSpec Tests

```bash
# Run InSpec directly
kitchen verify agent-ubuntu-2204

# Or login and run manually
kitchen login agent-ubuntu-2204
cd /tmp/kitchen
inspec exec test/integration/agent -t ssh://localhost
```

---

## Writing Your Own Tests

### Add New Test Suite

1. Edit `.kitchen.yml`:
```yaml
suites:
  - name: my-test
    run_list:
      - recipe[axonops::my_recipe]
    attributes:
      axonops:
        my_setting: true
```

2. Create InSpec test:
```ruby
# test/integration/my-test/my_test_spec.rb
describe package('my-package') do
  it { should be_installed }
end
```

3. Run test:
```bash
kitchen test my-test
```

---

## Best Practices

1. **Start Simple**: Use `kitchen test agent` for quick tests
2. **Keep VMs Small**: Destroy VMs when not needed
3. **Use Specific Suites**: Test only what you're working on
4. **Check Status**: Run `kitchen list` frequently
5. **Clean Up**: Run `kitchen destroy all` when done

---

## Quick Reference Card

```bash
# Most common commands
kitchen list                    # What's running?
kitchen test agent             # Test agent recipe
kitchen converge agent         # Re-run Chef
kitchen login agent            # Debug VM
kitchen destroy all            # Clean up

# Multi-node testing
KITCHEN_YAML=.kitchen.multi-node.yml kitchen create
KITCHEN_YAML=.kitchen.multi-node.yml kitchen converge

# Real package testing
KITCHEN_YAML=.kitchen.real-packages.yml kitchen test

# Debug mode
kitchen converge -l debug      # Verbose output
kitchen test --no-destroy      # Keep VM for debugging
```