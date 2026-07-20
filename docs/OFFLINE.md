# Offline / Air-gapped Installation

The `axonops` cookbook can install every component from pre-downloaded packages,
with no internet access on the target node. This has two parts:

1. **Download** the packages on an internet-connected machine — the standalone
   `download-packages.sh` script.
2. **Install** from those packages — set `node['axonops']['offline_install']`
   and the `offline_packages` filenames, then run the recipes as normal.

This page covers part 1. For the install-side attributes see the
[Offline/Air-gapped Installation example in the README](../README.md#4-offlineair-gapped-installation).

## The `download-packages.sh` downloader

`files/default/download-packages.sh` is a **static, Chef-free** shell script.
Run it directly on any machine with internet access — it needs `bash`, the
platform package manager (`dnf` or `apt-get`), and `curl` or `wget`. Run it as
root (or with `sudo`): it configures repositories and uses the package manager
to resolve the real, content-hashed AxonOps package filenames.

```bash
files/default/download-packages.sh --components <list> [options]
```

Select which packages to fetch with `--components` (comma-separated). Only the
requested set is downloaded and validated — nothing else is required.

### Components

| Component   | Downloads                                                                 |
|-------------|---------------------------------------------------------------------------|
| `cassandra` | Apache Cassandra tarball (`tar`) **or** RPM/deb (`pkg`). Not valid for DSE. |
| `java`      | Azul Zulu JDK tarball; plus the `zulu*-headless` OS package when `--cassandra-install-format pkg`. |
| `agent`     | `axon-agent` package + the matching `axon-cassandra*` / `axon-dse*` java-agent package (jar extracted alongside). |
| `server`    | `axon-server` package + the OpenSearch package.                           |
| `dashboard` | `axon-dash` package.                                                       |

### Common invocations

```bash
# Just the Cassandra tarball
./download-packages.sh --components cassandra

# Cassandra + Java (Azul Zulu JDK)
./download-packages.sh --components cassandra,java

# Cassandra + Java + AxonOps agent (+ java-agent)
./download-packages.sh --components cassandra,java,agent

# Full self-hosted stack
./download-packages.sh --components cassandra,java,agent,server,dashboard

# Agent for an existing DSE 6.8 cluster (no Cassandra download)
./download-packages.sh --components agent --edition dse --dse-version 6.8

# Cassandra installed as an RPM/deb (needs the headless JDK package too)
./download-packages.sh --components cassandra,java --cassandra-install-format pkg --cassandra-version 4.1.5
```

When it finishes, the script prints the exact
`node['axonops']['offline_packages'][*]` attribute values to set — copy them
straight into your Chef attributes.

### Options

Every option has an environment-variable equivalent (shown in brackets) and a
built-in default that mirrors the cookbook attributes. `latest` versions resolve
to pinned known-good fallbacks baked into the script.

| Flag | Env var | Default | Purpose |
|------|---------|---------|---------|
| `-c, --components LIST` | — | *(required)* | Comma-separated: `cassandra,java,agent,server,dashboard` |
| `-d, --dir PATH` | `AXONOPS_DOWNLOAD_DIR` | script directory | Output directory |
| `--repo-url URL` | `AXONOPS_REPO_URL` | `https://packages.axonops.com` | AxonOps package repo |
| `--agent-version VER` | `AXONOPS_AGENT_VERSION` | `latest` | `axon-agent` version |
| `--server-version VER` | `AXONOPS_SERVER_VERSION` | `latest` | `axon-server` version |
| `--dashboard-version VER` | `AXONOPS_DASHBOARD_VERSION` | `latest` | `axon-dash` version |
| `--java-agent-version VER` | `AXONOPS_JAVA_AGENT_VERSION` | `latest` | java-agent version |
| `--java-agent-package NAME` | `AXONOPS_JAVA_AGENT_PACKAGE` | auto-derived | Override the java-agent package |
| `--cassandra-version VER` | `AXONOPS_CASSANDRA_VERSION` | `5.0.5` | Apache Cassandra version |
| `--cassandra-install-format F` | `AXONOPS_CASSANDRA_INSTALL_FORMAT` | `tar` | `tar` or `pkg` |
| `--edition E` | `AXONOPS_EDITION` | `apache` | `apache` or `dse` |
| `--dse-version VER` | `AXONOPS_DSE_VERSION` | `5.1` | DSE series: `5.1`, `6.7`, `6.8`, `6.9` |
| `--opensearch-version VER` | `AXONOPS_OPENSEARCH_VERSION` | `3.6.0` | OpenSearch version |
| `--zulu-version VER` | `AXONOPS_ZULU_VERSION` | `17.0.9` | Zulu JDK tarball version |
| `--zulu-build BUILD` | `AXONOPS_ZULU_BUILD` | `17.46.19-ca` | Zulu JDK tarball build |
| `--redhat-repo-311x URL` | `AXONOPS_REDHAT_REPO_311X` | JFrog mirror | Cassandra 3.11 RPM mirror |
| `-h, --help` | — | — | Show help |

### Version derivation

The script mirrors the cookbook's own logic so the artifacts match what the
recipes expect:

- **`latest` package versions** (`agent`/`server`/`dashboard`/`java-agent`)
  resolve to pinned known-good fallbacks. Refresh them with
  `dnf list --showduplicates <package>` against `packages.axonops.com` and edit
  the `DEFAULT_*` / `java_agent_fallback` values at the top of the script.
- **The java-agent package** is derived from the Cassandra series
  (`3.11`→`axon-cassandra3.11-agent`, `4.1`→`axon-cassandra4.1-agent`,
  `5.0`→`axon-cassandra5.0-agent-jdk17`) or, for DSE, from `--dse-version`
  (`axon-dse<version>-agent`). Override with `--java-agent-package`.
- **The Java major** required by a Cassandra RPM/deb (`3.11`→8, `4.1`→11,
  `5.0`→17) drives which `zulu*-headless` package is fetched for `pkg` installs.

### Validation

The script rejects combinations that cannot work, matching the cookbook guards:

- Unknown component names.
- `--components cassandra` with `--edition dse` — this cookbook monitors DSE via
  the agent and never installs/manages DSE's Cassandra.
- Cassandra `3.11` + `pkg` on Debian/Ubuntu — no upstream apt channel exists.
- `latest` java-agent version for a package with no known-good fallback — pass
  `--java-agent-version` explicitly.

## Running via Chef

`recipe[axonops::offline_download_helper]` still works. It ships this exact
script to `node['axonops']['offline_packages_path']/download-packages.sh` and
logs a recommended command line derived from the node's attributes. Running the
script by hand and running it via the recipe are equivalent — the recipe is only
a convenience wrapper; the download logic is entirely in the standalone script.

## Comprehensive downloads

For a fuller downloader that mirrors the entire repository, AxonOps also
publishes <https://github.com/axonops/axonops-installer-packages-downloader>.
