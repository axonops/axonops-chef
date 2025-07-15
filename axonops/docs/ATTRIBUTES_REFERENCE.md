# AxonOps Chef Cookbook - Attributes Reference

This document provides a complete reference of all attributes available in the AxonOps Chef cookbook.

## Attribute Structure

Attributes are organized hierarchically under the following top-level keys:
- `axonops` - All AxonOps-specific settings
- `cassandra` - Apache Cassandra configuration
- `java` - Java/JDK configuration
- `elasticsearch` - Elasticsearch configuration (internal use)

## AxonOps Attributes

### Global Settings

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['axonops']['deployment_mode']` | String | `'saas'` | Deployment mode: 'saas' or 'self-hosted' |
| `['axonops']['offline_install']` | Boolean | `false` | Enable offline installation from local packages |
| `['axonops']['offline_packages_dir']` | String | `'/opt/axonops/offline'` | Directory containing offline packages |
| `['axonops']['offline_packages_path']` | String | `'/opt/axonops/offline'` | Alias for offline_packages_dir |

### API Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['axonops']['api']['key']` | String | `nil` | API key for SaaS mode (required) |
| `['axonops']['api']['organization']` | String | `nil` | Organization name for SaaS mode (required) |
| `['axonops']['api']['base_url']` | String | `nil` | Override API endpoint URL |

### Agent Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['axonops']['agent']['enabled']` | Boolean | `true` | Enable agent installation |
| `['axonops']['agent']['version']` | String | `'latest'` | Agent version to install |
| `['axonops']['agent']['user']` | String | `'axonops'` | User to run agent as |
| `['axonops']['agent']['group']` | String | `'axonops'` | Group for agent user |
| `['axonops']['agent']['hosts']` | String | `'agents.axonops.cloud'` | AxonOps server hostname(s) |
| `['axonops']['agent']['port']` | Integer | `443` | AxonOps server port |
| `['axonops']['agent']['disable_command_exec']` | Boolean | `false` | Disable remote command execution |
| `['axonops']['agent']['cassandra_home']` | String | `nil` | Cassandra installation directory (auto-detected if nil) |
| `['axonops']['agent']['cassandra_config']` | String | `nil` | Cassandra config directory (auto-detected if nil) |
| `['axonops']['agent']['java_agent']['enabled']` | Boolean | `true` | Enable Java agent for JVM monitoring |

### Java Agent Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['axonops']['java_agent']['version']` | String | `'1.0.10'` | Java agent version |
| `['axonops']['java_agent']['package']` | String | `'axon-cassandra5.0-agent-jdk17'` | Java agent package name |
| `['axonops']['java_agent']['jar_path']` | String | `'/usr/share/axonops/axon-cassandra-agent.jar'` | Installation path for Java agent JAR |

### Server Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['axonops']['server']['enabled']` | Boolean | `false` | Enable server installation (self-hosted mode) |
| `['axonops']['server']['version']` | String | `'latest'` | Server version to install |
| `['axonops']['server']['package']` | String | `'axon-server'` | Server package name |
| `['axonops']['server']['listen_address']` | String | `'0.0.0.0'` | Server listen address |
| `['axonops']['server']['listen_port']` | Integer | `8080` | Server API port |
| `['axonops']['server']['elasticsearch']['install']` | Boolean | `true` | Install Elasticsearch for server |
| `['axonops']['server']['elasticsearch']['url']` | String | `'http://127.0.0.1:9200'` | Elasticsearch URL |
| `['axonops']['server']['cassandra']['install']` | Boolean | `true` | Install Cassandra for metrics storage |
| `['axonops']['server']['cassandra']['hosts']` | Array | `['127.0.0.1']` | Cassandra hosts for metrics |

### Dashboard Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['axonops']['dashboard']['enabled']` | Boolean | `false` | Enable dashboard installation |
| `['axonops']['dashboard']['version']` | String | `'latest'` | Dashboard version to install |
| `['axonops']['dashboard']['listen_address']` | String | `'127.0.0.1'` | Dashboard listen address |
| `['axonops']['dashboard']['listen_port']` | Integer | `3000` | Dashboard web UI port |

### Repository Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['axonops']['repository']['enabled']` | Boolean | `true` | Enable AxonOps repository |
| `['axonops']['repository']['url']` | String | `'https://packages.axonops.com'` | Repository base URL |
| `['axonops']['repository']['beta']` | Boolean | `false` | Enable beta repository |

### Configuration Management (via API)

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['axonops']['alerts']['endpoints']` | Hash | `{}` | Alert endpoint configurations |
| `['axonops']['alerts']['rules']` | Hash | `{}` | Alert rule definitions |
| `['axonops']['alerts']['routes']` | Hash | `{}` | Alert routing configurations |
| `['axonops']['service_checks']` | Hash | `{}` | Service check definitions |
| `['axonops']['backups']` | Hash | `{}` | Backup configurations |
| `['axonops']['log_rules']` | Hash | `{}` | Log parsing rule definitions |

### Package Names (Auto-detected)

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['axonops']['packages']['elasticsearch_tarball']` | String | `nil` | Elasticsearch tarball filename |
| `['axonops']['packages']['cassandra_tarball']` | String | `nil` | Cassandra tarball filename |
| `['axonops']['packages']['java_tarball']` | String | `nil` | Java tarball filename |
| `['axonops']['packages']['agent']` | String | `nil` | Agent package filename |
| `['axonops']['packages']['server']` | String | `nil` | Server package filename |
| `['axonops']['packages']['dashboard']` | String | `nil` | Dashboard package filename |

## Cassandra Attributes

### Basic Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['cassandra']['install']` | Boolean | `false` | Install Apache Cassandra |
| `['cassandra']['version']` | String | `'5.0.4'` | Cassandra version to install |
| `['cassandra']['download_url']` | String | `nil` | Override download URL (auto-generated if nil) |
| `['cassandra']['install_method']` | String | `'tarball'` | Installation method: 'tarball' or 'package' |
| `['cassandra']['force_fresh_install']` | Boolean | `false` | Force fresh installation (removes existing) |

### Paths and Directories

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['cassandra']['install_dir']` | String | `'/opt/cassandra'` | Installation directory |
| `['cassandra']['data_root']` | String | `'/data/cassandra'` | Root directory for data files |
| `['cassandra']['directories']['data']` | Array | `["#{data_root}/data"]` | Data file directories |
| `['cassandra']['directories']['commitlog']` | String | `"#{data_root}/commitlog"` | Commit log directory |
| `['cassandra']['directories']['saved_caches']` | String | `"#{data_root}/saved_caches"` | Saved caches directory |
| `['cassandra']['directories']['hints']` | String | `"#{data_root}/hints"` | Hints directory |
| `['cassandra']['directories']['logs']` | String | `'/var/log/cassandra'` | Log files directory |

### Cluster Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['cassandra']['cluster_name']` | String | `'Test Cluster'` | Cluster name |
| `['cassandra']['dc']` | String | `'dc1'` | Datacenter name |
| `['cassandra']['rack']` | String | `'rack1'` | Rack name |
| `['cassandra']['endpoint_snitch']` | String | `'SimpleSnitch'` | Snitch implementation |

### Network Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['cassandra']['listen_address']` | String | `node['ipaddress']` | Address to bind for internal communication |
| `['cassandra']['rpc_address']` | String | `node['ipaddress']` | Address to bind for client connections |
| `['cassandra']['broadcast_address']` | String | `nil` | Public IP for cross-DC communication |
| `['cassandra']['broadcast_rpc_address']` | String | `nil` | Public IP for client connections |
| `['cassandra']['seeds']` | Array | `[node['ipaddress']]` | Seed node addresses |

### Port Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['cassandra']['storage_port']` | Integer | `7000` | Inter-node communication port |
| `['cassandra']['ssl_storage_port']` | Integer | `7001` | SSL inter-node communication port |
| `['cassandra']['native_transport_port']` | Integer | `9042` | CQL native transport port |
| `['cassandra']['jmx_port']` | Integer | `7199` | JMX monitoring port |

### Memory Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['cassandra']['heap_size']` | String | `nil` | JVM heap size (auto-calculated if nil) |
| `['cassandra']['heap_newsize']` | String | `nil` | JVM new generation size (auto-calculated if nil) |
| `['cassandra']['heap_size_mb']` | Integer | calculated | Calculated heap size in MB |
| `['cassandra']['heap_newsize_mb']` | Integer | calculated | Calculated new size in MB |

### User and Permissions

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['cassandra']['user']` | String | `'cassandra'` | User to run Cassandra as |
| `['cassandra']['group']` | String | `'cassandra'` | Group for Cassandra user |

### Performance Tuning

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['cassandra']['concurrent_reads']` | Integer | `32` | Concurrent read threads |
| `['cassandra']['concurrent_writes']` | Integer | `32` | Concurrent write threads |
| `['cassandra']['concurrent_compactors']` | Integer | `nil` | Concurrent compaction threads |
| `['cassandra']['compaction_throughput_mb_per_sec']` | Integer | `16` | Compaction throughput limit |

## Java Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['java']['jdk_version']` | String | `'17'` | JDK version to install |
| `['java']['install_flavor']` | String | `'zulu'` | JDK distribution: 'zulu', 'openjdk', etc. |
| `['java']['install_from_package']` | Boolean | `false` | Install from package (true) or tarball (false) |
| `['java']['java_home']` | String | `'/opt/java'` | JAVA_HOME directory |
| `['java']['set_etc_environment']` | Boolean | `true` | Set JAVA_HOME in /etc/environment |

## Elasticsearch Attributes

### Version and Installation

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['axonops']['elasticsearch']['version']` | String | `'7.17.26'` | Elasticsearch version (7.x only) |
| `['axonops']['elasticsearch']['install_method']` | String | `'tarball'` | Installation method |
| `['axonops']['elasticsearch']['install_dir']` | String | `'/opt/elasticsearch'` | Installation directory |

### Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['axonops']['elasticsearch']['cluster_name']` | String | `'axonops-search'` | Cluster name |
| `['axonops']['elasticsearch']['node_name']` | String | `node['hostname']` | Node name |
| `['axonops']['elasticsearch']['network_host']` | String | `'127.0.0.1'` | Network bind address |
| `['axonops']['elasticsearch']['http_port']` | Integer | `9200` | HTTP API port |
| `['axonops']['elasticsearch']['transport_port']` | Integer | `9300` | Transport port |

### Paths and Memory

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['axonops']['elasticsearch']['path_data']` | String | `'/var/lib/elasticsearch'` | Data directory |
| `['axonops']['elasticsearch']['path_logs']` | String | `'/var/log/elasticsearch'` | Log directory |
| `['axonops']['elasticsearch']['heap_size']` | String | `nil` | Heap size (auto-calculated if nil) |

## Multi-Node Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `['axonops']['multi_node']['role']` | String | `nil` | Node role: 'server' or 'cassandra' |
| `['axonops']['multi_node']['server_ip']` | String | `nil` | AxonOps server IP for multi-node setups |

## Usage Examples

### Override in Wrapper Cookbook

```ruby
# In attributes/default.rb
override['axonops']['deployment_mode'] = 'self-hosted'
override['axonops']['server']['enabled'] = true
override['cassandra']['cluster_name'] = 'Production'
override['cassandra']['heap_size'] = '8G'
```

### Override in Environment

```json
{
  "name": "production",
  "override_attributes": {
    "axonops": {
      "agent": {
        "hosts": "axonops.internal.company.com",
        "port": 8080
      }
    },
    "cassandra": {
      "dc": "us-east-1",
      "rack": "rack1"
    }
  }
}
```

### Override in Node

```json
{
  "name": "cassandra-node-01",
  "normal": {
    "cassandra": {
      "listen_address": "10.0.1.10",
      "seeds": ["10.0.1.10", "10.0.1.11", "10.0.1.12"]
    }
  }
}
```