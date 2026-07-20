# AxonOps Chef Cookbook - Project Guide

## Project Overview

Create a comprehensive Chef cookbook for AxonOps that provides flexible, modular installation and configuration of the entire AxonOps ecosystem. This cookbook will be published to Chef Supermarket for community use.

### Target
- Create a modular Chef cookbook with optional components
- Support both SaaS and self-hosted AxonOps deployments
- Publish to Chef Supermarket for easy integration into existing Chef projects

## Key Components

### 1. AxonOps Server Installation (OPTIONAL)
- Install AxonOps server for self-hosted deployments
- Can use existing OpenSearch or install new instance
- Can use existing Cassandra or install new instance for metrics storage
- Support for airgapped environments

### 2. AxonOps Agent Installation
- Install agent on Cassandra nodes to be monitored
- Does NOT reinstall existing Cassandra
- Configures agent to connect to either:
  - Self-hosted AxonOps server
  - AxonOps SaaS (agents.axonops.cloud)

### 3. Apache Cassandra Installation (OPTIONAL)
- Install Apache Cassandra 5 for users who need a new database
- Separate from AxonOps metrics storage Cassandra
- Full configuration management

### 4. AxonOps Configuration via API (CRITICAL)
- Port https://github.com/axonops/axonops-config-automation functionality
- Configure via AxonOps APIs:
  - Alerts and alert rules
  - Service checks
  - Log monitoring
  - Backup configurations
  - Notification channels (Slack, PagerDuty, etc.)
  - SLAs and thresholds
- Works with both self-hosted and SaaS deployments

### 5. Supporting Components (OPTIONAL)
- Java/Zulu JDK installation
- System tuning for Cassandra
- SSL/TLS certificate management

## Key Design Principles

1. **Modularity**: Each component is optional and can be used independently
2. **Flexibility**: Users can bring their own Java, OpenSearch, Cassandra
3. **API-First**: Configuration is done via AxonOps APIs, not config files
4. **Airgapped Support**: Full offline installation capability
5. **Chef Supermarket Ready**: Proper structure for public distribution
6. **Variables**: The configuration variables must be defined under attributes/*.rb to use used in recipes/*.rb; play special care to ensure there are no duplicates and that all variables have meaninful names.

## Usage Examples

### Example 1: Install AxonOps Agent on Existing Cassandra Cluster
```ruby
# Just install the agent, no other components
include_recipe 'axonops::agent'
```

### Example 2: Self-Hosted AxonOps with Existing Infrastructure
```ruby
# Use existing OpenSearch and Cassandra
node.override['axonops']['server']['elastic']['install'] = false
node.override['axonops']['server']['search_db']['hosts'] = ['http://my-opensearch:9200/']
node.override['axonops']['server']['cassandra']['install'] = false
node.override['axonops']['server']['cassandra']['hosts'] = ['my-cassandra-1', 'my-cassandra-2']

include_recipe 'axonops::server'
include_recipe 'axonops::agent'
```

### Example 3: Full Stack Installation
```ruby
# Install everything: Java, OpenSearch, Cassandra metrics DB, AxonOps server, and agent
include_recipe 'axonops::java'
include_recipe 'axonops::server'
include_recipe 'axonops::agent'
include_recipe 'axonops::cassandra'  # Install Apache Cassandra 5 for application use
```

### Example 4: Configure AxonOps via API
```ruby
# Configure alerts, backups, notifications via API
include_recipe 'axonops::configure_api'

# Or use custom resources directly
axonops_alert_rule 'high_cpu_alert' do
  metric 'cpu_usage'
  threshold 90
  duration '5m'
  severity 'critical'
  action :create
end

axonops_notification 'slack_alerts' do
  type 'slack'
  webhook_url 'https://hooks.slack.com/...'
  channel '#alerts'
  action :create
end
```

## Critical Implementation Notes

### 1. API Configuration (from axonops-config-automation)
The cookbook MUST implement all configuration capabilities from https://github.com/axonops/axonops-config-automation:
- Alert rules and routes
- Backup configurations
- Service level agreements
- Log parsing rules
- Notification integrations
- Dashboard configurations

### 2. Agent Installation WITHOUT Cassandra Reinstall
```ruby
# The agent recipe must:
# 1. Detect existing Cassandra installation
# 2. Configure agent to monitor it
# 3. NOT modify the existing Cassandra
# 4. Add Java agent to existing Cassandra JVM options
```

### 3. Modular Design for Chef Supermarket
```ruby
# Users should be able to:
include_recipe 'axonops::agent'  # Just the agent

# OR
include_recipe 'axonops::server'  # Just the server

# OR
include_recipe 'axonops::configure_api'  # Just API configuration

# OR mix and match as needed
```

## Implementation Priorities

1. **First Priority**: Agent installation that works with existing Cassandra
2. **Second Priority**: API configuration resources (alerts, backups, etc.)
3. **Third Priority**: Server installation for self-hosted deployments
4. **Fourth Priority**: Full Cassandra installation for new deployments

## Testing Strategy

1. **Unit Tests**: ChefSpec for all recipes and resources
2. **Integration Tests**: Kitchen tests for:
   - Agent with existing Cassandra
   - Server installation scenarios
   - API configuration
   - Full stack deployment
3. **API Tests**: Verify all API configurations work correctly

## Publishing Requirements

1. **Cookbook Name**: `axonops` (not cassandra-ops!)
2. **Metadata**: Complete with all dependencies clearly documented
3. **Documentation**: Clear README with examples for each use case
4. **License**: Apache 2.0
5. **Testing**: All tests passing
6. **Versioning**: Semantic versioning starting at 0.1.0

## Common Mistakes to Avoid

1. **DO NOT** bundle everything together - keep components modular
2. **DO NOT** assume users want to install Cassandra - many have existing clusters
3. **DO NOT** forget the API configuration - this is CRITICAL functionality
4. **DO NOT** hardcode configurations - use attributes and allow overrides
5. **DO NOT** name it "cassandra-ops" - this is the AxonOps cookbook

## Notes for Implementation

- Start with the agent recipe since it's the most commonly used component
- Study the axonops-config-automation repo carefully for all API endpoints
- Ensure the cookbook works in both online and airgapped environments
- Test with real Cassandra clusters, not just fresh installations
- Make sure custom resources are idempotent and handle errors gracefully
