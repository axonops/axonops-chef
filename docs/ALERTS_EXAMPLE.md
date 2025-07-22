# Full payload example

```json
{
  "run_list": [
    "recipe[axonops::alert_rules]"
  ],
  "axonops": {
    "api": {
      "org": "testorg1",
      "cluster": "test50cluster"
    },
    "alert_rules": [
      {
        "name": "Check for High CPU usage",
        "dashboard": "System",
        "chart": "CPU usage per host",
        "metric": "host_CPU_Percent_Merge",
        "operator": ">",
        "warning_value": 80,
        "critical_value": 90,
        "duration": "15m",
        "description": "Alert when CPU usage is too high",
        "routing": [
          "slack-alerts",
          "pagerduty"
        ],
        "action": "create"
      },
      {
        "name": "High Memory Usage",
        "dashboard": "System",
        "chart": "Used memory",
        "metric": "host_Memory_Used",
        "operator": ">",
        "warning_value": 80,
        "critical_value": 90,
        "duration": "5m",
        "description": "Alert when memory usage is too high",
        "routing": [
          "slack-alerts"
        ],
        "action": "create"
      }
    ],
    "tcp_checks": [
      {
        "name": "Storage Port Check",
        "interval": "1m",
        "timeout": "1m",
        "tcp": "{{.comp_listen_address}}:{{.comp_storage_port}}",
        "action": "create"
      },
      {
        "name": "CQL Port Check",
        "interval": "2m",
        "timeout": "1m",
        "tcp": "{{.comp_rpc_address}}:{{.comp_native_transport_port}}",
        "action": "create"
      }
    ],
    "shell_checks": [
      {
        "name": "NODE DOWN",
        "interval": "30s",
        "timeout": "1m",
        "shell": "/bin/bash",
        "script": "EXIT_OK=0\nEXIT_WARNING=1\nEXIT_CRITICAL=2\n\nNODETOOL=/opt/cassandra/bin/nodetool\nWARNING_DN_COUNT=1\nCRITICAL_DN_COUNT=2\n\nlocal_dc=$($NODETOOL info | awk -F: '/Data Center/{gsub(/^[ \\t]+/, \"\", $2); print $2}')\nif [ -z $local_dc ]; then\n    exit $EXIT_WARNING\nfi\n\n# Check node status logic here\nexit $EXIT_OK",
        "action": "create"
      },
      {
        "name": "axon-agent.log check",
        "interval": "1m",
        "timeout": "30s",
        "shell": "/bin/bash",
        "script": "if [ -r /var/log/axonops/axon-agent.log ]\nthen\n  exit 0\nelse\n  echo 'Unable to read /var/log/axonops/axon-agent.log'\n  exit 2\nfi",
        "action": "create"
      }
    ],
    "http_checks": [
      {
        "name": "AxonOps API Health Check",
        "interval": "1m",
        "timeout": "30s",
        "url": "https://api.axonops.com/health",
        "http_method": "GET",
        "expected_status": 200,
        "headers": {
          "Accept": "application/json"
        },
        "action": "create"
      },
      {
        "name": "Webhook Test",
        "interval": "5m",
        "timeout": "1m",
        "url": "https://webhook.site/your-webhook-url",
        "http_method": "POST",
        "headers": {
          "Content-Type": "application/json",
          "X-Custom-Header": "AxonOps"
        },
        "body": "{\"status\": \"check\", \"service\": \"cassandra\"}",
        "expected_status": 201,
        "action": "create"
      }
    ],
    "backups": [
      {
        "name": "Daily S3 Backup",
        "tag": "daily-s3-backup",
        "local_retention_duration": "1d",
        "remote_retention_duration": "7d",
        "remote": true,
        "remote_type": "s3",
        "s3_region": "us-east-1",
        "s3_access_key_id": "YOUR_ACCESS_KEY_ID",
        "s3_secret_access_key": "YOUR_SECRET_ACCESS_KEY",
        "s3_storage_class": "STANDARD",
        "s3_acl": "private",
        "s3_encryption": "AES256",
        "s3_no_check_bucket": true,
        "s3_disable_checksum": false,
        "remote_path": "my-backup-bucket/cassandra-backups",
        "schedule": true,
        "schedule_expr": "0 2 * * *",
        "keyspaces": ["system_auth", "my_keyspace"],
        "datacenters": ["dc1"],
        "all_nodes": true,
        "all_tables": false,
        "tables": [{ "Name": "important_table" }],
        "bwlimit": "50M",
        "tpslimit": 25,
        "action": "create"
      },
      {
        "name": "SFTP Backup",
        "tag": "sftp-backup",
        "local_retention_duration": "1d",
        "remote_retention_duration": "7d",
        "remote": true,
        "remote_type": "sftp",
        "remote_path": "backup-server/cassandra-backups",
        "sftp_host": "backup.example.com",
        "sftp_user": "sftp_user",
        "sftp_pass": "your_sftp_password",
        "sftp_port": "22",
        "schedule": true,
        "schedule_expr": "0 3 * * *",
        "keyspaces": ["system_auth"],
        "all_nodes": true,
        "action": "create"
      }
    ],
    "integrations": [
      {
        "name": "slack-alerts",
        "integration_type": "slack",
        "slack_webhook_url": "https://hooks.slack.com/services/XXX/XXX/XXXXXXX",
        "slack_channel": "#alerts",
        "slack_axondash_url": "https://axonops.internal.axonopsdev.com",
        "action": "create"
      },
      {
        "name": "pagerduty",
        "integration_type": "pagerduty",
        "pagerduty_integration_key": "YOUR_PAGERDUTY_INTEGRATION_KEY",
        "action": "create"
      },
      {
        "name": "teams-alerts",
        "integration_type": "microsoft_teams",
        "teams_webhook_url": "https://outlook.office.com/webhook/YOUR_TEAMS_WEBHOOK",
        "action": "create"
      },
      {
        "name": "email-alerts",
        "integration_type": "smtp",
        "smtp_server": "smtp.example.com",
        "smtp_port": "587",
        "smtp_username": "alerts@example.com",
        "smtp_password": "smtp_password",
        "smtp_from": "alerts@example.com",
        "smtp_receivers": "ops-team@example.com",
        "smtp_subject": "AxonOps Alert",
        "smtp_start_tls": true,
        "smtp_auth_login": true,
        "smtp_skip_certificate_verify": false,
        "action": "create"
      },
      {
        "name": "servicenow-incidents",
        "integration_type": "servicenow",
        "servicenow_instance_url": "https://mycompany.service-now.com",
        "servicenow_username": "api_user",
        "servicenow_password": "api_password",
        "servicenow_client_id": "optional_client_id",
        "servicenow_client_secret": "optional_client_secret",
        "action": "create"
      },
      {
        "name": "opsgenie-alerts",
        "integration_type": "opsgenie",
        "opsgenie_api_key": "YOUR_OPSGENIE_API_KEY",
        "opsgenie_api_url": "https://api.opsgenie.com",
        "action": "create"
      },
      {
        "name": "generic-webhook",
        "integration_type": "general_webhook",
        "webhook_url": "http://some:8080",
        "webhook_headers": [
          { "header": "Auth", "value": "blab" },
          { "header": "Other", "value": "other" }
        ],
        "action": "create"
      }
    ]
  }
}
```
