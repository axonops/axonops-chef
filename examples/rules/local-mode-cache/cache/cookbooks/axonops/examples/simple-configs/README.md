# Simple Configuration Examples

This directory contains ready-to-use configuration files. Just copy, edit, and run!

## Quick Start (3 Steps)

### Step 1: Copy the files you need

```bash
# Copy Chef configuration
sudo cp solo.rb /etc/chef/solo.rb

# Copy the configuration that matches your needs:

# Option A: Monitor existing Cassandra
sudo cp monitor-existing-cassandra.json /etc/chef/node.json

# OR Option B: Install Cassandra + Monitoring
sudo cp install-everything.json /etc/chef/node.json
```

### Step 2: Edit the configuration

Edit `/etc/chef/node.json` and replace:
- `REPLACE_WITH_YOUR_ORG_NAME` → Your organization name from AxonOps dashboard
- `REPLACE_WITH_YOUR_ORG_KEY` → Your organization key from AxonOps dashboard  
- `REPLACE_WITH_YOUR_SERVER_IP` → Your server's IP address (like 10.0.0.100)

### Step 3: Run Chef

```bash
sudo chef-client --local-mode --config /etc/chef/solo.rb
```

## What's in This Directory?

| File | Purpose | When to Use |
|------|---------|-------------|
| `solo.rb` | Chef configuration | Always needed |
| `monitor-existing-cassandra.json` | Install monitoring agent only | You already have Cassandra |
| `install-everything.json` | Install Cassandra + monitoring | You need a new Cassandra |
| `install-agent.sh` | Complete installation script | Want a one-command install |

## Complete Installation Script

For the easiest installation, use the provided script:

```bash
# Make it executable
chmod +x install-agent.sh

# Run it with your AxonOps credentials
./install-agent.sh YOUR_ORG_NAME YOUR_ORG_KEY my-cluster-name
```

## Common Customizations

### Change Cassandra Memory (Heap Size)

In your `node.json`, modify:
```json
"cassandra": {
  "heap_size": "8G"  // Change from 4G to 8G
}
```

### Use Multiple Seed Nodes

```json
"cassandra": {
  "seeds": "10.0.0.1,10.0.0.2,10.0.0.3"
}
```

### Enable Debug Logging

```json
"agent": {
  "log_level": "debug"
}
```

## Troubleshooting

If something goes wrong:

1. Check Chef output for errors
2. Look at logs:
   ```bash
   # Agent logs
   sudo tail -f /var/log/axonops/agent.log
   
   # Cassandra logs  
   sudo tail -f /var/log/cassandra/system.log
   ```
3. Verify services are running:
   ```bash
   sudo systemctl status axon-agent
   sudo systemctl status cassandra
   ```

## Need Help?

- See the [Beginner's Guide](../../docs/BEGINNER_GUIDE.md) for detailed explanations
- Check the [Configuration Guide](../../docs/CONFIGURATION_GUIDE.md) for more examples
- Visit [AxonOps Documentation](https://docs.axonops.com)