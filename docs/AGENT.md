# AxonOps Agent Installation Guide

This guide covers installing and configuring the AxonOps monitoring agent with the
AxonOps Chef cookbook. The agent monitors an **existing** Cassandra, DataStax
Enterprise (DSE), or Kafka installation — it never installs or reinstalls the
database/broker itself.

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Basic Usage](#basic-usage)
- [Configuration Reference](#configuration-reference)
- [Examples](#examples)
  - [SaaS mode (default)](#saas-mode-default)
  - [Self-hosted mode](#self-hosted-mode)
  - [Monitoring DataStax Enterprise (DSE) 5.1](#monitoring-datastax-enterprise-dse-51)
  - [Monitoring Kafka instead of Cassandra](#monitoring-kafka-instead-of-cassandra)
  - [TLS / mTLS to a self-hosted server](#tls--mtls-to-a-self-hosted-server)
  - [Disabling remote command execution](#disabling-remote-command-execution)
  - [Human-readable identifier and hostname override](#human-readable-identifier-and-hostname-override)
  - [Offline / air-gapped install](#offline--air-gapped-install)
  - [Amazon Linux](#amazon-linux)
- [How detection works](#how-detection-works)
- [Troubleshooting](#troubleshooting)

## Overview

`axonops::agent`:

1. Detects an existing Cassandra, DSE, or Kafka install on the node (or trusts
   `node['axonops']['agent']['cassandra_home']` / `cassandra_config` if set).
2. Installs `axon-agent` and the matching java agent (`axon-cassandra*-agent-jdk*`,
   `axon-dse-agent`, or `axon-kafka3-agent`).
3. Renders `/etc/axonops/axon-agent.yml` and starts the `axon-agent` service.

## Requirements

- An already-running Cassandra, DSE 5.1, or Kafka install on the node (the agent
  does not install one for you — pair with `axonops::cassandra` or
  `axonops::kafka` if you also want this cookbook to install the database).
- Network access to `agents.axonops.cloud` (SaaS mode) or your self-hosted
  AxonOps server (self-hosted mode), unless using [offline install](#offline--air-gapped-install).

## Basic Usage

```ruby
# recipes/default.rb
include_recipe 'axonops::agent'
```

With no attributes set, this installs the agent in SaaS mode pointed at
`agents.axonops.cloud:443` — you still need `org_key`/`org_name` (see
[SaaS mode](#saas-mode-default) below) for the agent to actually authenticate.

## Configuration Reference

All attributes live under `node['axonops']['agent']` unless noted.

| Attribute | Default | Description |
|-----------|---------|-------------|
| `enabled` | `true` | Master switch for the agent |
| `hosts` | `'agents.axonops.cloud'` | AxonOps server/SaaS hostname |
| `port` | `443` | AxonOps server/SaaS port |
| `org_key` | `nil` | Organization key (SaaS mode) |
| `org_name` | `nil` | Organization name |
| `api_key` | — | Overrides `org_key` if set (same effect) |
| `disable_command_exec` | `false` | Set `true` to disable remote command execution from the dashboard |
| `cassandra_home` / `cassandra_config` | `nil` (auto-detected) | Force a specific Cassandra/DSE install path |
| `tls_mode` | `nil` | `'disabled'`, `'TLS'`, or `'mTLS'` — required for self-hosted TLS |
| `tls_cafile` / `tls_certfile` / `tls_keyfile` | `nil` | Certificate paths for TLS/mTLS |
| `tls_skipverify` | `false` | Skip TLS certificate verification |
| `human_readable_identifier` | `nil` | Friendly node name shown in the dashboard |
| `hostname` | `nil` | Overrides the agent's reported hostname |
| `force_send_all_metrics_prom` | `nil` | Force-export all metrics via the Prometheus endpoint |
| `tmp_path` | `nil` | Agent temp directory override |
| `scripts_location` | `'/var/lib/axonops/scripts/'` | Location for custom service-check scripts |
| `ntp_server` | `'pool.ntp.org'` | NTP server the agent checks clock drift against |
| `ntp_timeout` | `6` | NTP check timeout (seconds) |
| `backup_purge_interval` | `nil` | Local backup purge interval |
| `warn_threshold_millis` | `1000` | JMX call latency warning threshold |
| `node['axonops']['cassandra']['edition']` | `'apache'` | Auto-set to `'dse'` when a DSE install is detected — see [docs/DSE.md](DSE.md) |
| `node['axonops']['deployment_mode']` | `'saas'` | `'saas'` or `'self-hosted'` — self-hosted routes the agent to `axonops::server`'s listen address/port automatically |

## Examples

### SaaS mode (default)

```ruby
node.override['axonops']['agent']['org_key']  = 'your-org-key'
node.override['axonops']['agent']['org_name'] = 'your-org-name'

include_recipe 'axonops::agent'
```

### Self-hosted mode

Points the agent at your own `axonops::server` instead of `agents.axonops.cloud`:

```ruby
node.override['axonops']['deployment_mode']            = 'self-hosted'
node.override['axonops']['server']['enabled']           = true
node.override['axonops']['server']['listen_address']    = '10.0.1.5'
node.override['axonops']['server']['listen_port']       = 8080

include_recipe 'axonops::agent'
```

### Monitoring DataStax Enterprise (DSE) 5.1

No extra attributes needed — DSE is auto-detected from `/opt/dse` or
`/etc/dse/cassandra/cassandra.yaml`. See [docs/DSE.md](DSE.md) for full detail.

```ruby
node.override['axonops']['agent']['org_key']  = 'your-org-key'
node.override['axonops']['agent']['org_name'] = 'your-org-name'

include_recipe 'axonops::agent'
```

To force DSE monitoring without relying on auto-detection:

```ruby
node.override['axonops']['cassandra']['edition'] = 'dse'
include_recipe 'axonops::agent'
```

### Monitoring Kafka instead of Cassandra

If `axonops::kafka` is in the run list (or a Kafka install is detected), the
agent installs `axon-kafka3-agent` instead of the Cassandra java agent:

```ruby
include_recipe 'axonops::kafka'
include_recipe 'axonops::agent'
```

### TLS / mTLS to a self-hosted server

```ruby
node.override['axonops']['deployment_mode']         = 'self-hosted'
node.override['axonops']['server']['listen_address'] = 'axonops.internal'
node.override['axonops']['server']['listen_port']    = 8443

node.override['axonops']['agent']['tls_mode']     = 'mTLS'
node.override['axonops']['agent']['tls_cafile']   = '/etc/axonops/certs/ca.crt'
node.override['axonops']['agent']['tls_certfile'] = '/etc/axonops/certs/agent.crt'
node.override['axonops']['agent']['tls_keyfile']  = '/etc/axonops/certs/agent.key'

include_recipe 'axonops::agent'
```

### Disabling remote command execution

Locks down the dashboard's ability to run remote commands/scripts on this node
— common for production nodes with strict change-control:

```ruby
node.override['axonops']['agent']['disable_command_exec'] = true
include_recipe 'axonops::agent'
```

### Human-readable identifier and hostname override

Useful when the OS hostname isn't meaningful (e.g. autoscaled/cloud instances):

```ruby
node.override['axonops']['agent']['human_readable_identifier'] = "cassandra-#{node['axonops']['cassandra']['dc']}-#{node['ec2']['instance_id']}"
node.override['axonops']['agent']['hostname'] = node['ec2']['instance_id']

include_recipe 'axonops::agent'
```

### Offline / air-gapped install

```ruby
node.override['axonops']['offline_install']      = true
node.override['axonops']['offline_packages_path'] = '/opt/axonops/offline'

# Filenames are defined in attributes/default.rb under
# default['axonops']['offline_packages'] — override per-package if needed:
node.override['axonops']['offline_packages']['agent']      = 'axon-agent-2.0.6-1.x86_64.rpm'
node.override['axonops']['offline_packages']['java_agent'] = 'axon-cassandra5.0-agent-jdk17-1.0.10-1.noarch.rpm'

include_recipe 'axonops::agent'
```

Pre-stage both packages under `offline_packages_path` before converging — the
recipe raises a clear error naming the missing file rather than silently
skipping.

### Amazon Linux

No special attributes needed — `'amazon'` is a fully supported `platform_family`
for both online and offline installs:

```ruby
node.override['axonops']['agent']['org_key']  = 'your-org-key'
node.override['axonops']['agent']['org_name'] = 'your-org-name'

include_recipe 'axonops::agent'
```

## How detection works

The agent searches, in order: `/opt/cassandra`, `/usr/share/cassandra`,
`/var/lib/cassandra`, `/opt/apache-cassandra*`, `/opt/dse`, and
`node['axonops']['cassandra']['install_dir']`, then looks for a `bin/cassandra`
binary and a `cassandra.yaml` config file under `conf`, `config`,
`/etc/cassandra`, or `/etc/dse/cassandra`.

If you install Cassandra via this same cookbook (`axonops::cassandra`), run
that recipe first — its header comment says as much:

```ruby
include_recipe 'axonops::cassandra'  # installs Cassandra AND includes axonops::agent for you
```

If you're attaching monitoring to an **existing** Cassandra/DSE install this
cookbook didn't set up, `axonops::agent` alone is enough as long as the install
is in one of the searched paths above; otherwise set `cassandra_home` /
`cassandra_config` explicitly.

## Troubleshooting

**Agent won't start** — check `/var/log/axonops/axon-agent.log` and confirm
`/etc/axonops/axon-agent.yml` rendered with the expected `org`/`key`/`hosts`
values (`cat /etc/axonops/axon-agent.yml`).

**"Could not detect Cassandra or Kafka"** — the recipe couldn't find a Cassandra,
DSE, or Kafka install in any searched path, and neither `axonops::cassandra` nor
`axonops::kafka` is in the run list. Set `node['axonops']['agent']['cassandra_home']`
explicitly, or run `axonops::cassandra`/`axonops::kafka` first.

**Node doesn't appear in the dashboard** — verify network connectivity to
`agent_host:agent_port` (`agents.axonops.cloud:443` for SaaS, or your
self-hosted server), and check `org_key`/`org_name` are correct.

## Additional Resources

- [AxonOps documentation](https://docs.axonops.com/)
- [docs/DSE.md](DSE.md) — DataStax Enterprise monitoring
- [docs/CASSANDRA.md](CASSANDRA.md) — installing Apache Cassandra with this cookbook
- [docs/KAFKA.md](KAFKA.md) — installing Kafka with this cookbook
