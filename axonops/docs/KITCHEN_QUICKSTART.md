# Testing Quick Start Guide

This is a quick reference for testing the AxonOps Chef cookbook with Test Kitchen.

## Prerequisites Check

```bash
# Make sure you have these installed:
kitchen version      # Should show Test Kitchen version
vagrant --version    # Should show Vagrant version
VBoxManage --version # Should show VirtualBox version
```

## Most Common Test Commands

### 1. Test the Agent Installation (Fastest Test)
```bash
# This tests installing AxonOps agent on a node
kitchen test agent-ubuntu-2204
```

### 2. Test Full Stack Installation
```bash
# This tests server + dashboard + agent + Cassandra
kitchen test full-stack-ubuntu-2204
```

### 3. Test with Real AxonOps Packages
```bash
# This uses actual AxonOps binaries (not mocks)
KITCHEN_YAML=.kitchen.real-packages.yml kitchen test
```

### 4. Test Multi-Node Deployment
```bash
# This creates 2 VMs: AxonOps server and Cassandra app
KITCHEN_YAML=.kitchen.multi-node.yml kitchen create
KITCHEN_YAML=.kitchen.multi-node.yml kitchen converge
KITCHEN_YAML=.kitchen.multi-node.yml kitchen verify
```

## Quick Debugging

If a test fails and you want to investigate:

```bash
# Run test but keep the VM alive
kitchen test agent-ubuntu-2204 --no-destroy

# SSH into the VM
kitchen login agent-ubuntu-2204

# Inside the VM, check:
sudo systemctl status axon-agent          # Is service running?
sudo journalctl -u axon-agent            # Check logs
dpkg -l | grep axon                      # What's installed?
ls -la /etc/axonops/                     # Check config files
sudo cat /etc/axonops/axon-agent.yml    # View configuration

# When done, clean up
exit  # Leave VM
kitchen destroy agent-ubuntu-2204
```

## Test Status Check

```bash
# See what VMs are running
kitchen list

# Example output:
# Instance                      Driver   Provisioner  Verifier  Transport  Last Action  Last Error
# agent-ubuntu-2204             Vagrant  ChefZero     Inspec    Ssh        Verified     None
# server-ubuntu-2204            Vagrant  ChefZero     Inspec    Ssh        Created      None
```

## Clean Up Everything

```bash
# Destroy all test VMs
kitchen destroy all

# If VMs are stuck, force cleanup:
VBoxManage list runningvms | grep kitchen
for vm in $(VBoxManage list vms | grep kitchen | cut -d'"' -f2); do 
  VBoxManage unregistervm "$vm" --delete
done
rm -rf .kitchen
```

## Test Specific Scenarios

### Test Offline Installation
```bash
# First download packages (one-time)
cd scripts
./download_offline_packages.py --all
cd ..

# Then test offline installation
KITCHEN_YAML=.kitchen.offline.yml kitchen test
```

### Test Different Ubuntu Versions
```bash
kitchen test agent-ubuntu-2004  # Ubuntu 20.04
kitchen test agent-ubuntu-2204  # Ubuntu 22.04
kitchen test agent-ubuntu-2404  # Ubuntu 24.04
```

### Test Just One Part (Faster Development)
```bash
# Create VM once
kitchen create agent-ubuntu-2204

# Make code changes, then re-run Chef (fast!)
kitchen converge agent-ubuntu-2204

# Check if it worked
kitchen verify agent-ubuntu-2204

# Make more changes and re-run
kitchen converge agent-ubuntu-2204

# When done, destroy
kitchen destroy agent-ubuntu-2204
```

## What Each Test Configuration Does

| Config File | What It Tests | How Long | Use When |
|-------------|---------------|----------|----------|
| `.kitchen.yml` (default) | Basic recipes with mock services | ~2 min | Development |
| `.kitchen.multi-node.yml` | Server + Agent communication | ~5 min | Testing distributed setup |
| `.kitchen.real-packages.yml` | Real AxonOps packages | ~3 min | Final validation |
| `.kitchen.offline.yml` | No internet installation | ~4 min | Airgapped testing |

## Common Issues

### "No such file or directory - bin/vagrant-wrapper"
```bash
rm -rf .kitchen
kitchen create  # Try again
```

### "VirtualBox VM won't start"
```bash
# Restart VirtualBox
sudo killall -9 VBoxHeadless
kitchen destroy all
kitchen create
```

### "Package architecture (amd64) does not match system (arm64)"
This is normal on Apple Silicon Macs. The cookbook handles it with `--force-architecture`.

## Pro Tips

1. **Use specific suite names** to test faster:
   ```bash
   kitchen test agent  # Just test agent, not everything
   ```

2. **Keep VMs running** during development:
   ```bash
   kitchen converge  # Update without destroying
   ```

3. **Use parallel testing** for speed:
   ```bash
   kitchen test -c 2  # Run 2 tests at once
   ```

4. **Check VM resources**:
   ```bash
   VBoxManage list runningvms  # What's running
   df -h                       # Disk space
   ```

## Need More Details?

See the full [Kitchen Testing Guide](docs/KITCHEN_TESTING_GUIDE.md) for comprehensive documentation.