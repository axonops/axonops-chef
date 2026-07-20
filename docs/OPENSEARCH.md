# OpenSearch Installation Guide for AxonOps

This guide covers installing and configuring OpenSearch as part of a self-hosted
AxonOps server deployment. OpenSearch stores and indexes AxonOps server's own
configuration/search data — it's an internal dependency of `axonops::server`, not
something you interact with directly day to day.

> **Previously Elasticsearch.** This cookbook installed Elasticsearch (via a
> manually-extracted tarball) before switching to OpenSearch, installed as a real
> RPM/deb package from OpenSearch's own repo. The `node['axonops']['server']
> ['elastic']` attribute namespace is unchanged to minimize disruption — it now
> configures OpenSearch.

## Table of Contents
- [Overview](#overview)
- [Requirements](#requirements)
- [Basic Installation](#basic-installation)
- [Configuration Reference](#configuration-reference)
- [Using an external OpenSearch cluster](#using-an-external-opensearch-cluster)
- [Security](#security)
- [Offline / air-gapped install](#offline--air-gapped-install)
- [Troubleshooting](#troubleshooting)

## Overview

`axonops::opensearch` (also reachable as `axonops::elastic`, kept as a
backwards-compatible alias):

- Installs OpenSearch from the official OpenSearch yum/apt repo (RPM/deb — see
  [OpenSearch's own install docs](https://docs.opensearch.org/latest/install-and-configure/install-opensearch/rpm/))
- Configures it as a single-node cluster (all AxonOps needs)
- Applies the system tuning OpenSearch requires (`vm.max_map_count`)
- Enables and starts the package-managed `opensearch` systemd service

Paths, the `opensearch` user/group, and the systemd unit all come from the
package itself — this cookbook doesn't reinvent them the way the old tarball
install had to.

## Requirements

- **Operating System**: Ubuntu/Debian or RHEL/CentOS/Amazon Linux family
- **Memory**: minimum 1GB RAM allocated to the OpenSearch heap
- **System Settings**: `vm.max_map_count >= 262144` (configured automatically)

## Basic Installation

### Option 1: Install with AxonOps Server (recommended)

```ruby
include_recipe 'axonops::server'
```

`axonops::server` includes OpenSearch automatically when
`node['axonops']['server']['elastic']['install']` is `true` (the default).

### Option 2: Install OpenSearch only

```ruby
include_recipe 'axonops::opensearch'
```

## Configuration Reference

All settings live under `node['axonops']['server']['elastic']`:

| Attribute | Default | Description |
|-----------|---------|-------------|
| `version` | `2.19.6` | OpenSearch version to install |
| `cluster_name` | `axonops-cluster` | Cluster name |
| `heap_size` | `512m` | JVM heap size — increase for production |
| `data_dir` | `/var/lib/opensearch` | Data directory |
| `logs_dir` | `/var/log/opensearch` | Log directory |
| `listen_address` | `127.0.0.1` | IP address to bind to |
| `listen_port` | `9200` | HTTP port |
| `install` | `true` | Whether to install OpenSearch at all (`false` to use an external cluster) |
| `security_plugin_enabled` | `false` | See [Security](#security) |

**Production heap sizing**: never exceed 50% of available RAM or 32GB (the
compressed-oops threshold).

```ruby
node.override['axonops']['server']['elastic']['heap_size'] = '4g'
```

## Using an external OpenSearch cluster

Don't install OpenSearch on this node; point AxonOps Server at an existing
cluster instead:

```ruby
node.override['axonops']['server']['elastic']['install'] = false
node.override['axonops']['server']['search_db']['hosts'] = ['http://opensearch.internal:9200/']

include_recipe 'axonops::server'
```

## Security

OpenSearch's security plugin (authentication + TLS) is enabled by default
upstream and needs its own certificates and admin password setup — a different
model from the old Elasticsearch tarball install's manual self-signed certs.
This cookbook disables the security plugin by default
(`security_plugin_enabled: false`) to match that install's previous no-auth
behavior — fine for a single-node OpenSearch that only AxonOps Server itself
talks to over localhost.

For a production-hardened setup with the security plugin enabled:

```ruby
node.override['axonops']['server']['elastic']['security_plugin_enabled'] = true
node.override['axonops']['server']['search_db']['hosts'] = ['https://localhost:9200/']
```

This cookbook does **not** auto-generate certificates or an admin password for
you when the security plugin is enabled — follow
[OpenSearch's own security documentation](https://docs.opensearch.org/latest/security/configuration/)
to configure `plugins.security.*` settings, certificates, and internal users.

## Offline / air-gapped install

```ruby
node.override['axonops']['offline_install'] = true
node.override['axonops']['offline_packages_path'] = '/opt/axonops/offline'

# Set from the exact filename axonops::offline_download_helper's generated
# download-packages.sh prints at the end of its own run:
node.override['axonops']['offline_packages']['opensearch'] = 'opensearch-2.19.6-linux-x64.rpm'

include_recipe 'axonops::server'
```

See [docs/CHEF_SOLO_QUICKSTART.md](CHEF_SOLO_QUICKSTART.md) for a full
beginner-friendly walkthrough of offline installs.

## Troubleshooting

**OpenSearch fails to start**

```bash
systemctl status opensearch
journalctl -u opensearch -n 100
```

**Cannot connect**

```bash
curl -X GET "localhost:9200/_cluster/health?pretty"
systemctl is-active opensearch
```

**Bootstrap checks failed (`vm.max_map_count`)**

```bash
sysctl vm.max_map_count
sysctl -w vm.max_map_count=262144
```

**Useful commands**

```bash
curl -X GET "localhost:9200/_cluster/health?pretty"
curl -X GET "localhost:9200/_cat/indices?v"
curl -X GET "localhost:9200/_cat/allocation?v"
```

## Additional Resources

- [OpenSearch RPM install docs](https://docs.opensearch.org/latest/install-and-configure/install-opensearch/rpm/)
- [OpenSearch security plugin configuration](https://docs.opensearch.org/latest/security/configuration/)
- [AxonOps Documentation](https://docs.axonops.com/)
