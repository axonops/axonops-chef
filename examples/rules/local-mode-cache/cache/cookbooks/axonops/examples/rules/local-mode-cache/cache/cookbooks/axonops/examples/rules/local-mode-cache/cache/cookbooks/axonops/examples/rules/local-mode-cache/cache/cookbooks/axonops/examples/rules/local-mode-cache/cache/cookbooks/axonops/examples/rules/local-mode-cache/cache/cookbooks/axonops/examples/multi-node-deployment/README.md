# Multi-Node AxonOps Deployment Example

This example demonstrates a realistic multi-node deployment of AxonOps monitoring a separate Apache Cassandra cluster.

## Architecture

```
┌─────────────────────────┐         ┌─────────────────────────┐
│   AxonOps Server VM     │         │   Cassandra App VM      │
│   (192.168.56.10)       │         │   (192.168.56.20)       │
├─────────────────────────┤         ├─────────────────────────┤
│ • AxonOps Server (:8080)│◄────────┤ • Apache Cassandra 5.0  │
│ • AxonOps Dashboard     │         │ • AxonOps Agent         │
│   (:3000)               │         │   (monitors local       │
│ • Elasticsearch (:9200) │         │    Cassandra)           │
│ • Cassandra for metrics │         │                         │
│   (:9042)               │         │                         │
└─────────────────────────┘         └─────────────────────────┘
```

## Prerequisites

1. Vagrant and VirtualBox installed
2. At least 8GB RAM available (4GB for AxonOps VM, 2GB for Cassandra VM)
3. Chef Workstation installed

## Quick Start

1. **Clone this cookbook**:
   ```bash
   git clone https://github.com/axonops/axonops-chef.git
   cd axonops-chef
   ```

2. **Install dependencies**:
   ```bash
   bundle install
   ```

3. **Launch the multi-node environment**:
   ```bash
   cd examples/multi-node-deployment
   vagrant up
   ```

   Or using Test Kitchen:
   ```bash
   KITCHEN_YAML=.kitchen.multi-node.yml kitchen create
   KITCHEN_YAML=.kitchen.multi-node.yml kitchen converge
   ```

4. **Verify the deployment**:
   - AxonOps Dashboard: http://192.168.56.10:3000
   - AxonOps API: http://192.168.56.10:8080
   - Cassandra CQL: 192.168.56.20:9042

## Manual Deployment Steps

If you prefer to deploy manually or adapt this to your environment:

### 1. AxonOps Server Node

```ruby
# In your Chef recipe or role
node.override['axonops']['deployment_mode'] = 'self-hosted'
node.override['axonops']['server']['enabled'] = true
node.override['axonops']['server']['listen_address'] = '0.0.0.0'
node.override['axonops']['dashboard']['enabled'] = true

# Include the recipes
include_recipe 'axonops::elasticsearch'  # Storage backend
include_recipe 'axonops::server'         # API server
include_recipe 'axonops::dashboard'      # Web UI
```

### 2. Cassandra Application Node

```ruby
# ⚠️ WARNING: Only for fresh installations!
node.override['cassandra']['install'] = true
node.override['cassandra']['cluster_name'] = 'My Application Cluster'
node.override['cassandra']['seeds'] = ['192.168.56.20']

# Configure AxonOps agent
node.override['axonops']['agent']['enabled'] = true
node.override['axonops']['api']['url'] = 'http://192.168.56.10:8080'

# Include the recipes
include_recipe 'axonops::cassandra'  # Install Cassandra 5.0
include_recipe 'axonops::agent'      # Install monitoring agent
```

## Verification Steps

### 1. Check AxonOps Server

SSH into the AxonOps server:
```bash
vagrant ssh axonops-server
# or
KITCHEN_YAML=.kitchen.multi-node.yml kitchen login axonops-server
```

Verify services:
```bash
# Check all services are running
systemctl status elasticsearch
systemctl status cassandra
systemctl status axon-server
systemctl status axon-dash

# Check API health
curl http://localhost:8080/api/v1/health

# Check for connected agents
curl http://localhost:8080/api/v1/agents
```

### 2. Check Cassandra Node

SSH into the Cassandra node:
```bash
vagrant ssh cassandra-app
# or
KITCHEN_YAML=.kitchen.multi-node.yml kitchen login cassandra-app
```

Verify Cassandra and agent:
```bash
# Check Cassandra status
nodetool status
cqlsh -e "DESCRIBE KEYSPACES"

# Check agent is running
systemctl status axon-agent

# Check agent logs
tail -f /var/log/axonops/agent.log

# Verify agent can reach server
curl http://192.168.56.10:8080/api/v1/health
```

### 3. Test Monitoring

1. Generate some load on Cassandra:
   ```bash
   # On Cassandra node
   cassandra-stress write n=10000
   ```

2. Check metrics in AxonOps:
   - Open http://192.168.56.10:3000 in your browser
   - Navigate to the Clusters view
   - You should see your Cassandra node reporting metrics

## Configuration Options

### Network Configuration

To use different IP addresses, update:
- `.kitchen.multi-node.yml` for Test Kitchen
- `Vagrantfile` for direct Vagrant usage
- Recipe attributes for Chef runs

### Adding More Cassandra Nodes

To create a multi-node Cassandra cluster:

1. Add more suites in `.kitchen.multi-node.yml`:
   ```yaml
   - name: cassandra-app2
     driver:
       network:
         - ["private_network", {ip: "192.168.56.21"}]
     attributes:
       cassandra:
         seeds: ["192.168.56.20", "192.168.56.21"]
   ```

2. Update seed lists on all nodes

3. Ensure all nodes point to the same AxonOps server

## Production Considerations

This example uses:
- Static IPs for simplicity
- Disabled authentication for testing
- Mock binaries for some components

For production:
1. Use proper service discovery or DNS
2. Enable authentication on all services
3. Use SSL/TLS for all connections
4. Install real AxonOps binaries
5. Configure proper backup locations
6. Set up alerting endpoints

## Troubleshooting

### Nodes can't communicate
- Check firewall rules allow ports: 8080, 3000, 9042, 9200
- Verify network connectivity: `ping 192.168.56.10`
- Check service bind addresses are not localhost-only

### Agent not reporting
- Check agent logs: `/var/log/axonops/agent.log`
- Verify server URL in agent config
- Ensure Cassandra JMX is accessible

### Cassandra won't start
- Check for existing installation (this cookbook is for fresh installs only)
- Verify Java 17 is installed
- Check system resources (RAM, disk space)

## Clean Up

To destroy the test environment:
```bash
KITCHEN_YAML=.kitchen.multi-node.yml kitchen destroy
# or
vagrant destroy -f
```