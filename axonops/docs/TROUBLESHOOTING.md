# Troubleshooting Guide

This guide helps you fix common problems when using the AxonOps Chef cookbook.

## Quick Diagnosis

Run this command to check everything:

```bash
# Check if services are running
sudo systemctl status axon-agent
sudo systemctl status cassandra

# Check recent logs
sudo journalctl -u axon-agent -n 50 --no-pager
```

## Common Problems and Solutions

### 1. "Connection refused" or "Cannot connect to AxonOps"

**Symptoms:**
- Agent log shows "connection refused" or "timeout"
- Cluster doesn't appear in AxonOps dashboard

**Solutions:**

1. **Check your credentials:**
   ```bash
   # View your current configuration
   cat /etc/chef/node.json
   ```
   Make sure `org` and `org_key` match exactly what's in your AxonOps dashboard.

2. **Check internet connectivity:**
   ```bash
   # Test connection to AxonOps
   curl -I https://agents.axonops.cloud
   ```
   If this fails, check your firewall or proxy settings.

3. **Check the agent log for specific errors:**
   ```bash
   sudo tail -f /var/log/axonops/agent.log
   ```

### 2. "Package not found" During Installation

**Symptoms:**
- Chef fails with "Package axon-agent not found"
- APT/YUM can't find packages

**Solutions:**

1. **Update package lists:**
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   
   # RHEL/CentOS
   sudo yum makecache
   ```

2. **Check AxonOps repository is added:**
   ```bash
   # Ubuntu/Debian
   ls /etc/apt/sources.list.d/axonops*
   
   # RHEL/CentOS
   ls /etc/yum.repos.d/axonops*
   ```

3. **Use offline installation:**
   See the [Offline Installation](#offline-installation-issues) section below.

### 3. "Cassandra not detected"

**Symptoms:**
- Agent is running but shows no Cassandra metrics
- Dashboard shows agent as "connected" but no data

**Solutions:**

1. **Verify Cassandra is running:**
   ```bash
   # Check if Cassandra process exists
   ps aux | grep cassandra
   
   # Check Cassandra service
   sudo systemctl status cassandra
   
   # Try to connect with cqlsh
   cqlsh localhost
   ```

2. **Check Cassandra paths:**
   ```bash
   # The agent looks for Cassandra in standard locations:
   ls -la /etc/cassandra/cassandra.yaml
   ls -la /opt/cassandra/conf/cassandra.yaml
   ```

3. **Check agent can read Cassandra config:**
   ```bash
   # Check permissions
   ls -la /etc/cassandra/
   
   # Agent runs as 'axonops' user, ensure it can read files
   sudo -u axonops cat /etc/cassandra/cassandra.yaml > /dev/null
   ```

### 4. "Permission denied" Errors

**Symptoms:**
- Chef fails with permission errors
- Services won't start due to permissions

**Solutions:**

1. **Run Chef with sudo:**
   ```bash
   sudo chef-client --local-mode --config /etc/chef/solo.rb
   ```

2. **Fix ownership issues:**
   ```bash
   # Fix AxonOps directories
   sudo chown -R axonops:axonops /etc/axonops
   sudo chown -R axonops:axonops /var/log/axonops
   
   # Fix Cassandra directories (if installed by cookbook)
   sudo chown -R cassandra:cassandra /var/lib/cassandra
   sudo chown -R cassandra:cassandra /var/log/cassandra
   ```

### 5. Chef Run Fails

**Symptoms:**
- Chef stops with an error
- Red error messages during cookbook run

**Solutions:**

1. **Check your JSON syntax:**
   ```bash
   # Validate JSON file
   python -m json.tool /etc/chef/node.json
   ```
   Common mistakes:
   - Missing commas between items
   - Extra comma after last item
   - Missing quotes around strings

2. **Run Chef in debug mode:**
   ```bash
   sudo chef-client --local-mode --config /etc/chef/solo.rb -l debug
   ```

3. **Check Chef logs:**
   ```bash
   # Look for detailed error messages
   sudo tail -n 100 /var/chef/cache/chef-stacktrace.out
   ```

### 6. "Architecture mismatch" on Apple Silicon

**Symptoms:**
- Package installation fails with "wrong architecture"
- Running on M1/M2/M3 Mac with ARM64

**Solution:**
The cookbook handles this automatically, but if you still have issues:

```json
{
  "axonops": {
    "force_architecture": true
  }
}
```

### 7. Offline Installation Issues

**Symptoms:**
- No internet access on servers
- Installation fails due to network timeouts

**Solution:**

1. **Download packages on a machine with internet:**
   ```bash
   cd /etc/chef/cookbooks/axonops
   ./scripts/download_offline_packages.py --all
   ```

2. **Copy to offline server and configure:**
   ```json
   {
     "axonops": {
       "offline_install": true,
       "offline_package_dir": "/path/to/offline_packages"
     }
   }
   ```

## Getting More Help

### Collect Diagnostic Information

Run this script to collect all relevant information:

```bash
# Create diagnostic report
mkdir -p /tmp/axonops-diag
cd /tmp/axonops-diag

# Collect system info
uname -a > system.txt
cat /etc/os-release >> system.txt

# Collect Chef info
chef-client --version > chef.txt
cp /etc/chef/node.json .
chef-client --local-mode --why-run --config /etc/chef/solo.rb > chef-dryrun.txt 2>&1

# Collect service status
systemctl status axon-agent > agent-status.txt 2>&1
systemctl status cassandra > cassandra-status.txt 2>&1

# Collect logs (last 200 lines)
sudo tail -n 200 /var/log/axonops/agent.log > agent.log 2>&1
sudo journalctl -u axon-agent -n 200 --no-pager > agent-journal.log 2>&1

# Package info
dpkg -l | grep axon > packages-dpkg.txt 2>&1
rpm -qa | grep axon > packages-rpm.txt 2>&1

# Create archive
tar -czf /tmp/axonops-diagnostic.tar.gz *
echo "Diagnostic file created: /tmp/axonops-diagnostic.tar.gz"
```

### Where to Get Help

1. **Check the documentation:**
   - [Beginner's Guide](BEGINNER_GUIDE.md)
   - [Configuration Guide](CONFIGURATION_GUIDE.md)
   - [AxonOps Documentation](https://docs.axonops.com)

2. **Contact support:**
   - Email: support@axonops.com
   - Include the diagnostic file if possible

3. **Report cookbook issues:**
   - GitHub: https://github.com/axonops/axonops-chef/issues

## Prevention Tips

1. **Always test in non-production first**
2. **Keep your credentials secure** - never commit them to git
3. **Use version pinning** for production:
   ```json
   {
     "axonops": {
       "agent": {
         "version": "1.0.50"
       }
     }
   }
   ```
4. **Monitor the agent logs** after installation:
   ```bash
   sudo tail -f /var/log/axonops/agent.log
   ```