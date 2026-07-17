# DataStax Enterprise (DSE) Monitoring Guide

This guide covers monitoring an existing **DataStax Enterprise (DSE) 5.1** cluster with
the AxonOps agent, using the AxonOps Chef cookbook.

## Scope

This cookbook **monitors** DSE — it does not install, configure, or manage a DSE
cluster. `axonops::cassandra` refuses to touch a node once DSE is detected; use
`axonops::agent` (directly, or via `axonops::cassandra`, which now includes it for you)
to attach monitoring to an already-running DSE 5.1 install.

## Detection

The agent looks for a DSE install at:

- `/opt/dse`
- `/etc/dse/cassandra/cassandra.yaml`

If found, `node['axonops']['cassandra']['edition']` is automatically set to `'dse'`
(default `'apache'`). You can also force it explicitly:

```ruby
node.override['axonops']['cassandra']['edition'] = 'dse'
include_recipe 'axonops::agent'
```

## What happens for each edition

| Edition  | `axonops::cassandra`                                   | `axonops::agent`                                      |
|----------|----------------------------------------------------------|---------------------------------------------------------|
| `apache` | Installs Apache Cassandra from tarball (default)          | Installs `axon-cassandra*-agent-jdk*`, monitors via the `cassandra` metrics template branch |
| `dse`    | Logs and delegates to `axonops::agent`; installs nothing   | Installs `axon-dse-agent` (`node['axonops']['java_agent']['dse']`), monitors via the `dse` metrics template branch (DSE-specific JMX object names, e.g. `com.datastax.bdp:type=dsefs,*`) |

## Quick start

```ruby
# DSE 5.1 already installed and running on this node — just attach monitoring.
node.override['axonops']['agent']['org_key'] = 'your-org-key'
node.override['axonops']['agent']['org_name'] = 'your-org-name'
include_recipe 'axonops::agent'
```

## Java

DSE 5.1 requires Java 8, same as Apache Cassandra 3.11 —
`AxonOpsCassandra::JAVA_MAJOR['5.1']` reflects this if you use the version library
directly.

## Limitations

- No Kitchen/CI coverage: DataStax does not distribute a redistributable DSE Docker
  image suitable for public CI, so DSE support is covered by ChefSpec/unit tests only.
- Only DSE 5.1 is supported/tested. Other DSE versions are not covered.
