# AxonOps Chef Examples - Alerts, Backups & Integrations

This directory contains example configurations for deploying AxonOps monitoring components using Chef Solo.

## Overview

The `solo.json` file in this directory demonstrates how to configure:
- **Alert Rules** - Metric-based alerts for CPU, disk space, etc.
- **Log Alert Rules** - Pattern-based alerts from log files
- **TCP Checks** - Port availability monitoring
- **Shell Checks** - Custom script-based health checks
- **HTTP Checks** - HTTP endpoint monitoring
- **Backups** - Scheduled backup configurations
- **Integrations** - Notification channels (Slack, PagerDuty, etc.)

## Prerequisites

1. Chef Workstation or Chef Client installed
2. This cookbook available locally
3. AxonOps server (self-hosted or SaaS)
4. Valid AxonOps API credentials

## Quick Start

1. **Clone this cookbook**:
   ```bash
   git clone <repository-url>
   cd axonops-chef
   ```

2. **Navigate to examples directory**:
   ```bash
   cd examples/alerts
   ```

3. **Update configuration**:
   Edit `solo.json` and update the following values:
   ```json
   {
  "axonops": {
      "api": {
        "org": "MYORG",
        "cluster": "MYCLUSTER"
       ...
      },
     },
   }
   ```

4. **Create Chef Solo configuration**:
   Create a `solo.rb` file:
   ```ruby
   cookbook_path File.expand_path('../../', __FILE__)
   json_attribs File.expand_path('./solo.json', __FILE__)
   log_level :info
   log_location STDOUT
   ```

5. **Run Chef Solo**:
   ```bash
   chef-solo -c solo.rb -j solo.json
   ```

## Configuration Details

### Alert Rules
Monitor system metrics with configurable thresholds:
```json
{
  "alert_rules": [
    {
      "name": "High CPU Alert",
      "dashboard": "System",
      "chart": "CPU usage per host",
      "metric": "host_CPU_Percent_Merge",
      "operator": ">",
      "warning_value": 80,
      "critical_value": 90,
      "duration": "15m",
      "routing": ["default"]
    }
  ]
}
```

### Log Alert Rules
Detect patterns in log files with advanced filtering:
```json
{
  "log_alert_rules": [
    {
      "name": "Node Down",
      "content": "is now DOWN",
      "source": ["/var/log/cassandra/system.log"],
      "level": ["error"],
      "warning_value": 1,
      "critical_value": 5,
      "duration": "5m",
      "description": "Cassandra node down detected"
    },
    {
      "name": "Authentication Failures",
      "content": "Authentication failed",
      "source": ["/var/log/cassandra/system.log"],
      "level": ["warning", "error"],
      "warning_value": 10,
      "critical_value": 50,
      "duration": "15m",
      "description": "Multiple authentication failures"
    }
  ]
}
```

**Supported Properties:**
- `content`: Text pattern to search for in logs
- `source`: Array of log file paths to monitor
- `level`: Array of log levels (debug, info, warning, error)
- `type`: Array of log types to filter
- `operator`: Comparison operator (>=, >, <=, <, =, !=)
- `warning_value`: Threshold for warning alerts
- `critical_value`: Threshold for critical alerts
- `duration`: Time window for evaluation
- `dc`, `rack`, `host_id`: Location-based filtering
- `routing`: Array of integration names for notifications
- `present`: Boolean to control alert creation/deletion

### Health Checks

#### TCP Checks
Monitor port availability:
```json
{
  "tcp_checks": [
    {
      "name": "Cassandra CQL Port",
      "tcp": "localhost:9042",
      "interval": "30s",
      "timeout": "5s"
    }
  ]
}
```

#### Shell Checks
Run custom scripts:
```json
{
  "shell_checks": [
    {
      "name": "Check Cassandra Process",
      "script": "ps aux | grep -c '[c]assandra'",
      "shell": "/bin/bash",
      "interval": "1m",
      "timeout": "10s"
    }
  ]
}
```

#### HTTP Checks
Monitor HTTP endpoints:
```json
{
  "http_checks": [
    {
      "name": "API Health",
      "url": "http://localhost:8080/api/v1/health",
      "method": "GET",
      "interval": "1m",
      "timeout": "10s"
    }
  ]
}
```

### Backups
Configure scheduled backups:
```json
{
  "backups": [
    {
      "name": "Daily Backup",
      "keyspace": "system_auth",
      "schedule": "0 2 * * *",
      "retention_days": 7,
      "location": "s3://backup-bucket/cassandra"
    }
  ]
}
```

### Integrations
Set up notification channels:
```json
{
  "integrations": [
    {
      "name": "Slack Alerts",
      "type": "slack",
      "webhook_url": "https://hooks.slack.com/services/XXX",
      "channel": "#alerts"
    },
    {
      "name": "PagerDuty Critical",
      "type": "pagerduty",
      "integration_key": "your-integration-key"
    }
  ]
}
```

## Testing Individual Components

To test only specific components, modify the run_list:

```json
{
  "run_list": [
    "recipe[axonops::alert_rules]"    // For all alert configurations
  ]
}
```

Or test individual resource types by creating minimal configurations:

```bash
# Test only TCP checks
echo '{
  "axonops": {
    "tcp_checks": [{
      "name": "Test Port",
      "tcp": "localhost:80",
      "interval": "1m",
      "timeout": "5s"
    }]
  },
  "run_list": ["recipe[axonops::alert_rules]"]
}' > test-tcp.json

sudo chef-solo -c solo.rb -j test-tcp.json
```

## Troubleshooting

1. **Authentication Issues**:
   - Verify your API token is correct
   - Check server_url includes protocol (http:// or https://)
   - Ensure org_name matches your AxonOps organization

2. **Validation Errors**:
   - Interval and timeout must be strings (e.g., "30s", "1m", "5m")
   - TCP checks require format "host:port" in the tcp property
   - All required properties must be present

3. **Debug Mode**:
   Run with debug logging:
   ```bash
   sudo chef-solo -c solo.rb -j solo.json -l debug
   ```

4. **Common Time Formats**:
   - Seconds: "30s"
   - Minutes: "5m"
   - Hours: "1h"
   - Days: "7d"

## Environment Variables

You can override configuration using environment variables:
- `AXONOPS_URL` - AxonOps server URL
- `AXONOPS_ORG` - Organization name
- `AXONOPS_CLUSTER` - Cluster name
- `AXONOPS_TOKEN` - API authentication token
- `AXONOPS_USERNAME` - Username (if not using token)
- `AXONOPS_PASSWORD` - Password (if not using token)

Example:
```bash
export AXONOPS_URL="https://dash.axonops.cloud"
export AXONOPS_TOKEN="your-token"
chef-solo -c solo.rb -j solo.json
```

## Next Steps

1. Review the created resources in your AxonOps dashboard
2. Adjust thresholds and intervals based on your requirements
3. Test alerts by triggering conditions
4. Integrate with your existing Chef infrastructure

For more information, see the main cookbook documentation.
