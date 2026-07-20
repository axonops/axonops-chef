<p align="center">
  <a href="https://axonops.com">
    <img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/AxonopsDigitalMaster_AxonopsFullLogoBlue.jpg" alt="AxonOps" width="300">
  </a>
</p>

<p align="center">
  <em>Built and maintained by <a href="https://axonops.com">AxonOps</a></em>
</p>

# AxonOps Chef Cookbook — Scripts

Helper scripts for maintaining and using the cookbook. These are standalone
tools — none of them require a Chef run.

| Script | Purpose |
|--------|---------|
| [`download_offline_packages.py`](download_offline_packages.py) | Mirror AxonOps packages (and optionally Cassandra, Java, Elasticsearch) for offline / air-gapped installs. |
| [`create_mock_packages.sh`](create_mock_packages.sh) | Generate small fake package files for local testing of the offline flow (no network). |

---

## `download_offline_packages.py`

Downloads AxonOps packages straight from `packages.axonops.com` (apt + yum),
verifies each file against its published SHA-256, and writes a `manifest.json`
alongside them. Run it on any machine with internet access, then copy the
output directory to your air-gapped target.

> **Which downloader?** This Python script gives fine-grained control over
> *which* AxonOps packages and versions you fetch (`--packages`). For the
> simpler, component-oriented Chef-driven flow (`--components cassandra,java,…`
> that also prints the `node['axonops']['offline_packages']` values to set), use
> [`files/default/download-packages.sh`](../files/default/download-packages.sh)
> and see [docs/OFFLINE.md](../docs/OFFLINE.md).

### Requirements

- Python 3 (standard library only — no `pip install` needed).

### Quick start

```bash
# Everything (AxonOps deb + rpm, Cassandra, Java, Elasticsearch)
scripts/download_offline_packages.py --all --non-interactive --output-dir /tmp/offline

# Only AxonOps RPMs
scripts/download_offline_packages.py --all --non-interactive \
  --output-dir /tmp/offline --package-type rpm

# Interactive menu (no flags)
scripts/download_offline_packages.py
```

By default the AxonOps step mirrors **every** `axon-*` package (all Cassandra,
DSE and Kafka agents, plus `axon-agent`, `axon-server`, `axon-dash`) at its
latest version — that is roughly 1 GB of RPMs. Narrow it with `--packages`.

### Selecting AxonOps packages — `--packages`

Restrict which `axon-*` packages are fetched with a comma-separated list.
Shell-style globs are allowed. Only the latest version of each match is fetched
unless you pin one.

```bash
# A single agent
scripts/download_offline_packages.py --components axonops --package-type rpm \
  --output-dir /tmp/offline --packages axon-cassandra3.11-agent

# A whole series (both JDK variants) via glob
scripts/download_offline_packages.py --components axonops --package-type rpm \
  --output-dir /tmp/offline --packages 'axon-cassandra5.0-agent*'

# The three core packages
scripts/download_offline_packages.py --components axonops --package-type rpm \
  --output-dir /tmp/offline --packages axon-agent,axon-dash,axon-server
```

### Pinning versions — `name=version`

Pin a specific version per package with `name=version`. Unpinned entries still
fetch the latest. The pin matches an exact version **or** the upstream portion
of an RPM `ver-rel` string, so `axon-agent=2.0.30` selects the `2.0.30` DEB and
the `2.0.30-1` RPM. A pin that matches nothing reports a clean no-match rather
than silently downloading the latest.

```bash
# RPM, pinned versions
scripts/download_offline_packages.py --non-interactive --output-dir /tmp/offline \
  --package-type rpm --components axonops \
  --packages axon-agent=2.0.30,axon-dash=2.0.36,axon-server=2.0.34

# DEB, same pins
scripts/download_offline_packages.py --non-interactive --output-dir /tmp/offline \
  --package-type deb --components axonops \
  --packages axon-agent=2.0.30,axon-dash=2.0.36,axon-server=2.0.34

# Mix pinned and latest
scripts/download_offline_packages.py --components axonops --package-type rpm \
  --output-dir /tmp/offline \
  --packages axon-agent=2.0.30,axon-dash,axon-server=2.0.34
```

Run once without `--packages` to see the package names and current versions
that are live, then pin from there.

### Package names & architectures

Names are dotted and, for Cassandra 4.0+/5.0, carry a JDK-variant suffix:

| Kind | Examples |
|------|----------|
| Core | `axon-agent`, `axon-server`, `axon-dash` |
| Cassandra agents | `axon-cassandra3.11-agent`, `axon-cassandra4.1-agent`, `axon-cassandra5.0-agent-jdk11`, `axon-cassandra5.0-agent-jdk17` |
| DSE agents | `axon-dse5.1-agent`, `axon-dse6.7-agent`, `axon-dse6.8-agent`, `axon-dse6.9-agent` |
| Kafka agents | `axon-kafka2-agent`, `axon-kafka3-agent`, `axon-kafka4-agent` |

- **RPM**: `axon-agent`, `axon-server`, `axon-dash` ship per-architecture
  (`x86_64` + `aarch64`) — both are fetched. The agent packages are `noarch`;
  the script drops the repo's obsolete `x86_64` builds of them and keeps the
  single current `noarch` artifact.
- **DEB**: `axon-agent`/`axon-server`/`axon-dash` ship one `amd64` build; the
  agents are architecture `all`.

### Options

| Flag | Description |
|------|-------------|
| `--all` | Download everything (AxonOps deb + rpm, Cassandra, Java, Elasticsearch), non-interactive. Honours `--package-type`. |
| `--components java cassandra elasticsearch axonops` | Download only the named components. |
| `--axonops` / `--cassandra` / `--elasticsearch` / `--java` | Legacy single-component switches. |
| `--package-type {deb,rpm}` | AxonOps package format. Omit for both. |
| `--packages LIST` | AxonOps package filter (globs, `name=version` pins). See above. |
| `--version VERSION` | Specific version for Cassandra / Elasticsearch. |
| `--java-arch {x64,aarch64}` | Java (Azul Zulu) architecture. Default `x64`. |
| `--output-dir DIR` | Where to write packages (default: `offline_packages/`). |
| `--non-interactive` | Never prompt; take defaults. |

Full reference: `scripts/download_offline_packages.py --help`.

### Output & verification

Every downloaded file is SHA-256-verified against the repository metadata.
Truncated transfers (the CDN occasionally drops a connection mid-download) are
detected by comparing bytes written against `Content-Length` and retried up to
three times. On completion a `manifest.json` listing every file with its size
and checksum is written to the output directory.

---

## `create_mock_packages.sh`

Builds small mock `axon-server`/`axon-dash`/`axon-agent` `.deb` packages (via
`dpkg-deb`, for `all`/`amd64`/`arm64`) plus stub Cassandra java-agent JARs into
`offline_packages/`, so the offline install path can be exercised locally
without pulling gigabytes over the network. The packages install a stub binary
and systemd unit — for development and CI only, not real AxonOps builds.

Requires `dpkg-deb` (run on a Debian/Ubuntu host or container).

```bash
scripts/create_mock_packages.sh
```

---

## Contact

Maintained by [AxonOps](https://axonops.com). For support, visit
[axonops.com/contact](https://axonops.com/contact).
