# AxonOps Chef Cookbook - Beginner's Guide

This guide is for users who are new to Chef and want to use the AxonOps cookbook to install and configure AxonOps monitoring for their Cassandra clusters.

## What is Chef?

Chef is an automation tool that helps you install and configure software on servers. Think of it like this:
- **Cookbook** = A collection of installation instructions (like a recipe book)
- **Recipe** = Specific installation steps (like a recipe for a dish)
- **Attributes** = Configuration settings (like ingredients and quantities)

## How Chef Works (Different from Ansible)

If you're coming from Ansible, here's the key difference:

- **Ansible**: You run commands from your laptop that connect to many servers (using an inventory file)
- **Chef Local Mode**: You log into each server and run Chef there (no inventory file needed)

In this guide, we use Chef's "local mode" which means:
1. You SSH into each server
2. You run Chef on that server
3. Chef configures that server only

For multiple servers, you simply repeat the process on each one.

## What Does This Cookbook Do?

The AxonOps cookbook automates the installation of:
1. **AxonOps Agent** - Software that monitors your Cassandra database
2. **AxonOps Server** - (Optional) Your own AxonOps monitoring server
3. **Apache Cassandra** - (Optional) The database itself if you need it

Most users only need the **Agent** to monitor their existing Cassandra clusters.

## Prerequisites

Before you start, you need:
1. A server (physical or virtual) running Ubuntu, Debian, or RHEL-based Linux
2. An AxonOps account (sign up at https://axonops.com)
3. Your Cassandra cluster that you want to monitor

## Important: How Chef Targets Servers

**Unlike Ansible, Chef doesn't have an inventory file.** Here's how it works:

- **With Ansible**: You run commands from your laptop and it connects to many servers
- **With Chef Local Mode**: You connect to each server and run Chef there

Think of it like this:
- Ansible = Remote control (you push changes from your laptop)
- Chef Local Mode = You visit each server (you run commands on each server)

**Example:**
```bash
# Ansible way (from your laptop):
ansible-playbook -i inventory install-axonops.yml  # Runs on all servers in inventory

# Chef way (on each server):
ssh server1.example.com
sudo chef-client --local-mode  # Runs on THIS server only
exit

ssh server2.example.com  
sudo chef-client --local-mode  # Runs on THIS server only
exit
```

**For multiple servers**, you simply repeat the installation on each one. There's no built-in "inventory" concept in Chef local mode.

## Step-by-Step Installation Guide

### Step 1: Install Chef on Your Server

**Important:** Run these commands ON THE SERVER where Cassandra is running, not on your laptop.

```bash
# First, SSH into your server
ssh your-server.example.com

# Then install Chef on that server
# For Ubuntu/Debian:
wget https://packages.chef.io/files/stable/chef/18.2.7/ubuntu/22.04/chef_18.2.7-1_amd64.deb
sudo dpkg -i chef_18.2.7-1_amd64.deb

# For RHEL/CentOS/AlmaLinux:
wget https://packages.chef.io/files/stable/chef/18.2.7/el/8/chef-18.2.7-1.el8.x86_64.rpm
sudo rpm -Uvh chef-18.2.7-1.el8.x86_64.rpm
```

Verify installation:
```bash
chef-client --version
```

### Step 2: Download the AxonOps Cookbook

```bash
# Create Chef directory structure
sudo mkdir -p /etc/chef/cookbooks

# Download the cookbook
cd /etc/chef/cookbooks
sudo git clone https://github.com/axonops/axonops-chef.git
sudo mv axonops-chef/axonops .
sudo rm -rf axonops-chef
```

### Step 3: Configure Your Settings

Create a configuration file that tells Chef what to install and how to configure it.

Create `/etc/chef/solo.rb`:
```bash
sudo nano /etc/chef/solo.rb
```

Add this content:
```ruby
cookbook_path "/etc/chef/cookbooks"
json_attribs "/etc/chef/node.json"
log_level :info
log_location STDOUT
```

### Step 4: Create Your Installation Settings

This is where you specify what to install and your AxonOps connection details.

Create `/etc/chef/node.json`:
```bash
sudo nano /etc/chef/node.json
```

For **Option A: Monitor Existing Cassandra** (Most Common):
```json
{
  "run_list": ["recipe[axonops::agent]"],
  "axonops": {
    "agent": {
      "org": "YOUR_ORGANIZATION_NAME",
      "org_key": "YOUR_ORGANIZATION_KEY",
      "cluster_name": "my-cassandra-cluster"
    }
  }
}
```

Replace:
- `YOUR_ORGANIZATION_NAME` - Found in your AxonOps dashboard under Settings → Organization
- `YOUR_ORGANIZATION_KEY` - Found in the same place (keep this secret!)
- `my-cassandra-cluster` - Any name you want to identify this cluster

For **Option B: Install Everything** (Cassandra + AxonOps):
```json
{
  "run_list": [
    "recipe[axonops::java]",
    "recipe[axonops::cassandra]", 
    "recipe[axonops::agent]"
  ],
  "axonops": {
    "agent": {
      "org": "YOUR_ORGANIZATION_NAME",
      "org_key": "YOUR_ORGANIZATION_KEY",
      "cluster_name": "my-new-cluster"
    },
    "cassandra": {
      "cluster_name": "my-new-cluster",
      "listen_address": "10.0.0.100",
      "rpc_address": "10.0.0.100",
      "seeds": "10.0.0.100"
    }
  }
}
```

### Step 5: Run the Installation

```bash
sudo chef-client --local-mode --config /etc/chef/solo.rb
```

This will:
1. Read your configuration
2. Install the AxonOps agent
3. Configure it to connect to AxonOps
4. Start monitoring your Cassandra cluster

### Step 6: Verify Installation

Check if the agent is running:
```bash
# Check service status
sudo systemctl status axon-agent

# Check agent logs
sudo tail -f /var/log/axonops/agent.log
```

You should see your cluster appear in the AxonOps dashboard within a few minutes.

### For Multiple Servers

If you have multiple Cassandra servers, repeat Steps 1-6 on each server:

```bash
# Server 1
ssh cassandra1.example.com
# ... run steps 1-6 ...
exit

# Server 2  
ssh cassandra2.example.com
# ... run steps 1-6 ...
exit

# Server 3
ssh cassandra3.example.com
# ... run steps 1-6 ...
exit
```

Each server gets the same configuration (same org, org_key, and cluster_name) so they all report to the same cluster in AxonOps.

## Common Configuration Changes

### Change Memory Settings for Cassandra

Edit your `/etc/chef/node.json`:
```json
{
  "axonops": {
    "cassandra": {
      "heap_size": "4G",
      "heap_new_size": "800M"
    }
  }
}
```

Then rerun Chef:
```bash
sudo chef-client --local-mode --config /etc/chef/solo.rb
```

### Use a Different Java Version

```json
{
  "axonops": {
    "java": {
      "version": "11",
      "vendor": "openjdk"
    }
  }
}
```

### Configure Agent Advanced Settings

```json
{
  "axonops": {
    "agent": {
      "ntp_timeout": 60,
      "backup_retention_days": 7,
      "metrics_interval": 30,
      "log_level": "debug"
    }
  }
}
```

## Troubleshooting

### "Connection refused" or "Cannot connect to AxonOps"

1. Check your organization name and key are correct
2. Ensure your server can reach the internet (for SaaS)
3. Check firewall rules - agent needs outbound HTTPS (port 443)

### "Cassandra not detected"

The agent automatically detects Cassandra. Make sure:
1. Cassandra is running: `sudo systemctl status cassandra`
2. Cassandra is using standard ports (9042, 7000)
3. The agent has permissions to read Cassandra config files

### "Package not found" errors

Make sure your system can access package repositories:
```bash
# Ubuntu/Debian
sudo apt-get update

# RHEL/CentOS
sudo yum makecache
```

### View All Available Settings

To see all configuration options:
```bash
# Look at the attributes files
cat /etc/chef/cookbooks/axonops/attributes/default.rb
cat /etc/chef/cookbooks/axonops/attributes/agent.rb
```

## Offline Installation

If your servers don't have internet access:

1. Download packages on a machine with internet:
```bash
cd /etc/chef/cookbooks/axonops
./scripts/download_offline_packages.py --all
```

2. Copy the `offline_packages` directory to your offline server

3. Add to your configuration:
```json
{
  "axonops": {
    "offline_install": true,
    "offline_package_dir": "/path/to/offline_packages"
  }
}
```

## Uninstalling

To remove AxonOps:
```bash
# Stop services
sudo systemctl stop axon-agent

# Remove packages
sudo apt-get remove axon-agent  # Debian/Ubuntu
sudo yum remove axon-agent       # RHEL/CentOS

# Remove configuration
sudo rm -rf /etc/axonops
sudo rm -rf /var/log/axonops
```

## Next Steps

1. **Set up alerts** - In the AxonOps dashboard, configure alerts for disk space, performance, etc.
2. **Configure backups** - Use the dashboard to set up automated Cassandra backups
3. **Explore metrics** - View real-time performance metrics in the dashboard

## Getting Help

- **AxonOps Documentation**: https://docs.axonops.com
- **AxonOps Support**: support@axonops.com
- **Chef Documentation**: https://docs.chef.io
- **This Cookbook's Issues**: https://github.com/axonops/axonops-chef/issues