#
# Cookbook:: axonops
# Recipe:: configure
#
# Configures AxonOps monitoring via API
# Based on https://github.com/axonops/axonops-config-automation
#

# Ensure we have API credentials
unless node['axonops']['api']['key'] || node['axonops']['deployment_mode'] == 'self-hosted'
  raise('AxonOps API key required for configuration. Set node["axonops"]["api"]["key"]')
end

# Configure Alert Endpoints (Notification Channels)
node['axonops']['alerts']['endpoints'].each do |endpoint_name, config|
  axonops_notification endpoint_name do
    type config['type']
    config config
    action :create
  end
end

# Configure Alert Rules
node['axonops']['alerts']['rules'].each do |rule_name, config|
  axonops_alert_rule rule_name do
    metric config['metric']
    condition config['condition'] || 'above'
    threshold config['threshold']
    duration config['duration'] || '5m'
    severity config['severity'] || 'warning'
    clusters config['clusters'] || []
    description config['description']
    enabled config.fetch('enabled', true)
    action :create
  end
end

# Configure Service Checks
node['axonops']['service_checks'].each do |check_name, config|
  axonops_service_check check_name do
    check_type config['type']
    interval config['interval'] || '60s'
    timeout config['timeout'] || '30s'
    config config
    action :create
  end
end

# Configure Backup Schedules
node['axonops']['backups'].each do |backup_name, config|
  axonops_backup backup_name do
    backup_type config['type']
    schedule config['schedule']
    retention config['retention']
    destination config['destination']
    config config
    action :create
  end
end

# Log successful configuration
Chef::Log.info('AxonOps configuration completed via API')
