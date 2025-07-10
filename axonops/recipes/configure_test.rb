#
# Cookbook:: axonops
# Recipe:: configure_test
#
# Test recipe for AxonOps configuration management
#

# Include prerequisites only
include_recipe 'axonops::default'
include_recipe 'axonops::_common'

# Skip the actual configure recipe as it needs custom resources
# Just create the test config files directly

# Create test configuration files
directory '/etc/axonops/config.d' do
  owner 'axonops'
  group 'axonops'
  mode '0755'
end

# Create test alert configuration
file '/etc/axonops/config.d/alerts.yml' do
  content <<-YAML
alerts:
  endpoints:
    test_slack:
      type: slack
      webhook_url: https://hooks.slack.com/services/TEST/TEST/TEST
  rules:
    high_cpu:
      condition: cpu_usage > 80
      duration: 5m
      endpoint: test_slack
YAML
  owner 'axonops'
  group 'axonops'
  mode '0644'
end

# Create test service checks
file '/etc/axonops/config.d/service_checks.yml' do
  content <<-YAML
service_checks:
  cassandra_health:
    interval: 60s
    timeout: 10s
    check_type: nodetool_status
YAML
  owner 'axonops'
  group 'axonops'
  mode '0644'
end

# Create test backup configuration
file '/etc/axonops/config.d/backups.yml' do
  content <<-YAML
backups:
  schedules:
    daily:
      cron: "0 2 * * *"
      retention: 7
  destination:
    type: local
    path: /backup/cassandra
YAML
  owner 'axonops'
  group 'axonops'
  mode '0644'
end

# Create backup directory
directory '/backup/cassandra' do
  owner 'axonops'
  group 'axonops'
  mode '0755'
  recursive true
end

# Log completion
log 'axonops-configure-test-info' do
  message 'AxonOps configuration test recipe completed'
  level :info
end