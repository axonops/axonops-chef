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
- [Snapshot repositories (S3/GCS)](#snapshot-repositories-s3gcs)
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
| `version` | `3.8.0` | OpenSearch version to install |
| `cluster_name` | `axonops-cluster` | Cluster name |
| `heap_size` | `512m` | JVM heap size — increase for production |
| `data_dir` | `/var/lib/opensearch` | Data directory |
| `logs_dir` | `/var/log/opensearch` | Log directory |
| `listen_address` | `127.0.0.1` | IP address to bind to |
| `listen_port` | `9200` | HTTP port |
| `install` | `true` | Whether to install OpenSearch at all (`false` to use an external cluster) |
| `security_plugin_enabled` | `false` | See [Security](#security) |
| `java_tmp_dir` | `/var/lib/opensearch/tmp` | JVM `java.io.tmpdir` — see [noexec /tmp](#noexec-tmp). Set to `''` or `/tmp` to keep the OS default |

**Production heap sizing**: never exceed 50% of available RAM or 32GB (the
compressed-oops threshold).

```ruby
node.override['axonops']['server']['elastic']['heap_size'] = '4g'
```

## noexec /tmp

On CIS-hardened hosts (Amazon Linux 2023 and others) `/tmp` is mounted
`noexec`. The JVM unpacks and executes native libraries into `java.io.tmpdir`
at startup, so OpenSearch fails to start when that lands on a `noexec` mount.

The cookbook defaults `java_tmp_dir` to `/var/lib/opensearch/tmp`, creates it
`opensearch:opensearch` `0750`, and writes two drop-ins that restart the
service on change:

- `/etc/opensearch/jvm.options.d/tmpdir.options` — `-Djava.io.tmpdir=<dir>`
- `/etc/systemd/system/opensearch.service.d/tmpdir.conf` —
  `Environment=OPENSEARCH_TMPDIR=<dir>`, since `opensearch-env` otherwise
  derives `OPENSEARCH_TMPDIR` from `mktemp -d` under `/tmp`.

Keep this directory on a mount that is **not** `noexec`. To opt out and use the
OS default `/tmp`, set the attribute to `''` or `/tmp`; no directory or
drop-ins are created.

```ruby
node.override['axonops']['server']['elastic']['java_tmp_dir'] = '/var/lib/opensearch/tmp'
```

## Snapshot repositories (S3/GCS)

Back up the AxonOps OpenSearch to an S3 bucket (AWS S3 or any S3-compatible
store) or a GCS bucket. With `snapshot.enabled` the recipe installs the
`repository-s3` or `repository-gcs` plugin, writes the credentials to
`/etc/opensearch/opensearch.keystore`, renders the client settings into
`opensearch.yml` and registers the repository and an optional Snapshot
Management policy.

All settings live under `node['axonops']['server']['elastic']['snapshot']`
(or the `opensearch` alias namespace, merged key by key):

| Attribute | Type | Default | Example | Description |
|-----------|------|---------|---------|-------------|
| `enabled` | bool | `false` | `true` | Install the plugin, load credentials and register the repository |
| `type` | string | `s3` | `gcs` | `s3` (AWS S3 or any S3-compatible store) or `gcs` |
| `client` | string | `default` | `backups` | Client name in the `s3.client.<client>.*` / `gcs.client.<client>.*` settings |
| `repository_name` | string | `<type>-snapshots` | `nightly` | Repository name |
| `bucket` | string | `''` | `opensearch-backups` | Bucket name. Required |
| `base_path` | string | `''` | `prod/cluster1` | Path prefix inside the bucket |
| `register` | bool | `true` | `false` | Register the repository and policy through the REST API |
| `s3.access_key` | string | `''` | `data_bag_item(...)['access_key']` | Static access key. Set together with `s3.secret_key` |
| `s3.secret_key` | string | `''` | `data_bag_item(...)['secret_key']` | Static secret key |
| `s3.session_token` | string | `''` | | Optional session token for temporary credentials |
| `s3.region` | string | `''` | `eu-west-1`, `fsn1` | Signing region |
| `s3.endpoint` | string | `''` | `fsn1.your-objectstorage.com` | Endpoint for S3-compatible stores (Hetzner Object Storage, MinIO, Ceph RGW) |
| `s3.protocol` | string | `''` | `http` | `http` or `https`. Empty keeps the plugin default (`https`) |
| `s3.path_style_access` | bool | `false` | `true` | Path-style URLs (`https://endpoint/bucket`) instead of virtual-hosted style |
| `s3.extra_settings` | hash | `{}` | `{ 'disable_chunked_encoding' => true }` | Other non-secret `s3.client.<client>.*` settings (`signer_override`, `disable_chunked_encoding`, timeouts) |
| `gcs.credentials_json` | string or hash | `''` | `data_bag_item(...)['sa_json']` | Service-account JSON |
| `gcs.project_id` | string | `''` | `my-project` | GCP project ID |
| `gcs.endpoint` | string | `''` | `https://storage.example.com` | Custom GCS endpoint |
| `policy` | hash | `{}` | see below | Snapshot Management policy. `name` is the policy name; the other keys are the `_plugins/_sm/policies` request body. `snapshot_config.repository` defaults to the repository name |

S3 example (Hetzner Object Storage; for AWS, drop `endpoint` and
`path_style_access` and set the AWS region):

```ruby
creds = data_bag_item('secrets', 'opensearch_s3')

node.override['axonops']['server']['elastic']['snapshot'] = {
  'enabled' => true,
  'type' => 's3',
  'bucket' => 'opensearch-backups',
  'base_path' => 'axonops-production',
  's3' => {
    'access_key' => creds['access_key'],
    'secret_key' => creds['secret_key'],
    'region' => 'fsn1',
    'endpoint' => 'fsn1.your-objectstorage.com',
    'path_style_access' => true,
  },
  'policy' => {
    'name' => 'daily',
    'creation' => { 'schedule' => { 'cron' => { 'expression' => '0 2 * * *', 'timezone' => 'UTC' } } },
    'deletion' => {
      'schedule' => { 'cron' => { 'expression' => '0 3 * * *', 'timezone' => 'UTC' } },
      'condition' => { 'max_age' => '14d', 'min_count' => 1 },
    },
    'snapshot_config' => { 'indices' => '*' },
  },
}

include_recipe 'axonops::server'
```

GCS example:

```ruby
node.override['axonops']['server']['elastic']['snapshot'] = {
  'enabled' => true,
  'type' => 'gcs',
  'bucket' => 'opensearch-backups',
  'gcs' => {
    'project_id' => 'my-project',
    'credentials_json' => data_bag_item('secrets', 'opensearch_gcs')['sa_json'],
  },
}
```

Check the repository after the run:

```bash
curl -X POST http://127.0.0.1:9200/_snapshot/s3-snapshots/_verify
```

Notes:

- Credentials go only into `opensearch.keystore` (`root:opensearch`, `0640`);
  they never appear in `opensearch.yml` or the Chef output. The keystore has
  no password, so it is obfuscated rather than encrypted: keep the source
  credentials in an encrypted data bag or a secrets manager.
- Leave the static credentials empty to use the instance identity: an EC2
  instance profile or IRSA for S3, GCE/GKE workload identity for GCS. Any
  credentials stored earlier for the client are then removed.
- Installing the plugin or changing credentials restarts OpenSearch once,
  before the repository is registered. When `opensearch_version` changes, the
  plugin is reinstalled to match.
- The repository-gcs plugin reads the service-account JSON at startup and
  OpenSearch will not start when it is malformed, so the recipe refuses JSON
  without `client_id`, `client_email`, `private_key_id` and a PEM
  `private_key`.
- With `security_plugin_enabled`, registration uses HTTPS and the
  `search_db` username and password.
- Offline installs copy the plugin zip named by
  `node['axonops']['offline_packages']['opensearch_repository_s3']` or
  `['opensearch_repository_gcs']` from `offline_packages_path`. Download it
  from `https://artifacts.opensearch.org/releases/plugins/repository-s3/<version>/repository-s3-<version>.zip`
  (or `repository-gcs`); it must match the OpenSearch version.
- Setting `enabled` back to `false` does not remove the plugin, the repository
  or the keystore credentials. Removing a key from `policy` does not remove it
  from an existing policy; delete the policy
  (`DELETE _plugins/_sm/policies/<name>`) and converge again.
- Restoring snapshots is not automated.

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
node.override['axonops']['offline_packages']['opensearch'] = 'opensearch-3.8.0-linux-x64.rpm'

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
