# Configuration Guide - Simple Reference

This guide shows you how to configure the AxonOps cookbook for common scenarios. Each example shows the complete configuration file you need.

## How to Use This Guide

1. Find the scenario that matches your needs
2. Copy the configuration example
3. Replace the placeholder values (like YOUR_ORG_NAME)
4. Save as `/etc/chef/node.json`
5. Run: `sudo chef-client --local-mode --config /etc/chef/solo.rb`

## Quick Reference - What Each Setting Does

| Setting | What It Does | Example Value |
|---------|--------------|---------------|
| `org` | Your AxonOps organization name | `"my-company"` |
| `org_key` | Secret key from AxonOps dashboard | `"abc123xyz789"` |
| `cluster_name` | Name to identify this Cassandra cluster | `"production-cluster"` |
| `axon_server` | AxonOps server address | `"agents.axonops.cloud"` (default) |
| `axon_port` | AxonOps server port | `443` (default) |

## Configuration Examples

### 1. Basic Agent Installation (Most Common)

**Use this when:** You have Cassandra already running and just want to monitor it.

```json
{
  "run_list": ["recipe[axonops::agent]"],
  "axonops": {
    "agent": {
      "org": "my-company",
      "org_key": "get-this-from-axonops-dashboard",
      "cluster_name": "production"
    }
  }
}
```

### 2. Agent with Custom Settings

**Use this when:** You need to adjust monitoring intervals or logging.

```json
{
  "run_list": ["recipe[axonops::agent]"],
  "axonops": {
    "agent": {
      "org": "my-company",
      "org_key": "your-secret-key",
      "cluster_name": "production",
      "metrics_interval": 60,
      "log_level": "info",
      "backup_retention_days": 14,
      "ntp_timeout": 30
    }
  }
}
```

**Settings explained:**
- `metrics_interval`: How often to collect metrics (seconds)
- `log_level`: How detailed logs should be (debug/info/warn/error)
- `backup_retention_days`: How long to keep backup metadata
- `ntp_timeout`: Time sync check timeout (seconds)

### 3. Install Cassandra + Agent

**Use this when:** You need to install Cassandra from scratch with monitoring.

```json
{
  "run_list": [
    "recipe[axonops::java]",
    "recipe[axonops::cassandra]",
    "recipe[axonops::agent]"
  ],
  "axonops": {
    "agent": {
      "org": "my-company",
      "org_key": "your-secret-key",
      "cluster_name": "new-cluster"
    },
    "cassandra": {
      "version": "5.0.4",
      "cluster_name": "new-cluster",
      "listen_address": "10.0.1.10",
      "rpc_address": "10.0.1.10",
      "seeds": "10.0.1.10,10.0.1.11,10.0.1.12",
      "heap_size": "8G"
    }
  }
}
```

**Cassandra settings explained:**
- `version`: Which Cassandra version to install
- `listen_address`: IP address Cassandra listens on (use server's IP)
- `rpc_address`: IP address for client connections (usually same as listen_address)
- `seeds`: Comma-separated list of seed nodes (at least one, usually 3)
- `heap_size`: Memory allocation for Cassandra

### 4. Multi-DC Cassandra Setup

**Use this when:** You have multiple data centers.

```json
{
  "run_list": [
    "recipe[axonops::cassandra]",
    "recipe[axonops::agent]"
  ],
  "axonops": {
    "agent": {
      "org": "my-company",
      "org_key": "your-secret-key",
      "cluster_name": "global-cluster"
    },
    "cassandra": {
      "cluster_name": "global-cluster",
      "listen_address": "10.0.1.10",
      "rpc_address": "10.0.1.10",
      "seeds": "10.0.1.10,10.0.2.10",
      "endpoint_snitch": "GossipingPropertyFileSnitch",
      "dc": "dc1",
      "rack": "rack1"
    }
  }
}
```

### 5. Self-Hosted AxonOps Server

**Use this when:** You want to run your own AxonOps server (not use SaaS).

```json
{
  "run_list": [
    "recipe[axonops::java]",
    "recipe[axonops::elasticsearch]",
    "recipe[axonops::server]",
    "recipe[axonops::dashboard]"
  ],
  "axonops": {
    "server": {
      "install": true,
      "heap_size": "2G"
    },
    "dashboard": {
      "port": 3000
    },
    "elasticsearch": {
      "heap_size": "2G",
      "cluster_name": "axonops-metrics"
    }
  }
}
```

Then on your Cassandra nodes, point the agent to your server:

```json
{
  "run_list": ["recipe[axonops::agent]"],
  "axonops": {
    "agent": {
      "axon_server": "10.0.1.50",
      "axon_port": 8080,
      "org": "internal",
      "org_key": "your-internal-key",
      "cluster_name": "production"
    }
  }
}
```

### 6. Offline/Airgapped Installation

**Use this when:** Your servers have no internet access.

First, download packages on a machine with internet:
```bash
./scripts/download_offline_packages.py --all
```

Then use this configuration:

```json
{
  "run_list": ["recipe[axonops::agent]"],
  "axonops": {
    "offline_install": true,
    "offline_package_dir": "/path/to/offline_packages",
    "agent": {
      "org": "my-company",
      "org_key": "your-secret-key",
      "cluster_name": "offline-cluster"
    }
  }
}
```

### 7. Different Java Versions

**Use this when:** You need a specific Java version.

```json
{
  "run_list": [
    "recipe[axonops::java]",
    "recipe[axonops::cassandra]"
  ],
  "axonops": {
    "java": {
      "version": "17",
      "vendor": "azul-zulu"
    },
    "cassandra": {
      "version": "5.0.4"
    }
  }
}
```

**Java options:**
- Versions: 8, 11, 17, 21
- Vendors: azul-zulu, openjdk, corretto

## How to Apply Configuration Changes

1. Edit your `/etc/chef/node.json` file
2. Run Chef again:
   ```bash
   sudo chef-client --local-mode --config /etc/chef/solo.rb
   ```
3. Chef will apply only the changes needed

## Checking Current Configuration

To see what's currently configured:

```bash
# Check agent configuration
cat /etc/axonops/axon-agent.yml

# Check Cassandra configuration
cat /etc/cassandra/cassandra.yaml

# Check what Chef last applied
cat /var/chef/cache/chef-client-running.json
```

## Common Mistakes to Avoid

1. **Wrong IP addresses**: Use your server's actual IP, not localhost or 127.0.0.1
2. **Missing quotes**: JSON requires quotes around all strings
3. **Extra commas**: Don't put a comma after the last item in a list
4. **Wrong org key**: Copy the exact key from AxonOps dashboard
5. **Firewall blocks**: Ensure ports are open (9042 for Cassandra, 443 for AxonOps)

## Getting Your Organization Details

1. Log into AxonOps: https://dashboard.axonops.com
2. Click on Settings → Organization
3. Copy your:
   - Organization Name (goes in `org`)
   - Organization Key (goes in `org_key`)

## Need Help?

If something isn't working:
1. Check the agent logs: `sudo tail -f /var/log/axonops/agent.log`
2. Run Chef in debug mode: `sudo chef-client --local-mode --config /etc/chef/solo.rb -l debug`
3. Verify your JSON is valid: https://jsonlint.com