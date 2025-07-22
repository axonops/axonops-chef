#
# Cookbook:: axonops
# Recipe:: example_alerts
#
# Example recipe demonstrating how to configure alert rules
#

# Example 1: CPU usage alert
axonops_alert_rule 'Check for High CPU' do
  org ENV['AXONOPS_ORG'] || node['axonops']['api']['org']
  cluster ENV['AXONOPS_CLUSTER'] || node['axonops']['api']['cluster']
  username ENV['AXONOPS_USERNAME'] || node['axonops']['api']['username'] || ''
  password ENV['AXONOPS_PASSWORD'] || node['axonops']['api']['password'] || ''
  base_url ENV['AXONOPS_URL'] || node['axonops']['api']['base_url'] || ''
  auth_token ENV['AXONOPS_TOKEN'] || node['axonops']['api']['auth_token'] || ''
  dashboard 'System'
  chart 'CPU usage per host'
  metric 'host_CPU_Percent_Merge'
  operator '>'
  warning_value 80
  critical_value 90
  duration '5m'
  description 'Alert when CPU usage is too high'
  routing ['slack-alerts', 'pagerduty']  # Integration names
  action :create
end

# Example 2: Memory usage alert
axonops_alert_rule 'high_memory_usage' do
  org ENV['AXONOPS_ORG'] || node['axonops']['api']['org']
  cluster ENV['AXONOPS_CLUSTER'] || node['axonops']['api']['cluster']
  username ENV['AXONOPS_USERNAME'] || node['axonops']['api']['username'] || ''
  password ENV['AXONOPS_PASSWORD'] || node['axonops']['api']['password'] || ''
  base_url ENV['AXONOPS_URL'] || node['axonops']['api']['base_url'] || ''
  auth_token ENV['AXONOPS_TOKEN'] || node['axonops']['api']['auth_token'] || ''
  dashboard 'System'
  chart 'Used memory'
  metric 'host_Memory_Used'
  operator '>'
  warning_value 80
  critical_value 90
  duration '5m'
  description 'Alert when memory usage is too high'
  routing ['slack-alerts', 'pagerduty']  # Integration names
  action :create
end
