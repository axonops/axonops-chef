# AxonOps Chef Cookbook - Configuration Examples

This guide provides practical examples for common AxonOps deployment scenarios.

## Table of Contents

1. [Basic SaaS Agent Deployment](#basic-saas-agent-deployment)
2. [Self-Hosted Full Stack](#self-hosted-full-stack)
3. [Production Cassandra Cluster](#production-cassandra-cluster)
4. [Multi-Datacenter Setup](#multi-datacenter-setup)
5. [Offline/Airgapped Installation](#offlineairgapped-installation)
6. [High Performance Configuration](#high-performance-configuration)
7. [Security Hardened Setup](#security-hardened-setup)

---

## Basic SaaS Agent Deployment

Monitor an existing Cassandra cluster using AxonOps SaaS.

### Wrapper Cookbook Recipe

```ruby
# recipes/axonops_agent.rb
node.override['axonops']['deployment_mode'] = 'saas'
node.override['axonops']['api']['key'] = 'your-api-key-here'
node.override['axonops']['api']['organization'] = 'your-org-name'

# Agent will auto-detect existing Cassandra
include_recipe 'axonops::agent'
```

### Role Definition

```json
{
  "name": "cassandra_monitored",
  "description": "Cassandra node with AxonOps monitoring",
  "run_list": [
    "recipe[axonops::agent]"
  ],
  "override_attributes": {
    "axonops": {
      "deployment_mode": "saas",
      "api": {
        "key": "your-api-key-here",
        "organization": "your-org-name"
      }
    }
  }
}
```

---

## Self-Hosted Full Stack

Complete AxonOps installation with all components.

### Environment Configuration

```json
{
  "name": "axonops_self_hosted",
  "override_attributes": {
    "axonops": {
      "deployment_mode": "self-hosted",
      "server": {
        "enabled": true,
        "listen_address": "0.0.0.0"
      },
      "dashboard": {
        "enabled": true,
        "listen_address": "0.0.0.0"
      }
    }
  }
}
```

### Server Node Recipe

```ruby
# recipes/axonops_server.rb
node.override['axonops']['deployment_mode'] = 'self-hosted'

# Install dependencies
include_recipe 'axonops::java'
include_recipe 'axonops::elasticsearch'

# Install AxonOps server components
include_recipe 'axonops::server'
include_recipe 'axonops::dashboard'

# Configure API access
include_recipe 'axonops::configure_api'
```

### Application Node Recipe

```ruby
# recipes/cassandra_app.rb
# Install Cassandra with AxonOps monitoring
include_recipe 'axonops::java'
include_recipe 'axonops::cassandra'

# Configure agent for self-hosted server
node.override['axonops']['agent']['hosts'] = 'axonops-server.internal'
node.override['axonops']['agent']['port'] = 8080
include_recipe 'axonops::agent'
```

---

## Production Cassandra Cluster

Three-node Cassandra cluster with optimized settings.

### Base Attributes (attributes/production_cassandra.rb)

```ruby
# Cluster configuration
override['cassandra']['cluster_name'] = 'ProductionCluster'
override['cassandra']['endpoint_snitch'] = 'GossipingPropertyFileSnitch'

# Performance tuning
override['cassandra']['heap_size'] = '16G'
override['cassandra']['concurrent_reads'] = 64
override['cassandra']['concurrent_writes'] = 64
override['cassandra']['compaction_throughput_mb_per_sec'] = 32

# Directory configuration
override['cassandra']['data_root'] = '/data/cassandra'
override['cassandra']['directories']['data'] = [
  '/data/cassandra/data1',
  '/data/cassandra/data2',
  '/data/cassandra/data3'
]
override['cassandra']['directories']['commitlog'] = '/commitlog/cassandra'
override['cassandra']['directories']['logs'] = '/var/log/cassandra'

# AxonOps monitoring
override['axonops']['agent']['enabled'] = true
override['axonops']['java_agent']['enabled'] = true
```

### Node-Specific Configuration

```ruby
# Node 1 (seed)
node.override['cassandra']['listen_address'] = '10.0.1.10'
node.override['cassandra']['rpc_address'] = '10.0.1.10'
node.override['cassandra']['seeds'] = ['10.0.1.10', '10.0.1.11']
node.override['cassandra']['dc'] = 'us-east'
node.override['cassandra']['rack'] = 'rack1'

# Node 2 (seed)
node.override['cassandra']['listen_address'] = '10.0.1.11'
node.override['cassandra']['rpc_address'] = '10.0.1.11'
node.override['cassandra']['seeds'] = ['10.0.1.10', '10.0.1.11']
node.override['cassandra']['dc'] = 'us-east'
node.override['cassandra']['rack'] = 'rack2'

# Node 3
node.override['cassandra']['listen_address'] = '10.0.1.12'
node.override['cassandra']['rpc_address'] = '10.0.1.12'
node.override['cassandra']['seeds'] = ['10.0.1.10', '10.0.1.11']
node.override['cassandra']['dc'] = 'us-east'
node.override['cassandra']['rack'] = 'rack3'
```

---

## Multi-Datacenter Setup

Cassandra cluster spanning multiple datacenters.

### DC1 Configuration (US-East)

```ruby
# attributes/dc1.rb
override['cassandra']['endpoint_snitch'] = 'GossipingPropertyFileSnitch'
override['cassandra']['dc'] = 'us-east-1'
override['cassandra']['prefer_local'] = true

# Seeds from both DCs
override['cassandra']['seeds'] = [
  '10.0.1.10',   # DC1 seed
  '10.0.1.11',   # DC1 seed
  '10.1.1.10',   # DC2 seed
  '10.1.1.11'    # DC2 seed
]

# AxonOps configuration for DC1
override['axonops']['agent']['hosts'] = 'axonops-dc1.internal'
```

### DC2 Configuration (US-West)

```ruby
# attributes/dc2.rb
override['cassandra']['endpoint_snitch'] = 'GossipingPropertyFileSnitch'
override['cassandra']['dc'] = 'us-west-1'
override['cassandra']['prefer_local'] = true

# Same seeds as DC1
override['cassandra']['seeds'] = [
  '10.0.1.10',   # DC1 seed
  '10.0.1.11',   # DC1 seed
  '10.1.1.10',   # DC2 seed
  '10.1.1.11'    # DC2 seed
]

# AxonOps configuration for DC2
override['axonops']['agent']['hosts'] = 'axonops-dc2.internal'
```

### Cassandra-rackdc.properties Template

```properties
# This will be auto-generated by the cookbook
dc=<%= node['cassandra']['dc'] %>
rack=<%= node['cassandra']['rack'] %>
prefer_local=<%= node['cassandra']['prefer_local'] %>
```

---

## Offline/Airgapped Installation

Deploy AxonOps without internet access.

### Preparation (On Internet-Connected Machine)

```bash
# Download all required packages
cd axonops/scripts
./download_offline_packages.py --all --output-dir ../offline_packages
```

### Offline Deployment Recipe

```ruby
# recipes/offline_deploy.rb
node.override['axonops']['offline_install'] = true
node.override['axonops']['offline_packages_dir'] = '/mnt/packages'

# Disable repository
node.override['axonops']['repository']['enabled'] = false

# Install from local packages
include_recipe 'axonops::java'
include_recipe 'axonops::cassandra'
include_recipe 'axonops::agent'

# For self-hosted
if node['axonops']['deployment_mode'] == 'self-hosted'
  include_recipe 'axonops::elasticsearch'
  include_recipe 'axonops::server'
  include_recipe 'axonops::dashboard'
end
```

### Package Distribution

```ruby
# Copy packages to nodes
remote_directory node['axonops']['offline_packages_dir'] do
  source 'offline_packages'
  owner 'root'
  group 'root'
  mode '0755'
  files_mode '0644'
  action :create
end
```

---

## High Performance Configuration

Optimized for large-scale deployments.

### System Tuning Attributes

```ruby
# attributes/high_performance.rb

# Java settings
override['java']['jdk_version'] = '17'
override['cassandra']['heap_size'] = '32G'
override['cassandra']['heap_newsize'] = '8G'

# Cassandra performance
override['cassandra']['concurrent_reads'] = 128
override['cassandra']['concurrent_writes'] = 128
override['cassandra']['concurrent_compactors'] = 4
override['cassandra']['compaction_throughput_mb_per_sec'] = 64
override['cassandra']['streaming_throughput_mb_per_sec'] = 200

# Use separate disks for different data types
override['cassandra']['directories']['data'] = [
  '/ssd1/cassandra/data',
  '/ssd2/cassandra/data',
  '/ssd3/cassandra/data',
  '/ssd4/cassandra/data'
]
override['cassandra']['directories']['commitlog'] = '/nvme/cassandra/commitlog'

# Network optimization
override['cassandra']['internode_compression'] = 'dc'
override['cassandra']['inter_dc_tcp_nodelay'] = true

# AxonOps agent optimization
override['axonops']['agent']['monitoring_interval'] = 30
override['axonops']['agent']['batch_size'] = 1000
```

### Custom sysctl.conf

```ruby
# Additional kernel tuning
sysctl_param 'net.core.somaxconn' do
  value 65535
end

sysctl_param 'net.ipv4.tcp_max_syn_backlog' do
  value 65535
end

sysctl_param 'vm.dirty_background_ratio' do
  value 5
end

sysctl_param 'vm.dirty_ratio' do
  value 80
end
```

---

## Security Hardened Setup

Production-ready security configuration.

### TLS/SSL Configuration

```ruby
# attributes/security.rb

# Enable SSL for Cassandra
override['cassandra']['client_encryption_options'] = {
  'enabled' => true,
  'optional' => false,
  'keystore' => '/etc/cassandra/certs/keystore.jks',
  'keystore_password' => 'changeme',
  'require_client_auth' => true,
  'truststore' => '/etc/cassandra/certs/truststore.jks',
  'truststore_password' => 'changeme'
}

override['cassandra']['server_encryption_options'] = {
  'internode_encryption' => 'all',
  'keystore' => '/etc/cassandra/certs/keystore.jks',
  'keystore_password' => 'changeme',
  'truststore' => '/etc/cassandra/certs/truststore.jks',
  'truststore_password' => 'changeme'
}

# Enable authentication
override['cassandra']['authenticator'] = 'PasswordAuthenticator'
override['cassandra']['authorizer'] = 'CassandraAuthorizer'

# AxonOps SSL configuration
override['axonops']['agent']['ssl'] = true
override['axonops']['agent']['ssl_verify'] = true
override['axonops']['agent']['ssl_ca_cert'] = '/etc/axonops/certs/ca.crt'
override['axonops']['agent']['ssl_client_cert'] = '/etc/axonops/certs/client.crt'
override['axonops']['agent']['ssl_client_key'] = '/etc/axonops/certs/client.key'
```

### Firewall Rules

```ruby
# Configure firewall
include_recipe 'firewall::default'

# Cassandra ports
firewall_rule 'cassandra-cql' do
  port 9042
  source '10.0.0.0/8'
  action :create
end

firewall_rule 'cassandra-internode' do
  port 7000
  source '10.0.0.0/8'
  action :create
end

# AxonOps ports (self-hosted)
firewall_rule 'axonops-api' do
  port 8080
  source '10.0.0.0/8'
  action :create
  only_if { node['axonops']['deployment_mode'] == 'self-hosted' }
end

# Block all other traffic
firewall 'default' do
  action :install
end
```

### Secrets Management

```ruby
# Use Chef Vault for sensitive data
chef_gem 'chef-vault' do
  compile_time true
end

require 'chef-vault'

# Retrieve secrets
api_key = ChefVault::Item.load('axonops', 'api_key')[node.chef_environment]
ssl_password = ChefVault::Item.load('cassandra', 'ssl_passwords')[node.chef_environment]

# Apply secrets
node.override['axonops']['api']['key'] = api_key
node.override['cassandra']['client_encryption_options']['keystore_password'] = ssl_password
```

---

## Alert Configuration Examples

### Critical Alerts Setup

```ruby
# Define alert rules via API
axonops_alert_rule 'high_cpu' do
  cluster 'production'
  metric 'system.cpu.usage'
  threshold 90
  duration '5m'
  severity 'critical'
  enabled true
  action :create
end

axonops_alert_rule 'disk_space' do
  cluster 'production'
  metric 'system.disk.usage'
  threshold 85
  duration '10m'
  severity 'warning'
  enabled true
  action :create
end

# Configure notification channels
axonops_notification 'slack_critical' do
  type 'slack'
  webhook_url 'https://hooks.slack.com/services/xxx/yyy/zzz'
  channel '#alerts-critical'
  events ['critical']
  action :create
end

axonops_notification 'pagerduty_oncall' do
  type 'pagerduty'
  integration_key 'your-integration-key'
  severity_filter ['critical']
  action :create
end
```

---

## Backup Configuration

### Automated Backup Setup

```ruby
# Configure S3 backup
axonops_backup_config 'daily_backup' do
  cluster 'production'
  type 's3'
  schedule '0 2 * * *'  # 2 AM daily
  retention_days 30
  s3_bucket 'company-cassandra-backups'
  s3_region 'us-east-1'
  s3_access_key_id 'AKIAXXXXXXXX'
  s3_secret_access_key 'secret'
  incremental true
  action :create
end

# Local backup for development
axonops_backup_config 'dev_backup' do
  cluster 'development'
  type 'local'
  schedule '0 */6 * * *'  # Every 6 hours
  retention_days 7
  local_path '/backups/cassandra'
  action :create
end
```