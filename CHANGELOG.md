# Changelog

All notable changes to the AxonOps Chef Cookbook will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### DSE cassandra-env.sh JVM-agent path
- New `node['axonops']['cassandra']['dse_env_file']` attribute and
  `AxonOpsCassandra.dse_env_file` helper (`libraries/cassandra_version.rb`) to
  resolve DSE's `cassandra-env.sh` path: explicit override, then the rpm/deb
  default (`/etc/dse/cassandra/cassandra-env.sh`), then the tar layout
  (`<dse_home>/resources/cassandra/conf/cassandra-env.sh` — DSE tarballs wrap
  Cassandra under `bin/dse`, not a top-level `bin/cassandra`).
- `recipes/agent.rb`'s `configure-jvm-agent` now appends a direct
  `-javaagent:/usr/share/axonops/axon-dse<version>-agent.jar=...` line for DSE
  instead of the Cassandra-only `axonops-jvm.options` source line, which DSE
  installs don't ship. `detect-cassandra` also now recognizes the DSE tar
  layout when searching for an existing install. See `docs/DSE.md`.

#### Standalone offline package downloader
- New `files/default/download-packages.sh`: a static, Chef-free script that
  downloads offline-install packages, selecting the component set via
  `--components` (`cassandra`, `java`, `agent`, `server`, `dashboard`). Only the
  requested packages are fetched and validated — e.g. `--components cassandra`,
  `--components cassandra,java`, `--components cassandra,java,agent`, or the full
  `--components cassandra,java,agent,server,dashboard`. All versions, edition,
  install-format, repo URLs, etc. are overridable via flags or `AXONOPS_*` env
  vars, defaulting to the same values (and `latest` fallbacks) the cookbook uses.
- New `docs/OFFLINE.md` documents the component matrix, flags, version
  derivation, and validation rules.

### Changed

- `recipes/offline_download_helper.rb` no longer generates the download script
  from an ERB template baked with node attributes. It now ships the standalone
  `download-packages.sh` (via `cookbook_file`) to
  `node['axonops']['offline_packages_path']` and logs a recommended, component-
  based command line derived from the node's attributes. Existing
  `include_recipe 'axonops::offline_download_helper'` run lists keep working; the
  download logic is now fully usable without a Chef run.
- Removed `templates/default/offline-download-script.sh.erb` (superseded by the
  static script).

#### Switched from Elasticsearch to OpenSearch
- `axonops::server`'s internal search/config-storage dependency is now
  **OpenSearch**, installed as a real RPM/deb package from OpenSearch's own
  repo (`recipes/opensearch.rb`), replacing the old Elasticsearch tarball
  install (`recipes/elasticsearch.rb`, deleted). All download URLs (direct
  release artifacts, yum repo metadata, apt repo, GPG key) verified live.
  `opensearch.yml.erb` deliberately does **not** set `bootstrap.memory_lock`
  (the old Elasticsearch template did, backed by a systemd `LimitMEMLOCK`
  override this recipe intentionally doesn't reinvent — setting the yml key
  alone without the ulimit fails OpenSearch's bootstrap check on anything
  but pure loopback). `wait-for-opensearch` uses the same bounded-retry
  pattern as the existing `wait-for-axon-server` (not `Timeout.timeout`,
  which can interrupt mid-`Net::HTTP` call rather than unwind cleanly).
- New `docs/OPENSEARCH.md` (replaces `docs/ELASTIC.md`).
- The `node['axonops']['server']['elastic']['*']` attribute namespace is
  unchanged to minimize disruption to existing node configs — it now
  configures OpenSearch. Removed the now-meaningless `install_dir`/
  `tarball_url`/`tarball_checksum`/`ssl.*` sub-attributes (package installs
  don't have a configurable install dir, and OpenSearch's security plugin
  isn't configured via manually-generated certs the way the old tarball
  install's `ssl.self_signed` was); added `security_plugin_enabled`
  (default `false`, matching the old install's no-auth behavior) — see
  docs/OPENSEARCH.md#security.
- `axonops::elastic` is kept as a backwards-compatible wrapper recipe (now
  pointing at `axonops::opensearch`) so existing run_lists referencing it
  keep working; `recipe[axonops::elasticsearch]` run_list entries need
  updating to `recipe[axonops::opensearch]` (updated in this repo's own
  `examples/nodes/*.json`).
- New `offline_packages['opensearch']` key (replaces `offline_packages`
  `['elasticsearch']`) — `offline_download_helper`/
  `offline-download-script.sh.erb` download the real OpenSearch RPM/deb
  (verified live) instead of an Elasticsearch tarball.
- Removed the dead, unused `node['axonops']['server']['elasticsearch']`
  attribute namespace (`attributes/default.rb`) — a stray duplicate of
  `server.elastic.*` never referenced by any recipe.
- Added `node['axonops']['server']['opensearch']['*']` as the preferred
  attribute namespace, aliasing `elastic.*`. `recipes/opensearch.rb` and
  `recipes/server.rb` merge `elastic` as the base with `opensearch`
  overriding key-by-key when set — set either namespace, or mix both, with
  `opensearch` winning on conflicts. `elastic.*` keeps working unchanged.

#### Chef Solo Quickstart guide for beginners
- New `docs/CHEF_SOLO_QUICKSTART.md`: a beginner-friendly, no-prior-Chef-knowledge
  walkthrough covering three scenarios — Cassandra only, Cassandra + AxonOps
  agent, and agent-only (monitoring an existing Cassandra or DSE cluster) —
  plus a troubleshooting section built from the real errors hit and fixed
  while writing this cookbook. Linked from README.md.
- Removed the unused `sysctl` cookbook dependency from `Berksfile`/
  `Berksfile.lock` (and its own transitive `ohai` dependency) — grepped the
  whole codebase confirming no recipe ever calls a resource from either;
  this cookbook writes `/etc/sysctl.d` config directly via plain `file`/
  `directory` resources, it never needed the `sysctl` cookbook at all.

#### DSE 6.7/6.8/6.9 java-agent support, offline download included
- `node['axonops']['cassandra']['dse_version']` attribute (default `'5.1'`) and
  `AxonOpsCassandra.dse_java_agent_package` (`libraries/cassandra_version.rb`),
  mapping DSE series to its real package: `axon-dse5.1-agent`,
  `axon-dse6.7-agent`, `axon-dse6.8-agent`, `axon-dse6.9-agent`. `docs/DSE.md`
  previously only documented 5.1; DSE version can't be auto-detected, so this
  must be set explicitly for anything else.
- `offline_download_helper`/`offline-download-script.sh.erb` now resolve the
  DSE java-agent package from `dse_version` too, and correctly download only
  the agent for `edition == 'dse'` — never a Cassandra package, since this
  cookbook doesn't install/manage DSE.

#### Amazon Linux + package-install correctness, verified end to end on Cassandra 3.11
- Full test harness: ChefSpec unit specs, InSpec controls, Test Kitchen
  configuration with suites for 3.11/4.1/5.0 tarball, package install, GC
  variants, and TLS modes.
- New `axonops.cassandra.start_on_install` attribute (default `false`) —
  Chef no longer starts/restarts Cassandra during converge unless asked;
  needed for controlled multi-node bootstraps.
- New `axonops.cassandra.redhat_repository_url_311x` attribute: 3.11 has no
  official apt channel but does have an RPM mirror (JFrog), matching the
  Ansible role.
- `chefignore`: Chef was treating this repo's dev/test `Gemfile` (chefspec,
  berkshelf, cookstyle...) as part of the cookbook and bundle-installing it
  on every converge — fixed the actual root cause (a stray `gem 'faraday'`
  declaration in `metadata.rb`, unused anywhere in the codebase) and added
  `chefignore` as defense in depth.
- `test/docker/Dockerfile.systemd-ubuntu`, `Dockerfile.systemd-rockylinux`:
  systemd-enabled base images for kitchen-docker CI — AxonOps packages call
  `systemctl` in their postinst scripts, which needs a real init system
  kitchen-docker's stock containers don't have.
- `offline-download-script.sh.erb`: rewritten to use `dnf download`/
  `apt-get download` against the real AxonOps repo (same repo config as
  `recipes/repo.rb`) for `axon-agent`/`axon-server`/`axon-dash`/the
  series-specific `axon-cassandra*-agent` java-agent package, instead of
  guessing download URLs — confirmed via `dnf download --url` that
  packages.axonops.com serves flat, content-hashed filenames with no
  predictable `el${VER}/${ARCH}/name-version.rpm` path. The java-agent jar
  is extracted from that downloaded package (no standalone jar URL exists).
  Also downloads the monitored Cassandra itself as an RPM when
  `install_format == 'pkg'` (3.11 via the JFrog mirror, 4.1/5.0 via
  `redhat.cassandra.apache.org` — both real static paths, unlike the
  AxonOps repo). Elasticsearch/Zulu tarball URLs fixed to use uname-style
  arch names (`aarch64`/`x86_64`), not Debian-style (`arm64`/`amd64`), which
  404 upstream. New `axonops.offline_packages.cassandra_pkg` attribute
  (distinct from the tarball `cassandra` key) for the RPM/deb case.
  Verified end-to-end in a real container: downloaded packages, installed
  from them, both `axon-agent` and `cassandra` (3.11) services came up.

### Fixed

#### `axonops::agent` crashed when run standalone against an existing Cassandra/DSE/Kafka (continued)
- `notifies` resolves its target against the compiled resource collection
  immediately — regardless of whether an `only_if` guard would skip the
  notifying resource at runtime. `ruby_block[configure-jvm-agent]`
  unconditionally notified `service[cassandra]`/`service[kafka]`, but
  those are only ever declared by `recipes/configure_cassandra.rb`/
  `recipes/kafka.rb`, not `recipes/agent.rb` itself — so running
  `axonops::agent` standalone to monitor an existing, cookbook-external
  Cassandra/DSE/Kafka (a common, explicitly documented use case — see
  `docs/DSE.md`) crashed unconditionally with
  `Chef::Exceptions::ResourceNotFound`. Verified live. Now only attaches
  the notification when the target resource genuinely exists in the
  current run (`resources(service: service)`, rescued) — this cookbook
  shouldn't be restarting a service it doesn't manage anyway.

#### Force-selecting DSE edition alone never actually installed anything (continued)
- `docs/DSE.md` documents forcing DSE monitoring explicitly via
  `node.override['axonops']['cassandra']['edition'] = 'dse'` — precisely
  for cases where path-based auto-detection might miss a real,
  non-standard DSE install. But `recipes/agent.rb`'s Cassandra/Kafka
  dispatch `elsif` only ever checked `run_list.include?
  ('recipe[axonops::cassandra]') || cassandra_detected` — an explicitly
  forced `edition: 'dse'` satisfied neither, so it always fell through to
  the `else` branch's `Chef::Log.error("Could not detect Cassandra or
  Kafka"); return` and silently installed nothing. Verified live: a
  DSE-only offline install (`run_list: ["recipe[axonops::agent]"]`,
  `edition: 'dse'`, no real DSE present on the test box) converged with
  "2/22 resources updated" — only the two detection `ruby_block`s ran, no
  package install was even attempted. Added `edition == 'dse'` as a third,
  independently-sufficient condition on that `elsif`.

#### Wrong java-agent version fallback for DSE and non-3.11 series (continued)
- The `'latest'` → real-version fallback for `java_agent_version` was a
  single flat constant (`1.0.14`, `axon-cassandra3.11-agent`'s own latest)
  reused for every `axon-cassandra*-agent`/`axon-dse*-agent` package
  regardless of series — each has an independent release history. Verified
  live: downloading a DSE agent with the 3.11 agent's version failed with
  "No package axon-dse5.1-agent-1.0.14-1.noarch available". Replaced with
  a per-package version map
  (`LATEST_KNOWN_JAVA_AGENT_VERSIONS`) covering all 3.11/4.1/5.0/DSE
  5.1/6.7/6.8/6.9 packages, keyed by the already-resolved
  `java_agent_package` name; raises a clear error naming the missing
  package if a future/custom one isn't in the map, instead of silently
  guessing wrong.

#### Post-download summary printed the java-agent jar instead of the RPM/deb (continued)
- `offline_packages['java_agent']` printed the *extracted jar* filename
  (`axon-cassandra3.11-agent-1.0.14.jar`) — but `recipes/agent.rb`'s
  offline install (`rpm -Uvh`/`dpkg -i`) actually installs the RPM/deb
  package, not the jar; the jar is only consumed separately (and
  automatically, no attribute needed) by the tar/4.1/5.0
  `cassandra-env.sh` sourcing path. Verified live: following the printed
  instructions failed with "not an rpm package (or package manifest)".
  Now prints the real downloaded package filename, same as
  `agent`/`server`/`dashboard`/`cassandra_pkg`/`java` above it.

#### Cassandra package installs never installed Java from a package (continued)
- A Cassandra RPM/deb declares a real `java-X.Y.Z-headless` dependency —
  verified live: `dnf install cassandra-3.11.19-....rpm` alone fails with
  "nothing provides java-1.8.0-headless" against a tarball-only Java
  install, since a manually-extracted tarball JDK is invisible to rpm/dnf/
  dpkg dependency resolution even though `java` itself works fine via
  `alternatives`. `recipes/java.rb`'s offline branch only ever supported
  tarball installs, so any offline `install_format: 'pkg'` Cassandra
  install was broken by construction.
  - `recipes/cassandra.rb` now forces `node['java']['package'] = true`
    whenever `install_format == 'pkg'`, activating `java.rb`'s
    package-based install path instead of tarball (online installs were
    already unaffected, package-based either way).
  - New `node['java']['zulu_headless_packages']` attribute (major → package
    name, e.g. `zulu8-jdk-headless`) — the offline branch now globs for it
    by `java_major` instead of relying solely on a single, non-major-aware
    `offline_packages['java']` filename.
  - The headless JDK package itself has further dependencies (e.g.
    `zulu8-jdk-headless` needs `zulu8-jre-headless` and
    `zulu8-ca-jdk-headless`) that a single-file `rpm -i`/`dpkg -i` can't
    resolve offline — verified live. Installs every matching file in
    `offline_packages_path` together in one `rpm -Uvh`/`dpkg -i`
    transaction, same pattern already used for axon-agent.
  - After install, forces `alternatives --auto java` — the package's own
    postinstall registers a correctly higher-priority alternatives entry,
    but doesn't override a stale *manual* selection left over from a prior
    tarball install on the same box (verified live: `alternatives --list`
    showed both entries, manual one still active until forced).
  - `offline-download-script.sh.erb` downloads the whole dependency chain
    via `dnf download --resolve` (RPM) / `apt-get install
    --download-only` (deb) whenever `install_format == 'pkg'` — a bare
    `dnf download`/`apt-get download` doesn't resolve dependencies at all.
    Verified live end to end: downloaded packages, then
    `recipe[axonops::cassandra]` installed both Cassandra and its Java
    dependency from them with no network access needed.

#### Offline download script never downloaded the actual Cassandra package (continued)
- The false premise from earlier in this branch that `axonops::server`'s own
  metrics-storage Cassandra and the *monitored* Cassandra
  (`axonops::cassandra`) are two independent versions/tarballs led the
  script to always download a hardcoded-default tarball
  (`node['axonops']['server']['cassandra']['version']`, defaulting `5.0.4`)
  regardless of what was actually configured — and never downloaded
  anything at all for `install_format: 'pkg'`. In reality
  `recipes/server.rb` overrides `node['axonops']['cassandra']['*']` from
  `node['axonops']['server']['cassandra']['*']` before calling
  `axonops::cassandra`, so there's only one effective Cassandra config per
  node; `recipes/install_cassandra_tarball.rb`/`install_cassandra_pkg.rb`
  both read from the same `node['axonops']['cassandra']['version']`/
  `install_format`. Rewrote the script to download the real configured
  Cassandra — a tarball (`offline_packages['cassandra']`) for
  `install_format: 'tar'`, or an RPM/deb (`offline_packages['cassandra_pkg']`)
  for `'pkg'` (including a new Debian/Ubuntu `.deb` download path, matching
  the offline branch already added to `install_cassandra_pkg.rb`) — skipped
  entirely for `edition: 'dse'`, which never installs Cassandra. The
  post-download summary now prints whichever one actually got downloaded,
  plus the previously-missing `elasticsearch` line.

#### Offline download script's post-download summary (continued)
- The final "Set the following Chef attributes" summary printed
  `node['axonops']['packages'][...]` — the wrong attribute key throughout
  (real one is `offline_packages`, per `attributes/default.rb`); it also
  used `<%= File.dirname(__FILE__) %>` for the install path, which resolves
  to the `.erb` *template source's* location on the Chef workstation/server
  (e.g. `/var/chef/cache/cookbooks/axonops/templates/default`), not wherever
  the rendered script was actually run from. And it guessed `.deb`-style
  `name_VERSION_ARCH.deb` filenames unconditionally, wrong for the RHEL/
  Amazon branch's real, unpredictable content-hash-prefixed `.rpm` names.
  Now uses `$DOWNLOAD_DIR` (the directory the script is actually running
  from) and captures the real downloaded filename per package via the same
  glob approach already used for the java-agent jar extraction, so the
  summary reflects what's actually on disk.

#### DSE java-agent package name (continued)
- `node['axonops']['java_agent']['dse']` defaulted to `'axon-dse-agent'` — a
  package that doesn't exist on `packages.axonops.com` (confirmed via `dnf
  search dse`/`dnf list`). Every DSE-monitoring install (online and offline)
  was resolving to a 404/missing package. Now `nil` by default, resolved
  dynamically from `dse_version` unless explicitly overridden.

#### Amazon Linux + package-install correctness (continued)
- `offline_install` auto-vivify bug: `node.override['java']['offline_install']
  ||= …` read-then-wrote through the override chain, auto-vivifying an
  empty (truthy) Mash that permanently stuck offline mode on regardless of
  the real flag.
- Amazon Linux `platform_family` gaps in Java install, `tar` package
  install, and `yum_package` → `package` (dnf) resolution — all previously
  only handled `'debian'`/`'rhel','fedora'`.
- `not_if { running_in_container }` in `system_tuning.rb` referenced a
  `def`d method from inside a resource guard block, where `self` is
  rebound to the resource — `NoMethodError`.
- `cassandra-env.sh.erb` unconditionally sourced
  `/usr/share/axonops/axonops-jvm.options` — wrong for every non-5.0
  version and compile-time-guarded (fragile across separate converges).
  Now version-gated to match the Ansible role: 3.11/4.1 get a direct
  `-javaagent:` flag, only 5.0.x sources the override file.
- Java-agent package name was a single hardcoded default
  (`axon-cassandra5.0-agent-jdk17`) despite promising version-based
  auto-selection — every non-5.0 install got the wrong agent build.
- Duplicate, unconditional `/etc/systemd/system/cassandra.service` creation
  hardcoded to the tar layout — shadowed pkg installs' own init integration
  with the wrong `ExecStart`.
- 3.11 `cassandra.yaml` template rendered `legacy_ssl_storage_port_enabled`
  and `accepted_protocols`, keys that don't exist in the 3.11 schema —
  Cassandra refused to start.
- Java version selection: the online Zulu-repo install branch never ran
  `alternatives --set java`, so a box with multiple Zulu majors installed
  could silently run the wrong JDK.
- All 7 shipped `examples/nodes/*.json` wrapped attributes in a `"normal":
  {...}` key — that's node-object JSON format, not chef-solo's flat `-j`
  attribute-file format. None of these examples ever actually applied any
  attribute they set.
- `axon-cassandra*-agent` install: two separate `package` resources for it
  and `axon-agent` ran as two separate transactions, so rpm/dpkg couldn't
  reconcile the `/var/lib/axonops` directory they both ship — combined into
  one resource. `axon-cassandra3.11-agent` also publishes stale legacy
  x86_64 builds alongside newer noarch ones under the same name; dnf
  silently preferred the older, broken x86_64 build — forced the `.noarch`
  arch selector.
- `/etc/sysctl.d` and the `sysctl` binary itself aren't guaranteed present
  on minimal container images — guarded/created defensively.
- `AxonOpsCassandra.series` unsupported-version check now consistently
  raises `ArgumentError` (kept Chef-independent — CI validates this library
  standalone without Chef loaded).

**Reason**: Manually testing `recipe[axonops::cassandra]` end to end (both
tarball and RPM/`install_format: pkg`, on Amazon Linux 2023) surfaced a long
chain of real, previously-undetected bugs. Verified with `nodetool status`
showing the node `UN` and CQL bound on 9042.

#### Offline/airgapped install, verified end to end (download → install → running services)
- `recipes/agent.rb`'s offline branch had the exact same RPM-transaction-split
  bug already fixed for the online path: `axon-cassandra*-agent` and
  `axon-agent` installed as two separate `rpm_package`/`dpkg_package`
  resources, so whichever ran first failed on the unresolved `axon-agent`
  dependency. Fixed the same way — a single `rpm -Uvh`/`dpkg -i` invocation
  installing both files in one transaction.
- `recipes/install_cassandra_pkg.rb`: offline + `install_format: pkg` had no
  install path at all — the online branch's `package 'cassandra'` resource
  resolves from a yum/apt repo that offline mode explicitly skips creating,
  so it had nothing to install from. Added an offline branch that installs
  directly from a local RPM/deb (new `offline_packages.cassandra_pkg`
  attribute), matching the pattern `recipes/agent.rb` already used.
- `recipes/cassandra_self_signed.rb`: `keytool` was invoked bare, relying on
  PATH — but Chef `bash`/`execute` resources don't source
  `/etc/profile.d/java.sh` (login-shell only), so it was never actually
  resolvable even with Java installed. Now resolved from the stable
  `java_home` symlink `recipes/java.rb` maintains.
- `recipes/cassandra_self_signed.rb`: the self-signed cert's SAN extension
  included `dns:#{node['fqdn']}`/`dns:#{node['hostname']}` unfiltered — on a
  host where Ohai can't resolve a hostname (e.g. a bare container), these
  come back blank, and `keytool` rejects the whole `-ext` flag with
  "DNSName must not be null or empty". Blank entries are now filtered out,
  keeping `localhost`/`127.0.0.1` as a guaranteed fallback.
- `recipes/cassandra_self_signed.rb`: added a defensive `package 'openssl'`
  install — the recipe hard-requires it for the DER→PEM conversion steps but
  never ensured it was present.
- `recipes/system_tuning.rb`: `/etc/security/limits.d` and `/etc/default`
  aren't guaranteed present on minimal container images (same reasoning as
  the existing `/etc/sysctl.d` guard) — guarded/created defensively.
- `recipes/common.rb`'s `sysctl-reload` execute resource checked that the
  `sysctl` binary existed but not whether the environment could actually
  write to `/proc/sys` — an unprivileged container has the binary but gets
  "permission denied" regardless. Now skipped in containers, matching
  `system_tuning.rb`'s own existing container-detection guard.

**Reason**: Manually testing offline/airgapped install end to end (download
via the regenerated `offline-download-script.sh.erb`, then
`recipe[axonops::cassandra]` with `offline_install: true` against those
downloaded packages, on Amazon Linux 2023) surfaced this chain of real bugs.
Verified with `systemctl status` showing both `axon-agent` and `cassandra`
`active (running)`, and `nodetool status` showing the node `UN`.

#### Multi-version Cassandra support (epic #19)
- Added `AxonOps::CassandraVersion` library (`libraries/cassandra_version.rb`)
  mapping a Cassandra version to its Java major (3.11→8, 4.1→11, 5.0→17),
  config-template subdirectory, and unit-conversion helpers for the legacy
  3.11 schema.
- Added Apache Cassandra **3.11** support: version-aware Java selection and a
  dedicated legacy `cassandra.yaml` template
  (`templates/default/3.11/cassandra.yaml.erb`) using the integer
  `*_in_ms`/`*_in_mb`/`*_in_kb` keys, Thrift/RPC keys and megabit streaming
  throughput (#20, #22).
- Added version-aware Java package/JAVA_HOME selection driven by
  `node['java']['version']`, with per-major Zulu and OpenJDK package maps (#20).
- Added the missing `cassandra-jvm11-server.options.erb` template, fixing the
  crash when converging Cassandra 4.x (#21).
- Added BDD scaffolding (#28): Gherkin feature files under `features/`, InSpec
  controls under `test/integration/`, and `kitchen.yml` with `cassandra-3-11`
  and `cassandra-default` (5.0) suites; plus runnable RSpec unit specs for the
  version library and the 3.11 template render.

Fixed (found while validating a real 3.11 converge in Docker — Java 8
incompatibilities in the shared templates):
- `cassandra-env.sh` only appends the Java 11+ `-Xlog:gc` unified-logging flag
  when running Java 11+; on 3.11 (Java 8) GC logging comes from `jvm.options`.
- Removed the empty `-XX:MaxDirectMemorySize=` from the 3.x `jvm.options`
  template (an empty value is rejected by the JVM and prevented startup).
- Resolve the `jamm` javaagent jar dynamically in `cassandra-env.sh` instead of
  hardcoding `jamm-0.4.0.jar` (3.11 ships `jamm-0.3.0`).
- Renamed the helper module to `AxonOpsCassandra` to avoid colliding with the
  existing `class AxonOps` in `libraries/axonops.rb`.
- Fixed a Ruby syntax error in `recipes/chef_workstation.rb` (`command if …`).

**Reason**: The Cassandra recipe only supported tarball installs of 5.x with
hardcoded Java 17, a single non-version-specific template, and a broken 4.x
path. This brings it toward parity with the AxonOps Ansible role and adds 3.11.


#### DataStax Enterprise (DSE) 5.1 monitoring and Amazon Linux install support
- Added DSE 5.1 as a Cassandra `edition` (`libraries/cassandra_version.rb`,
  `attributes/cassandra.rb`), auto-detected from `/opt/dse` /
  `/etc/dse/cassandra/cassandra.yaml`. `axonops::agent` now installs the
  `axon-dse-agent` java agent and renders the existing (previously dead) DSE
  metrics branch in `axon-agent.yml.erb`; `axonops::cassandra` detects DSE and
  delegates to the agent instead of attempting to install/reinstall it. See
  `docs/DSE.md`.
- Fixed `recipes/agent.rb` reading the undefined
  `node['axonops']['java_agent']['cassandra']` attribute (always `nil`),
  which broke the java-agent package install for any online, non-DSE
  Cassandra-monitoring install. Now correctly reads
  `node['axonops']['java_agent']['package']`.
- Added `'amazon'` to the `platform_family` case in `recipes/repo.rb` (online
  repo setup) and `recipes/agent.rb` (offline install), and added
  `amazonlinux-2`/`amazonlinux-2023` to the Kitchen test matrix — Amazon
  Linux was declared supported in `metadata.rb` but had no working install
  path or CI coverage.

**Reason**: `metadata.rb` and the README already claimed Amazon Linux support,
and the DSE metrics template branch already existed, but neither was actually
wired up or tested — this closes that doc-vs-implementation gap.

#### Airgapped/offline install parity
- Fixed `recipes/java.rb` never respecting `node['axonops']['offline_install']`
  (only its own separate `node['java']['offline_install']`), which silently
  left Java installs reaching out to the Azul Zulu repo/GPG key during an
  otherwise "offline" Cassandra/Kafka/Elasticsearch/Server install. The
  top-level flag now propagates automatically.
- Removed a duplicate, conflicting definition of
  `node['axonops']['offline_install']`/`offline_packages_path` in
  `attributes/default.rb` (two different path defaults were defined; the
  second silently won).
- Documented `axonops::chef_workstation` as an explicit, intentional exception
  to airgapped support (it installs workstation/operator tooling, not part of
  the target-node install path).
- Added a `cassandra-offline` Kitchen suite exercising `offline_install: true`
  end-to-end, wired into a real GitHub Actions job (`kitchen-offline`) that
  stages the real Apache Cassandra and Zulu JDK 17 tarballs before converging
  — no proprietary AxonOps packages required, no hardcoded/stale filenames
  (Java's is resolved dynamically via Azul's metadata API).

**Reason**: CLAUDE.md's design principles claim full offline installation
capability, but the Java dependency shared by every install recipe silently
ignored the documented flag — airgapped deployments of Cassandra/Kafka/
Elasticsearch/Server were broken despite following the README's instructions.

#### Chef Server Deployment Documentation
- Added comprehensive Chef Server deployment section to README.md
- Included Berkshelf installation and usage instructions
- Added knife.rb configuration example
- Documented cookbook upload process with `berks upload`
- Added support for air-gapped environments with `berks package`

**Reason**: Users needed clear instructions on how to deploy the cookbook to a Chef Server environment, not just use it locally.

#### Node Configuration Documentation
- Added detailed knife commands for node management
- Documented node bootstrapping process
- Added examples for setting run lists and attributes
- Included environment and role management examples
- Added comprehensive deployment status checking commands
- Added troubleshooting section for deployment issues

**Reason**: Provide complete operational guidance for managing nodes with the AxonOps cookbook in production Chef environments.

#### Example Node Configuration Files
- Created `examples/nodes/` directory structure
- Added `cassandra-node.json` - Production Cassandra node example
- Added `server-node.json` - AxonOps server with Elasticsearch
- Added `full-stack-node.json` - All-in-one development setup
- Added `multi-role-node.json` - Complex multi-purpose node
- Added `container-node.json` - Containerized environment example

**Reason**: Provide real-world examples with proper attribute overrides to help users quickly deploy different AxonOps configurations.

#### Chef Workstation Recipe
- Created new `recipes/chef_workstation.rb` recipe
- Supports RHEL/CentOS/Rocky Linux 7+, Ubuntu 18.04+, Amazon Linux 2, Debian 9+
- Installs development tools, Ruby, and Chef Workstation
- Handles platform-specific requirements (EPEL, PowerTools/CRB)
- Creates basic knife.rb template
- Added corresponding attributes in `attributes/default.rb`

**Reason**: Many users need to set up management nodes with knife and Chef tools before they can deploy AxonOps. This recipe automates the prerequisites installation.

#### vm.max_map_count Skip Option
- Added `skip_vm_max_map_count` attribute to `attributes/common.rb`
- Updated `recipes/common.rb` to conditionally set vm.max_map_count
- Updated `recipes/system_tuning.rb` with conditional guard
- Updated `recipes/elasticsearch.rb` with conditional guards
- Added "Running in Restricted Environments" section to README.md
- Updated all example node files with the new attribute

**Reason**: Container environments and managed services often don't allow kernel parameter modifications. This option allows AxonOps to be deployed in such restricted environments.

### Changed

#### README.md Structure
- Reorganized sections for better flow
- Added Chef Server deployment before node configuration
- Enhanced Quick Start section with chef_workstation recipe
- Updated attributes section with new options
- Added new common use case for restricted environments

**Reason**: Improve documentation clarity and ensure users follow the correct deployment sequence.

### Fixed

#### Example File Cookbook Version
- Added `cookbook_version: "0.1.0"` field to all example JSON files
- Files updated:
  - `/examples/alerts/solo.json`
  - `/examples/nodes/cassandra-node.json`
  - `/examples/nodes/container-node.json`
  - `/examples/nodes/full-stack-node.json`
  - `/examples/nodes/multi-role-node.json`
  - `/examples/nodes/server-node.json`

**Reason**: Track which cookbook version the examples were created for, helping users understand compatibility when the cookbook is updated.

#### Example File Attribute Names
- Fixed agent configuration attributes to match recipe expectations:
  - Changed `endpoint` to `hosts` (splitting host:port when needed)
  - Changed `org` to `org_name`
  - Changed `tls` to `tls_mode` with proper values ("disabled", "TLS", "mTLS")
  - Kept `api_key` as-is (recipe already handles this correctly)

- Fixed cassandra configuration attributes:
  - Changed `datacenter` to `dc` in all cassandra sections

- Fixed server configuration attributes:
  - Changed `elasticsearch` to `elastic` in server sections
  - Fixed TLS configuration structure from `enabled: true/false` to `mode: "TLS"/"disabled"`

**Reason**: The example files were using different attribute names than what the cookbook recipes expected, causing the generated configuration files to have default values instead of the user-specified values. These fixes ensure that node configurations work correctly with the cookbook.

### Technical Details

#### Files Created
- `/recipes/chef_workstation.rb` - New recipe for Chef prerequisites
- `/examples/nodes/cassandra-node.json` - Cassandra node example
- `/examples/nodes/server-node.json` - Server node example
- `/examples/nodes/full-stack-node.json` - All-in-one example
- `/examples/nodes/multi-role-node.json` - Multi-role example
- `/examples/nodes/container-node.json` - Container example
- `/CHANGELOG.md` - This file

#### Files Modified
- `/README.md` - Extensive additions for Chef Server deployment and node management
- `/attributes/default.rb` - Added chef_workstation attributes
- `/attributes/common.rb` - Added skip_vm_max_map_count attribute
- `/recipes/common.rb` - Conditional vm.max_map_count setting
- `/recipes/system_tuning.rb` - Added conditional guard
- `/recipes/elasticsearch.rb` - Added conditional guards
- `/examples/alerts/solo.json` - Added cookbook_version field
- `/examples/nodes/cassandra-node.json` - Added cookbook_version field and fixed attribute names
- `/examples/nodes/container-node.json` - Added cookbook_version field and fixed attribute names
- `/examples/nodes/full-stack-node.json` - Added cookbook_version field and fixed attribute names
- `/examples/nodes/multi-role-node.json` - Added cookbook_version field and fixed attribute names
- `/examples/nodes/server-node.json` - Added cookbook_version field and fixed attribute names

### Migration Notes

For existing users:
- The new `skip_vm_max_map_count` attribute defaults to `false`, maintaining current behavior
- The chef_workstation recipe is optional and doesn't affect existing deployments
- All changes are backward compatible

### Contributors
- Brian Stark - Initial Chef Server deployment documentation and implementation

## [0.2.0] - 2025-07-27

### Added
- Added `skip_vm_swappiness` attribute to control vm.swappiness setting
- Added not_if condition to vm.swappiness sysctl resource in system_tuning recipe
- Updated example node configurations to include skip_vm_swappiness attribute

### Changed
- Updated cookbook version from 0.1.0 to 0.2.0 in metadata.rb
- Updated cookbook_version field in all example JSON files to match new version
