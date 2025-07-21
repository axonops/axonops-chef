#
# Cookbook:: axonops
# Recipe:: example_alerts
#
# Example recipe demonstrating how to configure alert rules
#

# Example 1: CPU usage alert
axonops_alert_rule 'high_cpu_usage' do
  org node['axonops']['api']['org']
  cluster node['axonops']['api']['cluster']
  dashboard 'System'
  chart 'CPU Usage'
  metric 'cpu_usage_percent'
  operator '>'
  warning_value 80
  critical_value 90
  duration '5m'
  description 'Alert when CPU usage is too high'
  notifications_enabled true
  routing ['slack-alerts', 'pagerduty']  # Integration names
  action :create
end

# Example 2: Disk space alert with per-host monitoring
axonops_alert_rule 'low_disk_space' do
  org node['axonops']['api']['org']
  cluster node['axonops']['api']['cluster']
  dashboard 'Storage'
  chart 'Disk Usage'
  metric 'disk_free_percent'
  operator '<'
  warning_value 20
  critical_value 10
  duration '10m'
  description 'Alert when disk space is running low'
  per({ 'enabled' => true, 'type' => 'perHost' })
  notifications_enabled true
  repeat_interval '30m'
  action :create
end

# Example 3: Cassandra-specific alert - compaction pending
axonops_alert_rule 'high_compaction_pending' do
  org node['axonops']['api']['org']
  cluster node['axonops']['api']['cluster']
  dashboard 'Cassandra'
  chart 'Compaction Pending'
  metric 'cassandra_compaction_pending_tasks'
  operator '>'
  warning_value 100
  critical_value 500
  duration '15m'
  description 'Alert when too many compactions are pending'
  scope_filters({ 'keyspace' => 'production' })
  notifications_enabled true
  action :create
end

# Example 4: Event-based alert - too many errors
axonops_alert_rule 'excessive_errors' do
  org node['axonops']['api']['org']
  cluster node['axonops']['api']['cluster']
  dashboard 'Events'
  chart 'Error Events'
  operator '>'
  warning_value 50
  critical_value 100
  duration '5m'
  description 'Alert on excessive error events'
  filters({ 'Type' => 'events' })
  notifications_enabled true
  action :create
end

# Example 5: Custom PromQL expression alert
axonops_alert_rule 'custom_latency_alert' do
  org node['axonops']['api']['org']
  cluster node['axonops']['api']['cluster']
  dashboard 'Performance'
  chart 'Read Latency'
  expr '(avg(rate(cassandra_read_latency_ms[5m])) > 10) OR (avg(rate(cassandra_read_latency_ms[5m])) > 20)'
  warning_value 10
  critical_value 20
  duration '5m'
  description 'Custom alert for read latency using PromQL'
  notifications_enabled true
  action :create
end

# Example 6: Datacenter-specific alert
axonops_alert_rule 'dc_replication_lag' do
  org node['axonops']['api']['org']
  cluster node['axonops']['api']['cluster']
  dashboard 'Replication'
  chart 'Cross-DC Lag'
  metric 'cassandra_cross_dc_latency_ms'
  operator '>'
  warning_value 100
  critical_value 500
  duration '10m'
  description 'Alert on cross-datacenter replication lag'
  scope_filters({ 'dc' => 'us-east-1' })
  per({ 'enabled' => true, 'type' => 'perDC' })
  notifications_enabled true
  action :create
end

# Example 7: Delete an alert rule
axonops_alert_rule 'deprecated_alert' do
  org node['axonops']['api']['org']
  cluster node['axonops']['api']['cluster']
  action :delete
end