# Apache Cassandra Installation Guide

This guide covers installation and configuration of Apache Cassandra using the AxonOps Chef cookbook. The cookbook supports **3.11.x, 4.1.x, and 5.0.x** and selects the correct Java version automatically.

## Table of Contents

- [Version Support Matrix](#version-support-matrix)
- [Install Method](#install-method)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Version-Specific Examples](#version-specific-examples)
- [Configuration Reference](#configuration-reference)
  - [Recipe Options](#recipe-options)
  - [Cluster Configuration](#cluster-configuration)
  - [Network Configuration](#network-configuration)
  - [Performance Tuning](#performance-tuning)
  - [Security Configuration](#security-configuration)
  - [Storage Configuration](#storage-configuration)
  - [JVM Configuration](#jvm-configuration)
  - [Logging Configuration](#logging-configuration)
  - [System Tuning](#system-tuning)
- [Advanced Configurations](#advanced-configurations)
- [cqlsh on Python 3.12+ hosts](#cqlsh-on-python-312-hosts)
- [SSL Caveat](#ssl-caveat)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)

---

## Version Support Matrix

| Cassandra version | Java major | `cassandra.yaml` schema | JVM option files |
|-------------------|------------|-------------------------|------------------|
| 3.11.x | 8 (Zulu/OpenJDK) | Legacy: integer `*_in_ms` / `*_in_mb` / `*_in_kb` keys, Thrift/RPC keys, megabit streaming | `jvm.options` |
| 4.1.x | 11 (Zulu/OpenJDK) | Modern: string-unit values (`32MiB`, `5000ms`, …) | `jvm-server.options` + `jvm11-server.options` |
| 5.0.x | 17 (Zulu/OpenJDK) | Modern (same as 4.1) | `jvm-server.options` + `jvm17-server.options` |

The version is selected via the `node['axonops']['cassandra']['version']` attribute (default: `5.0.5`).

### Java version selection

The `axonops::cassandra` recipe reads the `version` attribute at converge time and overrides `node['java']['version']` automatically:

- `3.11.*` → Java 8
- `4.1.*`  → Java 11
- `5.*`    → Java 17

This behaviour is implemented in `libraries/cassandra_version.rb` (`AxonOpsCassandra::java_major`). You can override Java selection by setting `node['java']['version']` explicitly, but this is not recommended unless you are providing your own JDK.

---

## Install Method

Cassandra is installed from a **tarball** downloaded from `https://archive.apache.org/dist/cassandra` (or from a local path for air-gapped installs). Package-repository (apt/yum) install is not implemented yet — see [Roadmap](#roadmap).

---

## Requirements

| Item | Requirement |
|------|-------------|
| Chef Infra Client | 15.0+ |
| OS | Ubuntu 20.04+, Rocky Linux 8+, RHEL 8+, Amazon Linux 2 |
| RAM | Minimum 4 GB; 8 GB+ recommended for production |
| Disk | SSD recommended |
| Network | Access to `archive.apache.org` (or local mirror for air-gapped) |

---

## Quick Start

```ruby
# Install Cassandra 5.0.5 (default) with Java 17
include_recipe 'axonops::cassandra'
```

This:
1. Sets `node['java']['version']` to `17` and installs Zulu 17 (or OpenJDK 17).
2. Downloads and extracts the Cassandra tarball.
3. Renders `cassandra.yaml` and JVM option files.
4. Starts the Cassandra service.

---

## Version-Specific Examples

### Install Cassandra 3.11.x

```ruby
node.override['axonops']['cassandra']['version']      = '3.11.17'
node.override['axonops']['cassandra']['cluster_name'] = 'Legacy Cluster'
node.override['axonops']['cassandra']['heap_size']    = '4G'
node.override['axonops']['cassandra']['gc_type']      = 'G1GC'  # Shenandoah not available in Java 8

# Disable client TLS until a JKS keystore is available (see SSL Caveat)
node.override['axonops']['cassandra']['client_encryption_options'] = {
  'enabled' => false
}

include_recipe 'axonops::cassandra'
```

What happens:
- `AxonOpsCassandra.java_major('3.11.17')` → `8` → Zulu 8 / OpenJDK 8 is installed.
- The legacy `templates/default/3.11/cassandra.yaml.erb` is rendered with integer `*_in_ms`/`*_in_mb`/`*_in_kb` keys and Thrift/RPC keys.
- `jvm.options` (single file) is rendered.

### Install Cassandra 5.0.x (default)

```ruby
node.override['axonops']['cassandra']['version']      = '5.0.5'
node.override['axonops']['cassandra']['cluster_name'] = 'Production Cluster'
node.override['axonops']['cassandra']['heap_size']    = '8G'
node.override['axonops']['cassandra']['gc_type']      = 'Shenandoah'

include_recipe 'axonops::cassandra'
```

What happens:
- Java 17 (Zulu 17 by default) is installed.
- The modern `templates/default/cassandra.yaml.erb` is rendered.
- `jvm-server.options` + `jvm17-server.options` are rendered.

### Install Cassandra 4.1.x

```ruby
node.override['axonops']['cassandra']['version']      = '4.1.5'
node.override['axonops']['cassandra']['cluster_name'] = 'Migration Cluster'
node.override['axonops']['cassandra']['heap_size']    = '8G'

include_recipe 'axonops::cassandra'
```

What happens:
- Java 11 (Zulu 11 by default) is installed.
- The modern `cassandra.yaml` template is rendered.
- `jvm-server.options` + `jvm11-server.options` are rendered.

---

## Configuration Reference

All attributes live under `node['axonops']['cassandra']`.

### Recipe Options

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `version` | String | `'5.0.5'` | Cassandra version to install, e.g. `'3.11.17'`, `'4.1.5'`, `'5.0.5'` |
| `skip_java_install` | Boolean | `false` | Skip Java installation when you manage Java yourself |
| `start_on_boot` | Boolean | `true` | Enable the Cassandra service at boot |
| `wait_for_start` | Boolean | `true` | Block until Cassandra is accepting connections after install |
| `base_url` | String | `'https://archive.apache.org/dist/cassandra'` | Base URL for the tarball download |
| `install_dir` | String | `'/opt'` | Parent directory for the Cassandra tarball extraction |
| `user` | String | `'cassandra'` | OS user that runs Cassandra |
| `group` | String | `'cassandra'` | OS group for Cassandra |

### Cluster Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `cluster_name` | String | `'AxonOps Cluster'` | Name of the Cassandra cluster |
| `num_tokens` | Integer | `16` | Number of vnodes per node |
| `allocate_tokens_for_local_replication_factor` | Integer | `3` | RF used for automatic token allocation |
| `initial_token` | String/nil | `nil` | Manual token; leave `nil` when using vnodes |
| `seeds` | Array | `['127.0.0.1']` | Seed node addresses |
| `endpoint_snitch` | String | `'SimpleSnitch'` | Snitch class |
| `dc` | String | `'dc1'` | Datacenter name (for `GossipingPropertyFileSnitch`) |
| `rack` | String | `'rack1'` | Rack name (for `GossipingPropertyFileSnitch`) |

### Network Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `listen_address` | String | `'localhost'` | Address bound for internode communication |
| `rpc_address` | String | `'localhost'` | Address bound for client (CQL) connections |
| `broadcast_address` | String/nil | `nil` | Address broadcast to other nodes |
| `broadcast_rpc_address` | String/nil | `nil` | Address broadcast for client connections |
| `storage_port` | Integer | `7000` | Internode communication port |
| `ssl_storage_port` | Integer | `7001` | TLS internode port |
| `native_transport_port` | Integer | `9042` | CQL port |
| `jmx_port` | Integer | `7199` | JMX port |

### Performance Tuning

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `concurrent_reads` | Integer | `32` | Concurrent read threads |
| `concurrent_writes` | Integer | `32` | Concurrent write threads |
| `concurrent_counter_writes` | Integer | `32` | Concurrent counter write threads |
| `compaction_throughput` | String | `'64MiB/s'` | Compaction throughput limit |
| `stream_throughput_outbound` | String | `'24MiB/s'` | Outbound streaming throughput |
| `memtable_allocation_type` | String | `'heap_buffers'` | Memtable allocation strategy |

### Security Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `authenticator` | String | `'PasswordAuthenticator'` | Authentication backend |
| `authorizer` | String | `'CassandraAuthorizer'` | Authorization backend |
| `role_manager` | String | `'CassandraRoleManager'` | Role management backend |
| `network_authorizer` | String | `'AllowAllNetworkAuthorizer'` | Network authorization |
| `permissions_validity` | String | `'2000ms'` | Permissions cache TTL |
| `roles_validity` | String | `'2000ms'` | Roles cache TTL |
| `credentials_validity` | String | `'2000ms'` | Credentials cache TTL |

#### Server encryption (node-to-node)

```ruby
node.override['axonops']['cassandra']['server_encryption_options'] = {
  'internode_encryption' => 'all',          # none | dc | rack | all
  'keystore'             => '/opt/cassandra/conf/keystore.jks',
  'keystore_password'    => 'your_keystore_password',
  'truststore'           => '/opt/cassandra/conf/truststore.jks',
  'truststore_password'  => 'your_truststore_password',
  'protocol'             => 'TLS',
  'accepted_protocols'   => ['TLSv1.2', 'TLSv1.3'],
  'require_client_auth'  => true,
}
```

#### Client encryption (CQL/9042)

```ruby
node.override['axonops']['cassandra']['client_encryption_options'] = {
  'enabled'             => true,
  'keystore'            => '/opt/cassandra/conf/keystore.jks',
  'keystore_password'   => 'your_keystore_password',
  'require_client_auth' => false,
  'protocol'            => 'TLS',
  'accepted_protocols'  => ['TLSv1.2', 'TLSv1.3'],
}
```

> **See [SSL Caveat](#ssl-caveat) before enabling client encryption.**

### Storage Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `data_file_directories` | Array | `['/var/lib/cassandra/data']` | Data directories |
| `commitlog_directory` | String | `'/var/lib/cassandra/commitlog'` | Commit log directory |
| `hints_directory` | String | `'/var/lib/cassandra/hints'` | Hints directory |
| `saved_caches_directory` | String | `'/var/lib/cassandra/saved_caches'` | Saved caches directory |
| `disk_optimization_strategy` | String | `'ssd'` | `ssd` or `spinning` |
| `commitlog_sync` | String | `'periodic'` | Commit log sync mode |
| `commitlog_sync_period` | String | `'10000ms'` | Commit log sync interval |
| `commitlog_segment_size` | String | `'32MiB'` | Commit log segment size |

### JVM Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `heap_size` | String | `'2G'` | JVM heap (`-Xms` / `-Xmx`) |
| `gc_type` | String | `'Shenandoah'` | GC: `'G1GC'` or `'Shenandoah'` (Shenandoah requires Java 11+; use `G1GC` for 3.11) |
| `gc_g1_heap_region_size` | String | `'16m'` | G1GC region size |
| `gc_g1_max_pause_millis` | Integer | `300` | G1GC max pause target (ms) |
| `gc_g1_initiating_heap_occupancy_percent` | Integer | `70` | G1GC initiating occupancy |
| `gc_shenandoah_heuristics` | String | `'adaptive'` | Shenandoah heuristic mode |
| `local_jmx` | String | `'yes'` | Restrict JMX to localhost |
| `jmx_authentication` | Boolean | `false` | Require JMX credentials |

### Logging Configuration

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `log_level` | String | `'INFO'` | Root log level |
| `log_dir` | String | `'/var/log/cassandra'` | Log directory |
| `gc_log_enabled` | Boolean | `true` | Enable GC logging |
| `gc_log_file_size` | String | `'10M'` | GC log file size |
| `gc_log_files` | Integer | `10` | Number of GC log files to keep |
| `debug_log_enabled` | Boolean | `true` | Write `debug.log` |
| `system_log_level` | String | `'INFO'` | System keyspace log level |
| `cassandra_log_level` | String | `'DEBUG'` | Cassandra package log level |

### System Tuning

```ruby
# Resource limits (written to /etc/security/limits.d/cassandra.conf)
node.override['axonops']['cassandra']['limits'] = {
  'memlock' => 'unlimited',
  'nofile'  => 100000,
  'nproc'   => 32768,
  'as'      => 'unlimited',
}

# Sysctl settings
node.override['axonops']['cassandra']['sysctl'] = {
  'vm.max_map_count'              => 1048575,
  'net.ipv4.tcp_keepalive_time'   => 60,
  'net.ipv4.tcp_keepalive_probes' => 3,
  'net.ipv4.tcp_keepalive_intvl'  => 10,
}
```

---

## Advanced Configurations

### Hinted Handoff

```ruby
node.override['axonops']['cassandra']['hinted_handoff_enabled']      = true
node.override['axonops']['cassandra']['max_hint_window']             = '3h'
node.override['axonops']['cassandra']['hinted_handoff_throttle']     = '1024KiB'
node.override['axonops']['cassandra']['max_hints_delivery_threads']  = 2
```

### Compaction

```ruby
node.override['axonops']['cassandra']['concurrent_compactors']     = 4
node.override['axonops']['cassandra']['compaction_throughput']     = '128MiB/s'
node.override['axonops']['cassandra']['sstable_preemptive_open_interval'] = '50MiB'
```

### Query Timeouts

```ruby
node.override['axonops']['cassandra']['read_request_timeout']  = '5000ms'
node.override['axonops']['cassandra']['write_request_timeout'] = '2000ms'
node.override['axonops']['cassandra']['range_request_timeout'] = '10000ms'
node.override['axonops']['cassandra']['request_timeout']       = '10000ms'
```

### Multi-Datacenter

```ruby
node.override['axonops']['cassandra']['cluster_name']     = 'Global'
node.override['axonops']['cassandra']['endpoint_snitch']  = 'GossipingPropertyFileSnitch'
node.override['axonops']['cassandra']['dc']               = 'us-east-1'
node.override['axonops']['cassandra']['rack']             = 'us-east-1a'
node.override['axonops']['cassandra']['seeds']            = ['10.0.1.10', '10.1.1.10']

include_recipe 'axonops::cassandra'
```

### Change Data Capture

```ruby
node.override['axonops']['cassandra']['cdc_enabled']      = true
node.override['axonops']['cassandra']['cdc_raw_directory'] = '/var/lib/cassandra/cdc_raw'
node.override['axonops']['cassandra']['cdc_total_space']  = '4096MiB'
```

---

## cqlsh on Python 3.12+ hosts

The `cqlsh` shipped inside the Cassandra tarball and the distro package relies on
a Python driver that imports stdlib modules removed in Python 3.12 (`asyncore`,
`imp`). On hosts whose **system Python is >= 3.12 — Ubuntu 24.04+, Debian 13 —
the bundled cqlsh aborts at startup** with an `ImportError`, on both `tar` and
`pkg` installs.

`axonops::cassandra` fixes this automatically: `recipes/cqlsh_venv.rb` provisions
an isolated Python virtualenv with the maintained standalone
[`cqlsh`](https://pypi.org/project/cqlsh/) package (which supports modern Python)
and installs a wrapper at `/usr/local/bin/cqlsh`. Because `/usr/local/bin`
precedes both `$CASSANDRA_HOME/bin` and `/usr/bin` on `PATH`, a plain `cqlsh`
call transparently uses the venv version — the system Python and the bundled
cqlsh are left untouched. This is harmless on Python <= 3.11 (the venv cqlsh
works there too), so it is enabled on all platforms by default.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `cqlsh_venv.enabled` | Boolean | `true` | Provision the cqlsh venv and wrapper |
| `cqlsh_venv.path` | String | `'/opt/cassandra-cqlsh-venv'` | Absolute venv path |
| `cqlsh_venv.python` | String | `'python3'` | Host interpreter used to create the venv |
| `cqlsh_venv.packages` | Array | `['cqlsh']` | pip packages installed into the venv; pin for reproducibility, e.g. `['cqlsh==6.2.0']` |
| `cqlsh_venv.wrapper_path` | String | `'/usr/local/bin/cqlsh'` | Wrapper path; shadows the bundled cqlsh on PATH |

Disable it on Python <= 3.11 distros where you don't want the extra venv:

```ruby
node.override['axonops']['cassandra']['cqlsh_venv']['enabled'] = false
```

**Airgapped / offline installs:** the standalone `cqlsh` package is installed
from PyPI, which needs network access at converge time. When
`node['axonops']['offline_install']` is set the recipe **skips** provisioning
(logs a warning and leaves the bundled cqlsh in place) rather than failing the
converge. Provision cqlsh manually, mirror it internally, or set
`cqlsh_venv.enabled = false` to silence the warning.

The wrapper also fixes the cqlsh-based cluster health probe in
`attributes/alerts.rb` on Python 3.12+ hosts, since it too resolves `cqlsh` from
`PATH`.

> **Upgrading cqlsh:** the pip install is idempotent (it skips once
> `<venv>/bin/cqlsh` exists), so it never auto-upgrades. Run
> `<venv>/bin/pip install --upgrade cqlsh` manually, or bump `cqlsh_venv.packages`
> to a pinned version and remove the venv, to move to a newer release.

---

## SSL Caveat

By default `client_encryption_options.enabled` is `true` and references a JKS keystore at `/opt/cassandra/conf/keystore.jks`. The `cassandra_self_signed` helper generates PEM files, not a JKS keystore. As a result, native transport (CQL/9042) will fail to start until one of the following is done:

1. **Disable client encryption** (recommended for development):
   ```ruby
   node.override['axonops']['cassandra']['client_encryption_options'] = {
     'enabled' => false
   }
   ```

2. **Provide a JKS keystore** at the path configured by `client_encryption_options.keystore`.

This is tracked in issue #30. PEM-based TLS is on the roadmap (issue #26).

---

## Testing

### Unit tests (RSpec)

Pure-Ruby specs that test the version library and verify the 3.11 template renders correctly:

```bash
# Run all unit specs
rspec --options /dev/null spec/unit/libraries/cassandra_version_spec.rb
rspec --options /dev/null spec/unit/templates/cassandra_3_11_yaml_spec.rb

# Or run the whole suite
chef exec rspec
```

### BDD feature files

Gherkin scenarios under `features/` describe the version-selection and install behaviour. These are read by the RSpec/Turnip harness (or can be executed with a compatible runner):

```
features/cassandra_install.feature
features/cassandra_version_support.feature
```

### Integration tests (Test Kitchen + InSpec)

Two suites are defined in `kitchen.yml`, using the Dokken driver (systemd in Docker):

| Suite | Cassandra version | Platforms |
|-------|-------------------|-----------|
| `cassandra-3-11` | 3.11.17 | ubuntu-22.04, rockylinux-9 |
| `cassandra-default` | 5.0.5 | ubuntu-22.04, rockylinux-9 |

```bash
# Converge and verify Cassandra 3.11 on Ubuntu
kitchen converge cassandra-3-11-ubuntu-2204
kitchen verify  cassandra-3-11-ubuntu-2204

# Full cycle for Cassandra 5.0 (default)
kitchen test cassandra-default-rockylinux-9

# Destroy all test containers
kitchen destroy
```

InSpec controls live under `test/integration/cassandra-3.11/` and `test/integration/cassandra-default/`.

### CI

The GitHub Actions workflow `.github/workflows/ci.yml` runs on every pull request and executes the unit spec suite.

---

## Troubleshooting

### Cassandra fails to start

- Check `/var/log/cassandra/system.log`.
- Verify Java is installed and correct: `java -version`.
- Ensure disk space and directory permissions are correct.
- Confirm `listen_address` and `rpc_address` are reachable.

### Cannot connect on CQL port 9042

- Verify `rpc_address` is not `localhost` if connecting remotely.
- Check `native_transport_port` (default `9042`) is open in the firewall.
- Ensure `start_native_transport` is `true`.
- If TLS is enabled, see [SSL Caveat](#ssl-caveat).

### Performance issues

- Check heap size — rule of thumb: 8 GB for most workloads, no more than 32 GB.
- Review GC logs at `/var/log/cassandra/gc.log.*`.
- Increase `concurrent_reads` / `concurrent_writes` on high-core nodes.

### Authentication failures

- Default credentials are `cassandra` / `cassandra`.
- Change them immediately after first boot.
- Ensure `authenticator` is `PasswordAuthenticator`.

### Log locations

| Log | Path |
|-----|------|
| System | `/var/log/cassandra/system.log` |
| Debug | `/var/log/cassandra/debug.log` |
| GC | `/var/log/cassandra/gc.log.*` |
| Audit | `/var/lib/cassandra/audit/` (if enabled) |

### Useful commands

```bash
# Check service status
systemctl status cassandra

# Connect with cqlsh
cqlsh -u cassandra -p cassandra

# Check cluster status
nodetool status

# Tail system log
tail -f /var/log/cassandra/system.log
```

---

## Roadmap

The following items are tracked as open GitHub issues and are **not yet implemented**:

| Issue | Feature |
|-------|---------|
| #23 | Package-repository (apt/yum) install mode |
| #24 | Full ~150-attribute `cassandra.yaml` parity for 3.11 |
| #25 | `system_tuning` recipe (currently disabled) |
| #26 | PEM-based TLS support (currently only JKS) |

---

## Additional Resources

- [Apache Cassandra 3.11 documentation](https://cassandra.apache.org/doc/3.11/)
- [Apache Cassandra 4.1 documentation](https://cassandra.apache.org/doc/4.1/)
- [Apache Cassandra 5.0 documentation](https://cassandra.apache.org/doc/5.0/)
- [AxonOps documentation](https://docs.axonops.com/)
