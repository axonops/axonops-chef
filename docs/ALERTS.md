# AxonOps Monitoring and Operations Guide

This guide explains how to configure monitoring, alerting, and backups in AxonOps using the Chef cookbook. AxonOps provides comprehensive operational capabilities for Apache Cassandra and Kafka clusters.

## Table of Contents

- [Overview](#overview)
- [Components](#components)
- [Configuration Methods](#configuration-methods)
- [Alert Rules](#alert-rules)
- [Health Checks](#health-checks)
- [Integrations](#integrations)
- [Backups](#backups)
- [Best Practices](#best-practices)
- [Examples](#examples)

## Overview

AxonOps operational management consists of four main components:

1. **Alert Rules** - Define conditions that trigger alerts based on metrics
2. **Health Checks** - Monitor service availability (TCP, HTTP, Shell scripts)
3. **Integrations** - Send notifications to external systems (Slack, PagerDuty, etc.)
4. **Backups** - Automated backup scheduling with local and remote storage

## Components

### Alert Rules

Alert rules monitor metrics and trigger notifications when thresholds are exceeded. They require:

- **Dashboard & Chart** - Reference to existing AxonOps dashboard visualizations
- **Metric** - The specific metric to monitor
- **Operator** - Comparison operator (>, <, =, !=, >=, <=)
- **Thresholds** - Warning and critical values
- **Duration** - How long the condition must persist
- **Routing** - Which integrations receive notifications

### Health Checks

Health checks verify service availability through:

- **TCP Checks** - Test network port connectivity
- **HTTP Checks** - Validate HTTP endpoint responses
- **Shell Checks** - Execute custom scripts for complex validations

### Integrations

Integrations define where alerts are sent:

- Slack
- PagerDuty
- Microsoft Teams
- Email (SMTP)
- ServiceNow
- OpsGenie
- Generic Webhooks

### Backups

Automated backup management with:

- **Scheduled Backups** - Cron-based scheduling
- **Local Storage** - Fast recovery with configurable retention
- **Remote Storage** - S3, SFTP, Azure Blob Storage
- **Granular Selection** - Keyspaces, tables, datacenters, nodes
- **Bandwidth Control** - Rate limiting for network usage

## Configuration Methods

### Method 1: Using Chef Attributes (Recommended)

Configure alerts through Chef attributes in your environment, role, or node:

```ruby
{
  "axonops": {
    "api": {
      "org": "your-organization",
      "cluster": "your-cluster-name"
    },
    "alert_rules": [
      {
        "name": "High CPU Usage",
        "dashboard": "System",
        "chart": "CPU usage per host",
        "metric": "host_CPU_Percent_Merge",
        "operator": ">",
        "warning_value": 80,
        "critical_value": 90,
        "duration": "15m",
        "description": "CPU usage is above normal levels",
        "routing": ["slack-alerts", "pagerduty"],
        "action": "create"
      }
    ],
    "integrations": [
      {
        "name": "slack-alerts",
        "integration_type": "slack",
        "slack_webhook_url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
        "slack_channel": "#alerts",
        "action": "create"
      }
    ]
  }
}
```

### Method 2: Direct Resource Usage

Use resources directly in your recipes:

```ruby
# Create a Slack integration
axonops_integration "slack-alerts" do
  integration_type "slack"
  slack_webhook_url "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
  slack_channel "#alerts"
  org node['axonops']['api']['org']
  cluster node['axonops']['api']['cluster']
  action :create
end

# Create an alert rule
axonops_alert_rule "High CPU Usage" do
  dashboard "System"
  chart "CPU usage per host"
  metric "host_CPU_Percent_Merge"
  operator ">"
  warning_value 80
  critical_value 90
  duration "15m"
  description "CPU usage is above normal levels"
  routing ["slack-alerts"]
  org node['axonops']['api']['org']
  cluster node['axonops']['api']['cluster']
  action :create
end
```

## Alert Rules

### Required Properties

- `name` - Unique identifier for the alert
- `dashboard` - Name of the AxonOps dashboard
- `chart` - Name of the chart within the dashboard
- `operator` - Comparison operator: `>`, `<`, `=`, `!=`, `>=`, `<=`
- `warning_value` - Threshold for warning alerts
- `critical_value` - Threshold for critical alerts
- `duration` - Time period (e.g., "5m", "15m", "1h")

### Optional Properties

- `metric` - Specific metric to monitor (auto-detected if not specified)
- `description` - Human-readable description
- `routing` - Array of integration names for notifications
- `routing_severity` - Severity level: "info", "warning", "error" (default: "warning")
- `group_by` - Group results by: "dc", "host_id", "rack", "scope"
- `filters` - Additional filtering criteria

### Common Alert Patterns

#### System Metrics

```ruby
# CPU Usage
{
  "name": "High CPU Usage",
  "dashboard": "System",
  "chart": "CPU usage per host",
  "operator": ">",
  "warning_value": 80,
  "critical_value": 90,
  "duration": "15m"
}

# Memory Usage
{
  "name": "High Memory Usage",
  "dashboard": "System",
  "chart": "Used memory",
  "operator": ">",
  "warning_value": 85,
  "critical_value": 95,
  "duration": "10m"
}

# Disk Space
{
  "name": "Low Disk Space",
  "dashboard": "System",
  "chart": "Disk usage",
  "operator": ">",
  "warning_value": 80,
  "critical_value": 90,
  "duration": "30m"
}
```

#### Cassandra Metrics

```ruby
# Pending Compactions
{
  "name": "High Pending Compactions",
  "dashboard": "Cassandra",
  "chart": "Pending compactions",
  "operator": ">",
  "warning_value": 100,
  "critical_value": 500,
  "duration": "20m"
}

# Read Latency
{
  "name": "High Read Latency",
  "dashboard": "Cassandra",
  "chart": "Read latency",
  "metric": "org_apache_cassandra_metrics_ClientRequest_Latency_Read",
  "operator": ">",
  "warning_value": 50,
  "critical_value": 100,
  "duration": "10m"
}
```

## Health Checks

### TCP Checks

Monitor network service availability:

```ruby
{
  "tcp_checks": [
    {
      "name": "Storage Port Check",
      "tcp": "{{.comp_listen_address}}:{{.comp_storage_port}}",
      "interval": "1m",
      "timeout": "30s"
    },
    {
      "name": "CQL Port Check",
      "tcp": "{{.comp_rpc_address}}:{{.comp_native_transport_port}}",
      "interval": "2m",
      "timeout": "30s"
    }
  ]
}
```

### HTTP Checks

Validate HTTP endpoints:

```ruby
{
  "http_checks": [
    {
      "name": "API Health Check",
      "url": "https://api.example.com/health",
      "http_method": "GET",
      "expected_status": 200,
      "interval": "1m",
      "timeout": "30s",
      "headers": {
        "Accept": "application/json"
      }
    }
  ]
}
```

### Shell Checks

Execute custom validation scripts:

```ruby
{
  "shell_checks": [
    {
      "name": "Node Health Check",
      "shell": "/bin/bash",
      "interval": "5m",
      "timeout": "1m",
      "script": "#!/bin/bash\nif nodetool status | grep -q 'DN'; then\n  echo 'Node is down'\n  exit 2\nfi\nexit 0"
    }
  ]
}
```

## Integrations

### Slack

```ruby
{
  "name": "slack-critical",
  "integration_type": "slack",
  "slack_webhook_url": "https://hooks.slack.com/services/T00/B00/XXX",
  "slack_channel": "#critical-alerts",
  "slack_axondash_url": "https://axonops.yourdomain.com"
}
```

### PagerDuty

```ruby
{
  "name": "pagerduty-oncall",
  "integration_type": "pagerduty",
  "pagerduty_integration_key": "YOUR_INTEGRATION_KEY"
}
```

### Email (SMTP)

```ruby
{
  "name": "email-alerts",
  "integration_type": "smtp",
  "smtp_server": "smtp.gmail.com",
  "smtp_port": "587",
  "smtp_username": "alerts@example.com",
  "smtp_password": "your-password",
  "smtp_from": "alerts@example.com",
  "smtp_receivers": "team@example.com,oncall@example.com",
  "smtp_subject": "AxonOps Alert - {{.AlertName}}",
  "smtp_start_tls": true,
  "smtp_auth_login": true
}
```

### Microsoft Teams

```ruby
{
  "name": "teams-alerts",
  "integration_type": "microsoft_teams",
  "teams_webhook_url": "https://outlook.office.com/webhook/YOUR_WEBHOOK"
}
```

### ServiceNow

```ruby
{
  "name": "servicenow-incidents",
  "integration_type": "servicenow",
  "servicenow_instance_url": "https://mycompany.service-now.com",
  "servicenow_username": "api_user",
  "servicenow_password": "api_password",
  "servicenow_client_id": "optional_client_id",
  "servicenow_client_secret": "optional_client_secret"
}
```

### OpsGenie

```ruby
{
  "name": "opsgenie-alerts",
  "integration_type": "opsgenie",
  "opsgenie_api_key": "YOUR_API_KEY",
  "opsgenie_api_url": "https://api.opsgenie.com"
}
```

### Generic Webhook

```ruby
{
  "name": "custom-webhook",
  "integration_type": "general_webhook",
  "webhook_url": "https://api.example.com/webhooks/alerts",
  "webhook_headers": [
    { "header": "Authorization", "value": "Bearer YOUR_TOKEN" },
    { "header": "X-Custom-Header", "value": "CustomValue" }
  ]
}
```

## Backups

AxonOps provides automated backup management with flexible scheduling and storage options.

### Required Properties

- `name` - Display name for the backup configuration
- `tag` - Unique identifier tag for the backup
- `keyspaces` - Array of keyspaces to backup

### Storage Configuration

#### Local Storage Only

```ruby
{
  "name": "Local Daily Backup",
  "tag": "local-daily",
  "local_retention_duration": "7d",
  "remote": false,
  "schedule": true,
  "schedule_expr": "0 2 * * *",
  "keyspaces": ["system_auth", "my_keyspace"],
  "all_nodes": true
}
```

#### S3 Remote Storage

```ruby
{
  "name": "S3 Backup",
  "tag": "s3-backup",
  "local_retention_duration": "1d",
  "remote_retention_duration": "30d",
  "remote": true,
  "remote_type": "s3",
  "remote_path": "my-bucket/cassandra-backups",
  "s3_region": "us-east-1",
  "s3_access_key_id": "AKIAIOSFODNN7EXAMPLE",
  "s3_secret_access_key": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
  "s3_storage_class": "STANDARD_IA",
  "s3_encryption": "AES256",
  "schedule": true,
  "schedule_expr": "0 2 * * *",
  "keyspaces": ["production_data"],
  "datacenters": ["dc1"],
  "all_nodes": true
}
```

#### SFTP Remote Storage

```ruby
{
  "name": "SFTP Backup",
  "tag": "sftp-backup",
  "local_retention_duration": "1d",
  "remote_retention_duration": "14d",
  "remote": true,
  "remote_type": "sftp",
  "remote_path": "/backups/cassandra",
  "sftp_host": "backup.example.com",
  "sftp_user": "backup_user",
  "sftp_pass": "secure_password",
  "sftp_port": "22",
  "schedule": true,
  "schedule_expr": "0 3 * * *",
  "keyspaces": ["system_auth"],
  "all_nodes": true
}
```

#### Azure Blob Storage

```ruby
{
  "name": "Azure Backup",
  "tag": "azure-backup",
  "local_retention_duration": "2d",
  "remote_retention_duration": "90d",
  "remote": true,
  "remote_type": "azure",
  "remote_path": "container/cassandra-backups",
  "azure_account": "myaccount",
  "azure_key": "mykey",
  "schedule": true,
  "schedule_expr": "0 1 * * *",
  "keyspaces": ["critical_data"],
  "all_nodes": false,
  "nodes": ["node1.example.com", "node2.example.com"]
}
```

### Backup Selection Options

#### By Keyspace and Table

```ruby
{
  "keyspaces": ["my_keyspace"],
  "tables": [
    { "Name": "important_table" },
    { "Name": "critical_table" }
  ],
  "all_tables": false
}
```

#### By Datacenter and Rack

```ruby
{
  "datacenters": ["dc1", "dc2"],
  "racks": ["rack1", "rack2"],
  "all_nodes": false
}
```

#### Specific Nodes

```ruby
{
  "nodes": ["10.0.1.10", "10.0.1.11"],
  "all_nodes": false
}
```

### Performance Settings

Control backup performance and resource usage:

```ruby
{
  "bwlimit": "50M",        # Bandwidth limit (e.g., "50M", "1G")
  "tpslimit": 25,          # Transactions per second limit
  "transfers": 4,          # Parallel transfer threads
  "timeout": "2h",         # Operation timeout
  "full_backup": false     # Full vs incremental backup
}
```

### Schedule Expressions

Uses cron format for scheduling:

- `"0 2 * * *"` - Daily at 2 AM
- `"0 0 * * 0"` - Weekly on Sunday at midnight
- `"0 3 1 * *"` - Monthly on the 1st at 3 AM
- `"0 */6 * * *"` - Every 6 hours
- `"30 2 * * 1-5"` - Weekdays at 2:30 AM

### Complete Backup Example

```ruby
{
  "backups": [
    {
      "name": "Production Backup",
      "tag": "prod-backup",
      "local_retention_duration": "3d",
      "remote_retention_duration": "30d",
      "remote": true,
      "remote_type": "s3",
      "remote_path": "prod-backups/cassandra",
      "s3_region": "us-west-2",
      "s3_access_key_id": "YOUR_KEY",
      "s3_secret_access_key": "YOUR_SECRET",
      "s3_storage_class": "GLACIER",
      "s3_encryption": "AES256",
      "schedule": true,
      "schedule_expr": "0 2 * * *",
      "keyspaces": ["production", "analytics"],
      "datacenters": ["dc1"],
      "all_nodes": true,
      "all_tables": true,
      "bwlimit": "100M",
      "tpslimit": 50,
      "transfers": 4,
      "timeout": "4h",
      "action": "create"
    }
  ]
}
```

### Backup Notifications

Backups can trigger alerts on failure. Configure backup failure routing in the global routing settings:

```ruby
{
  "integrations": [
    {
      "name": "backup-alerts",
      "integration_type": "slack",
      "slack_webhook_url": "https://hooks.slack.com/services/XXX",
      "slack_channel": "#backup-notifications"
    }
  ]
}
```

## Best Practices

### 1. Use Descriptive Names

Choose clear, descriptive names for alerts and integrations:
- ✅ "High CPU Usage Production"
- ❌ "Alert1"

### 2. Set Appropriate Thresholds

- Start with conservative thresholds and adjust based on your environment
- Leave headroom between warning and critical values
- Consider normal operating ranges for your workload

### 3. Configure Duration Wisely

- Short durations (1-5m) for critical services
- Longer durations (15-30m) for metrics with natural fluctuations
- Avoid alert fatigue from transient spikes

### 4. Group Related Alerts

Use routing to send related alerts to the same integration:

```ruby
{
  "routing": ["database-team-slack", "database-pagerduty"]
}
```

### 5. Test Your Alerts

- Create test conditions to verify alerts fire correctly
- Test all integration endpoints
- Document escalation procedures

### 6. Use Templates

AxonOps supports template variables in health checks:
- `{{.comp_listen_address}}` - Node listen address
- `{{.comp_storage_port}}` - Storage port
- `{{.comp_native_transport_port}}` - CQL port

### 7. Implement Gradual Rollout

1. Start with a few critical alerts
2. Monitor for false positives
3. Gradually add more alerts
4. Refine thresholds based on experience

### 8. Backup Best Practices

- **Test Restores**: Regularly test backup restoration procedures
- **Monitor Backup Jobs**: Set up alerts for backup failures
- **Secure Credentials**: Use encrypted data bags or vault for sensitive data
- **Network Consideration**: Use bandwidth limits during business hours
- **Retention Policy**: Balance storage costs with recovery requirements
- **Geographic Distribution**: Store remote backups in different regions

## Examples

For complete working examples, see [ALERTS_EXAMPLE.md](ALERTS_EXAMPLE.md).

### Quick Start Example

```ruby
{
  "run_list": ["recipe[axonops::alert_rules]"],
  "axonops": {
    "api": {
      "org": "mycompany",
      "cluster": "production"
    },
    "integrations": [
      {
        "name": "slack-dba",
        "integration_type": "slack",
        "slack_webhook_url": "https://hooks.slack.com/services/XXX",
        "slack_channel": "#database-alerts"
      }
    ],
    "alert_rules": [
      {
        "name": "Critical CPU",
        "dashboard": "System",
        "chart": "CPU usage per host",
        "operator": ">",
        "warning_value": 80,
        "critical_value": 90,
        "duration": "5m",
        "routing": ["slack-dba"]
      }
    ],
    "tcp_checks": [
      {
        "name": "CQL Port",
        "tcp": "{{.comp_rpc_address}}:9042",
        "interval": "1m",
        "timeout": "10s"
      }
    ],
    "backups": [
      {
        "name": "Daily Backup",
        "tag": "daily-backup",
        "local_retention_duration": "3d",
        "remote": true,
        "remote_type": "s3",
        "remote_path": "my-bucket/backups",
        "s3_region": "us-east-1",
        "s3_access_key_id": "YOUR_KEY",
        "s3_secret_access_key": "YOUR_SECRET",
        "schedule": true,
        "schedule_expr": "0 2 * * *",
        "keyspaces": ["system_auth", "production"],
        "all_nodes": true
      }
    ]
  }
}
```

## Troubleshooting

### Common Issues

1. **Alert not firing**
   - Verify the dashboard and chart names match exactly
   - Check metric values in AxonOps UI
   - Ensure duration has elapsed

2. **Integration not working**
   - Test webhook URLs are accessible
   - Verify authentication credentials
   - Check Chef logs for errors

3. **Duplicate alerts**
   - Ensure alert names are unique
   - Check for multiple Chef runs

4. **Backup failures**
   - Verify remote storage credentials
   - Check network connectivity to remote storage
   - Ensure sufficient disk space for local backups
   - Validate cron expression syntax

5. **Backup performance issues**
   - Adjust bandwidth limits
   - Reduce transfer threads
   - Schedule during off-peak hours

### Debug Mode

Enable debug logging to see detailed information:

```bash
chef-client -l debug
```

## Additional Resources

- [AxonOps Documentation](https://docs.axonops.com)
- [Chef Resource Reference](../README.md#resources)
- [Complete Examples](ALERTS_EXAMPLE.md)