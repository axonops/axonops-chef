# Test recipe to exercise all custom resources

# Ensure API is configured
node.override['axonops']['api']['key'] = 'resource-test-key'
node.override['axonops']['api']['organization'] = 'test-org'

# Create notification endpoints
axonops_notification 'slack_test' do
  type 'slack'
  config(
    webhook_url: 'https://hooks.slack.com/services/TEST/TEST/test',
    channel: '#alerts',
    username: 'AxonOps Bot'
  )
  action :create
end

axonops_notification 'email_alerts' do
  type 'email'
  config(
    smtp_host: 'smtp.example.com',
    smtp_port: 587,
    from: 'alerts@example.com',
    to: ['ops@example.com', 'oncall@example.com']
  )
  action :create
end

# Create alert rules
axonops_alert_rule 'high_cpu_usage' do
  metric 'cpu_usage'
  condition 'above'
  threshold 90
  duration '5m'
  severity 'critical'
  clusters ['all']
  notification_endpoints ['slack_test']
  enabled true
  action :create
end

axonops_alert_rule 'disk_space_warning' do
  metric 'disk_used_percent'
  condition 'above'
  threshold 80
  duration '10m'
  severity 'warning'
  clusters ['production']
  notification_endpoints ['email_alerts']
  action :create
end

axonops_alert_rule 'memory_pressure' do
  metric 'memory_used_percent'
  condition 'above'
  threshold 85
  duration '15m'
  severity 'warning'
  enabled true
  action :create
end

# Create service checks
axonops_service_check 'cassandra_node_health' do
  check_type 'cassandra_node_status'
  interval '60s'
  timeout '30s'
  clusters ['all']
  enabled true
  action :create
end

axonops_service_check 'jmx_connectivity' do
  check_type 'jmx_connectivity'
  interval '120s'
  timeout '10s'
  config(
    jmx_port: 7199,
    retry_attempts: 3
  )
  action :create
end

axonops_service_check 'compaction_check' do
  check_type 'compaction_backlog'
  interval '300s'
  config(
    threshold_mb: 1000,
    alert_on_exceeded: true
  )
  action :create
end

# Create backup schedules
axonops_backup 'daily_full_backup' do
  backup_type 's3'
  schedule '0 2 * * *' # 2 AM daily
  retention 7 # Keep for 7 days
  destination 's3://backup-bucket/cassandra/daily'
  config(
    aws_region: 'us-east-1',
    storage_class: 'STANDARD_IA',
    encryption: 'AES256'
  )
  clusters ['production']
  enabled true
  action :create
end

axonops_backup 'weekly_snapshot' do
  backup_type 'local'
  schedule '0 3 * * 0' # 3 AM on Sundays
  retention 30 # Keep for 30 days
  destination '/backup/cassandra/weekly'
  config(
    compression: 'gzip',
    parallel_uploads: 4
  )
  action :create
end

# Test update action
axonops_alert_rule 'high_cpu_usage' do
  metric 'cpu_usage'
  threshold 95 # Update threshold
  duration '3m' # Update duration
  action :update
end

# Test resource with minimal properties
axonops_alert_rule 'simple_alert' do
  metric 'node_down'
  condition 'equals'
  threshold 1
  action :create
end

# Create then delete a resource to test deletion
axonops_notification 'temporary_webhook' do
  type 'webhook'
  config(
    url: 'https://example.com/webhook',
    method: 'POST'
  )
  action :create
end

axonops_notification 'temporary_webhook' do
  action :delete
end

# Complex backup configuration
axonops_backup 'incremental_backup' do
  backup_type 'azure'
  schedule '0 */6 * * *' # Every 6 hours
  retention 3
  destination 'https://myaccount.blob.core.windows.net/cassandra-backups'
  config(
    account_name: 'myaccount',
    container_name: 'cassandra-backups',
    incremental: true,
    exclude_keyspaces: %w(system system_traces),
    include_schema: true
  )
  clusters %w(production staging)
  tags(
    environment: 'production',
    team: 'ops'
  )
  action :create
end

# Service check with custom script
axonops_service_check 'custom_health_check' do
  check_type 'custom_script'
  interval '180s'
  timeout '60s'
  config(
    script: '/opt/axonops/scripts/custom_check.sh',
    expected_output: 'OK',
    check_return_code: true
  )
  notification_endpoints %w(slack_test email_alerts)
  action :create
end

# Log configuration to ensure API is accessible
log "AxonOps API configured with key: #{node['axonops']['api']['key'][0..5]}..." do
  level :info
end
