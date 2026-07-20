# DataStax Enterprise (DSE) Monitoring Guide

This guide covers monitoring an existing **DataStax Enterprise (DSE)** cluster with
the AxonOps agent, using the AxonOps Chef cookbook. Supported series: **5.1, 6.7, 6.8,
6.9**.

## Scope

This cookbook **monitors** DSE — it does not install, configure, or manage a DSE
cluster. `axonops::cassandra` refuses to touch a node once DSE is detected; use
`axonops::agent` (directly, or via `axonops::cassandra`, which now includes it for you)
to attach monitoring to an already-running DSE install.

## Detection

The agent looks for a DSE install at:

- `/opt/dse`
- `/etc/dse/cassandra/cassandra.yaml`

If found, `node['axonops']['cassandra']['edition']` is automatically set to `'dse'`
(default `'apache'`). You can also force it explicitly:

```ruby
node.override['axonops']['cassandra']['edition'] = 'dse'
node.override['axonops']['cassandra']['dse_version'] = '6.8' # default: '5.1'
include_recipe 'axonops::agent'
```

`dse_version` can't be reliably auto-detected the way the Apache Cassandra version
can (no equivalent of `nodetool version`/a predictable install-path convention across
DSE releases), so set it explicitly for anything other than the default `'5.1'` — it
selects which `axon-dse<version>-agent` package gets installed
(`AxonOpsCassandra.dse_java_agent_package` in `libraries/cassandra_version.rb`; there
is no single generic `axon-dse-agent` package).

## What happens for each edition

| Edition  | `axonops::cassandra`                                   | `axonops::agent`                                      |
|----------|----------------------------------------------------------|---------------------------------------------------------|
| `apache` | Installs Apache Cassandra from tarball (default)          | Installs `axon-cassandra*-agent-jdk*`, monitors via the `cassandra` metrics template branch |
| `dse`    | Logs and delegates to `axonops::agent`; installs nothing   | Installs `axon-dse<dse_version>-agent` (e.g. `axon-dse6.8-agent` — override via `node['axonops']['java_agent']['dse']`), monitors via the `dse` metrics template branch (DSE-specific JMX object names, e.g. `com.datastax.bdp:type=dsefs,*`) |

## Quick start

```ruby
# DSE already installed and running on this node — just attach monitoring.
node.override['axonops']['cassandra']['dse_version'] = '6.8' # default: '5.1'
node.override['axonops']['agent']['org_key'] = 'your-org-key'
node.override['axonops']['agent']['org_name'] = 'your-org-name'
include_recipe 'axonops::agent'
```

## Offline/airgapped install

`axonops::offline_download_helper` resolves the java-agent package from `dse_version`
the same way the online path does, and only ever downloads the agent — never a
Cassandra package, since this cookbook doesn't install/manage DSE itself. Set
`node['axonops']['cassandra']['edition'] = 'dse'` (and `dse_version` if not `'5.1'`)
before running the download helper.

## JVM agent (cassandra-env.sh)

To collect JVM metrics, `axonops::agent` appends a `JVM_OPTS` line to DSE's
`cassandra-env.sh`, loading the `axon-dse<version>-agent.jar` installed above:

```bash
JVM_OPTS="$JVM_OPTS -javaagent:/usr/share/axonops/axon-dse5.1-agent.jar=/etc/axonops/axon-agent.yml"
```

The path to `cassandra-env.sh` is resolved in this order:

1. `node['axonops']['cassandra']['dse_env_file']` — set this if neither
   default below matches your install.
2. `/etc/dse/cassandra/cassandra-env.sh` — the rpm/deb package default.
3. `<dse_home>/resources/cassandra/conf/cassandra-env.sh` — tar installs,
   where `dse_home` is whichever of the detected/search paths
   (`node['axonops']['cassandra']['edition'] == 'dse'`-driven detection, see
   `cassandra_search_paths` in `recipes/agent.rb`) actually contains it.

```ruby
# Only needed if your DSE install doesn't match either default above.
node.override['axonops']['cassandra']['dse_env_file'] = '/opt/dse-5.1.32/resources/cassandra/conf/cassandra-env.sh'
```

If none of the three resolves to an existing file, the JVM agent line is
skipped — the agent still runs and reports non-JVM metrics.

## Java

DSE 5.1 requires Java 8, same as Apache Cassandra 3.11 —
`AxonOpsCassandra::JAVA_MAJOR['5.1']` reflects this if you use the version library
directly. 6.7/6.8/6.9 requirements depend on your DSE install; this cookbook doesn't
manage DSE's own Java, only the agent's.

## Limitations

- No Kitchen/CI coverage: DataStax does not distribute a redistributable DSE Docker
  image suitable for public CI, so DSE support is covered by ChefSpec/unit tests only.
- `dse_version` must be set explicitly — there's no reliable auto-detection of which
  DSE series is actually running.
