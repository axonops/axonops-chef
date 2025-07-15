# AxonOps Chef Cookbook - Default Configurations Guide

This document provides comprehensive information about all default configurations used by the AxonOps Chef cookbook. These defaults can be overridden using Chef attributes.

## Table of Contents

1. [AxonOps Agent Defaults](#axonops-agent-defaults)
2. [AxonOps Server Defaults](#axonops-server-defaults)
3. [AxonOps Dashboard Defaults](#axonops-dashboard-defaults)
4. [Apache Cassandra Defaults](#apache-cassandra-defaults)
5. [Elasticsearch Defaults](#elasticsearch-defaults)
6. [Java (Azul Zulu) Defaults](#java-azul-zulu-defaults)
7. [System Configuration Defaults](#system-configuration-defaults)

---

## AxonOps Agent Defaults

The AxonOps agent monitors Cassandra nodes and reports metrics to the AxonOps server.

### Default Attributes

```ruby
# Agent version
default['axonops']['agent']['version'] = 'latest'

# User and group
default['axonops']['agent']['user'] = 'axonops'
default['axonops']['agent']['group'] = 'axonops'

# Connection settings (SaaS mode by default)
default['axonops']['agent']['hosts'] = 'agents.axonops.cloud'
default['axonops']['agent']['port'] = 443

# Agent behavior
default['axonops']['agent']['disable_command_exec'] = false

# Cassandra detection (auto-detected if nil)
default['axonops']['agent']['cassandra_home'] = nil
default['axonops']['agent']['cassandra_config'] = nil

# Java agent
default['axonops']['java_agent']['version'] = '1.0.10'
default['axonops']['java_agent']['package'] = 'axon-cassandra5.0-agent-jdk17'
default['axonops']['java_agent']['jar_path'] = '/usr/share/axonops/axon-cassandra-agent.jar'
```

### Generated Configuration File: `/etc/axonops/axon-agent.yml`

```yaml
agent:
  name: "hostname"  # Automatically set to node hostname
  
server:
  hosts: ["agents.axonops.cloud:443"]  # Or self-hosted server
  
cassandra:
  hosts: ["localhost:9042"]
  jmx_host: localhost
  jmx_port: 7199
  
monitoring:
  interval: 60
  
logging:
  level: INFO
  file: /var/log/axonops/agent.log
```

### Directory Structure

- `/etc/axonops/` - Configuration files (owner: axonops:axonops, mode: 0755)
- `/var/log/axonops/` - Log files (owner: axonops:axonops, mode: 0755)
- `/var/lib/axonops/` - Data files (owner: axonops:axonops, mode: 0755)
- `/usr/share/axonops/` - Application files (owner: axonops:axonops, mode: 0755)

---

## AxonOps Server Defaults

The AxonOps server collects metrics from agents and provides the API for the dashboard.

### Default Attributes

```ruby
# Server version
default['axonops']['server']['version'] = 'latest'
default['axonops']['server']['package'] = 'axon-server'

# Network settings
default['axonops']['server']['listen_address'] = '0.0.0.0'
default['axonops']['server']['listen_port'] = 8080

# Storage backend
default['axonops']['server']['elasticsearch']['install'] = true
default['axonops']['server']['elasticsearch']['url'] = 'http://127.0.0.1:9200'

# Metrics storage (Cassandra)
default['axonops']['server']['cassandra']['install'] = true
default['axonops']['server']['cassandra']['hosts'] = ['127.0.0.1']
```

### Generated Configuration File: `/etc/axonops/axon-server.yml`

```yaml
server:
  listen_address: 0.0.0.0
  listen_port: 8080
  
storage:
  type: elasticsearch
  elasticsearch:
    hosts: ["http://localhost:9200"]
    index_prefix: axonops
  
cassandra_data:
  hosts: ["localhost:9042"]
  keyspace: axonops_data
  
api:
  enabled: true
  cors:
    enabled: true
    allowed_origins: ["*"]
    
auth:
  enabled: false  # Enable for production
  
logging:
  level: INFO
  file: /var/log/axonops/server.log
```

---

## AxonOps Dashboard Defaults

The dashboard provides the web UI for AxonOps.

### Default Attributes

```ruby
# Dashboard version
default['axonops']['dashboard']['version'] = 'latest'

# Network settings
default['axonops']['dashboard']['listen_address'] = '127.0.0.1'
default['axonops']['dashboard']['listen_port'] = 3000
```

### Generated Configuration File: `/etc/axonops/axon-dash.yml`

```yaml
dashboard:
  listen_address: 0.0.0.0
  listen_port: 3000
  server_endpoint: http://localhost:8080
  
ui:
  title: "AxonOps Dashboard"
  refresh_interval: 5000
  
logging:
  level: INFO
  file: /var/log/axonops/dashboard.log
```

---

## Apache Cassandra Defaults

When installing Cassandra for application use or AxonOps metrics storage.

### Default Attributes

```ruby
# Cassandra version
default['cassandra']['version'] = '5.0.4'
default['cassandra']['download_url'] = nil  # Auto-generated

# Installation paths
default['cassandra']['install_dir'] = '/opt/cassandra'
default['cassandra']['data_root'] = '/data/cassandra'

# Cluster configuration
default['cassandra']['cluster_name'] = 'Test Cluster'
default['cassandra']['dc'] = 'dc1'
default['cassandra']['rack'] = 'rack1'

# Network
default['cassandra']['listen_address'] = node['ipaddress']
default['cassandra']['rpc_address'] = node['ipaddress']
default['cassandra']['seeds'] = [node['ipaddress']]

# Ports
default['cassandra']['storage_port'] = 7000
default['cassandra']['ssl_storage_port'] = 7001
default['cassandra']['native_transport_port'] = 9042
default['cassandra']['jmx_port'] = 7199

# Directories
default['cassandra']['directories']['data'] = ["#{node['cassandra']['data_root']}/data"]
default['cassandra']['directories']['commitlog'] = "#{node['cassandra']['data_root']}/commitlog"
default['cassandra']['directories']['saved_caches'] = "#{node['cassandra']['data_root']}/saved_caches"
default['cassandra']['directories']['hints'] = "#{node['cassandra']['data_root']}/hints"
default['cassandra']['directories']['logs'] = '/var/log/cassandra'

# Memory settings (auto-calculated if nil)
default['cassandra']['heap_size'] = nil
default['cassandra']['heap_newsize'] = nil

# User and group
default['cassandra']['user'] = 'cassandra'
default['cassandra']['group'] = 'cassandra'
```

### Generated Configuration Files

#### `/opt/cassandra/conf/cassandra.yaml`

```yaml
cluster_name: 'Test Cluster'
num_tokens: 16
allocate_tokens_for_local_replication_factor: 3

seed_provider:
  - class_name: org.apache.cassandra.locator.SimpleSeedProvider
    parameters:
      - seeds: "127.0.0.1"

listen_address: 10.0.2.15
rpc_address: 10.0.2.15
native_transport_port: 9042

data_file_directories:
  - /data/cassandra/data

commitlog_directory: /data/cassandra/commitlog
saved_caches_directory: /data/cassandra/saved_caches
hints_directory: /data/cassandra/hints

endpoint_snitch: SimpleSnitch
```

#### `/opt/cassandra/conf/jvm-server.options`

```bash
# Heap size (automatically calculated as 1/4 of system RAM, max 8GB)
-Xms2G
-Xmx2G

# G1GC Settings
-XX:+UseG1GC
-XX:MaxGCPauseMillis=300

# GC logging
-Xlog:gc=info,heap*=trace,age*=debug,safepoint=info,promotion*=trace:file=/var/log/cassandra/gc.log:time,uptime,pid,tid,level:filecount=10,filesize=10485760

# AxonOps Java Agent (if installed)
-javaagent:/usr/share/axonops/axon-cassandra-agent.jar
```

---

## Elasticsearch Defaults

Used for AxonOps data storage and search functionality.

### Default Attributes

```ruby
# Version (only 7.x supported)
default['axonops']['elasticsearch']['version'] = '7.17.26'

# Installation
default['axonops']['elasticsearch']['install_method'] = 'tarball'
default['axonops']['elasticsearch']['install_dir'] = '/opt/elasticsearch'

# Configuration
default['axonops']['elasticsearch']['cluster_name'] = 'axonops-search'
default['axonops']['elasticsearch']['node_name'] = node['hostname']

# Network
default['axonops']['elasticsearch']['network_host'] = '127.0.0.1'
default['axonops']['elasticsearch']['http_port'] = 9200
default['axonops']['elasticsearch']['transport_port'] = 9300

# Paths
default['axonops']['elasticsearch']['path_data'] = '/var/lib/elasticsearch'
default['axonops']['elasticsearch']['path_logs'] = '/var/log/elasticsearch'

# Memory (auto-calculated as 1/2 of system RAM, max 32GB)
default['axonops']['elasticsearch']['heap_size'] = nil
```

### Generated Configuration File: `/opt/elasticsearch/config/elasticsearch.yml`

```yaml
cluster.name: axonops-search
node.name: hostname

network.host: 127.0.0.1
http.port: 9200

path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch

discovery.type: single-node

# Security disabled for local development
xpack.security.enabled: false
```

### JVM Options: `/opt/elasticsearch/config/jvm.options`

```bash
# Heap size (auto-calculated)
-Xms2g
-Xmx2g

# Use G1GC
-XX:+UseG1GC
```

---

## Java (Azul Zulu) Defaults

### Default Attributes

```ruby
# Java version
default['java']['jdk_version'] = '17'
default['java']['install_flavor'] = 'zulu'

# Installation method
default['java']['install_from_package'] = false  # Use tarball

# Paths
default['java']['java_home'] = '/opt/java'
```

### Environment Variables Set

- `JAVA_HOME=/opt/java`
- `PATH` includes `/opt/java/bin`

---

## System Configuration Defaults

### Security Limits: `/etc/security/limits.d/axonops.conf`

```bash
# For AxonOps user
axonops soft nofile 65536
axonops hard nofile 65536
axonops soft nproc 32768
axonops hard nproc 32768
axonops soft memlock unlimited
axonops hard memlock unlimited

# For Cassandra user
cassandra soft nofile 100000
cassandra hard nofile 100000
cassandra soft nproc 32768
cassandra hard nproc 32768
cassandra soft memlock unlimited
cassandra hard memlock unlimited
```

### Sysctl Settings: `/etc/sysctl.d/99-axonops.conf`

```bash
# AxonOps recommended settings
vm.max_map_count=1048575
net.ipv4.tcp_keepalive_time=60
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_keepalive_intvl=10

# For Cassandra performance
vm.swappiness=1
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.core.rmem_default=16777216
net.core.wmem_default=16777216
net.core.optmem_max=40960
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 65536 134217728
```

---

## Deployment Modes

### SaaS Mode (Default)

```ruby
default['axonops']['deployment_mode'] = 'saas'
default['axonops']['agent']['hosts'] = 'agents.axonops.cloud'
default['axonops']['agent']['port'] = 443
default['axonops']['api']['key'] = nil  # Must be provided
default['axonops']['api']['organization'] = nil  # Must be provided
```

### Self-Hosted Mode

```ruby
default['axonops']['deployment_mode'] = 'self-hosted'
default['axonops']['server']['enabled'] = true
default['axonops']['dashboard']['enabled'] = true
default['axonops']['agent']['hosts'] = 'localhost'
default['axonops']['agent']['port'] = 8080
```

### Offline Installation Mode

```ruby
default['axonops']['offline_install'] = true
default['axonops']['offline_packages_dir'] = '/opt/axonops/offline'
```

---

## Port Summary

| Service | Default Port | Protocol | Purpose |
|---------|-------------|----------|---------|
| AxonOps Server API | 8080 | HTTP | REST API & Agent connections |
| AxonOps Dashboard | 3000 | HTTP | Web UI |
| Elasticsearch | 9200 | HTTP | Search and analytics |
| Elasticsearch Transport | 9300 | TCP | Cluster communication |
| Cassandra CQL | 9042 | TCP | Client connections |
| Cassandra Inter-node | 7000 | TCP | Cluster communication |
| Cassandra JMX | 7199 | TCP | Management and monitoring |

---

## Override Examples

To override any default, set the attribute in your wrapper cookbook or role:

```ruby
# In a wrapper cookbook
node.override['cassandra']['cluster_name'] = 'Production Cluster'
node.override['cassandra']['heap_size'] = '16G'
node.override['axonops']['agent']['hosts'] = 'axonops.mycompany.com'

# In a Chef role
{
  "default_attributes": {
    "axonops": {
      "deployment_mode": "self-hosted",
      "server": {
        "listen_port": 8090
      }
    }
  }
}

# In a Policyfile
default['axonops']['offline_install'] = true
default['elasticsearch']['version'] = '7.17.26'
```