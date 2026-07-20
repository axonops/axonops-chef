# AxonOps Chef Cookbook - Cassandra Parity Implementation Plan

This document outlines a detailed, step-by-step plan to implement all outstanding GitHub issues under the Epic **#19: Cassandra recipe parity with Ansible role + Apache Cassandra 3.11 support**.

The plan is divided into priorities (P0, P1, P2) matching the epic's structure, ensuring dependencies are respected.

## Phase 1: Foundation & Critical Fixes (P0)

### 1. Issue #20: Version-aware Java selection
**Problem:** The cookbook currently hardcodes Java 17 for all Cassandra versions, causing failures for Cassandra 3.11 (requires Java 8) and 4.1 (requires Java 11).
**Plan:**
- Edit `recipes/cassandra.rb` before calling `axonops::java`.
- Inspect `node['axonops']['cassandra']['version']`.
- Override Java attributes accordingly:
  - `3.11.x` -> Java 8 (`zulu8-jdk`, `openjdk-8-jdk-headless` / `java-1.8.0-openjdk-headless`)
  - `4.1.x` -> Java 11 (`zulu11-jdk`, `openjdk-11-jdk-headless` / `java-11-openjdk-headless`)
  - `5.0.x` -> Java 17 (current default)
- Set matching `JAVA_HOME` variables through `node.override['java']['zulu_home']` and `openjdk_home`.
- Respect `node['axonops']['cassandra']['skip_java_install']`.

### 2. Issue #30: Fix keystore.jks reference for default client encryption
**Problem:** `client_encryption_options.enabled` defaults to `true` and looks for `/opt/cassandra/conf/keystore.jks`, but `axonops::cassandra_self_signed` generates PEM files instead of a JKS keystore, breaking native transport (CQL).
**Plan:**
- Change the default for `client_encryption_options.enabled` to `false` in `attributes/cassandra.rb` to ensure unencrypted CQL binds smoothly out-of-the-box.
- Alternatively, modify `cassandra_self_signed` to generate the JKS file if TLS is actually intended to be `true` by default. Changing the default to `false` is generally cleaner and matches community defaults for Cassandra.

## Phase 2: Core Parity Features (P1)

### 3. Issue #22: Version-specific config templates & Unit Conversion
**Problem:** Cassandra 3.11 uses legacy integer YAML keys (`_in_ms`, `_in_mb`) and Thrift settings, while 4.x/5.x use duration strings.
**Plan:**
- Create `libraries/cassandra_helpers.rb` with `AxonOps::CassandraHelpers` for parsing strings (e.g., `'5000ms'`, `'128MiB'`, `'24MiB/s'`) into integers (`convert_to_ms`, `convert_to_kb`, `convert_to_mb`, `convert_to_megabits_per_sec`, `convert_to_secs`).
- Reorganize `templates/default/` into `3.11/`, `4.1/`, and `5.0/` subdirectories.
- Create `templates/default/3.11/cassandra.yaml.erb` using `_in_ms` and `_in_mb` keys and include Thrift options (`start_rpc`, etc.).
- Update `configure_cassandra.rb` to select the right template directory and invoke the unit conversion helpers when passing attributes to the 3.11 template.

### 4. Issue #23: Package-repo install method (apt/yum)
**Problem:** Currently only tarball installation is supported. We need system package manager support for 4.1+.
**Plan:**
- Add attribute `node['axonops']['cassandra']['install_format'] = 'tar'` (default).
- Create `recipes/install_cassandra_pkg.rb`.
- Debian: Configure `https://debian.cassandra.apache.org` repository and GPG key, install and hold the `cassandra` package.
- RHEL/Amazon: Configure `https://redhat.cassandra.apache.org` repository and GPG key, install `cassandra-<version>-1`.
- Raise `UnsupportedAction` if `install_format == 'pkg'` and version is `3.11.x`.
- Update `recipes/cassandra.rb` to switch between `install_cassandra_tarball` and `install_cassandra_pkg`.
- Override `conf_dir` attribute (`/etc/cassandra` or `/etc/cassandra/conf`) dynamically.

### 5. Issue #24: Full cassandra.yaml attribute rendering
**Problem:** Most tuning attributes in `attributes/cassandra.rb` (~150 properties) are not rendered into the YAML template.
**Plan:**
- Update `recipes/configure_cassandra.rb` to pass all attributes.
- Use version gating for variables (e.g., `audit_logging_options`, `uuid_sstable_identifiers_enabled`, `sai_*` keys for 5.0).
- Format nested structures as proper Ruby hashes so they render as block YAML.
- Use modern keys for 4.1/5.0 (`read_request_timeout: <%= read_request_timeout %>`) and drop `compaction_throughput_mb_per_sec` from being a standalone hardcoded attribute (use helper instead).

### 6. Issue #25: Enable and complete system_tuning recipe
**Problem:** The `system_tuning.rb` recipe is commented out, has broken namespaces, missing templates, and lacks container-awareness.
**Plan:**
- Fix namespaces: replace `node['cassandra']['system']` with `node['axonops']['cassandra']['sysctl']` and `limits`.
- Remove broken reference to `cassandra_limits.conf.erb` and use `limits.conf.erb`.
- Implement a container guard (`/.dockerenv` or `node['virtualization']['system'] == 'docker'`) to skip `sysctl` rules on containers.
- Write sysctl variables to `/etc/sysctl.d/99-cassandra.conf`.
- Configure `irqbalance` to be disabled via `/etc/default/irqbalance`.
- Install `libjemalloc2` (Debian) or `jemalloc` (RHEL) and inject `LD_PRELOAD` into `cassandra-env.sh.erb`.
- Re-enable the recipe in `recipes/cassandra.rb`.

### 7. Issue #28: BDD Test Harness
**Problem:** Zero test coverage.
**Plan:**
- Configure `kitchen.yml` with Vagrant/Docker drivers for `ubuntu-22.04` and `rockylinux-9` platforms.
- Create Kitchen suites for 3.11-tar, 4.1-tar, 5.0-default, 5.0-pkg, and various GC/TLS configurations.
- Create ChefSpec tests in `spec/unit/recipes/` for testing Java selection, packaging, templating, and tuning logic.
- Create InSpec controls in `test/integration/cassandra/controls/` verifying java version, config files, `jvm.options`, `sysctl`, etc.
- Add Gherkin `*.feature` files documenting expected behaviors for BDD.
- Integrate into `.github/workflows/test.yml`.

## Phase 3: Follow-ups (P2)

### 8. Issue #26: PEM-based TLS support
**Problem:** Cassandra 4.1 introduced `PEMBasedSslContextFactory`, avoiding JKS complexity, but it's not supported in the cookbook.
**Plan:**
- Add `node['axonops']['cassandra']['client_encryption_options']['pem_enabled'] = false` and `server_encryption_options`.
- Update `cassandra.yaml.erb` (for 4.1 and 5.0) to output `PEMBasedSslContextFactory` and the respective `keystore_password`, `outbound_keystore`, etc., using PEM parameters if `pem_enabled` is true.
- Add validations to prevent using PEM TLS for Cassandra 3.11.

### 9. Issue #27: Documentation
**Problem:** The README lacks the required Cassandra version matrix, configuration references, and testing instructions.
**Plan:**
- Add a new `## Apache Cassandra` section to `README.md`.
- Detail the Version support matrix (3.11, 4.1, 5.0) and Install Formats (`tar`, `pkg`).
- Document key Configuration Attributes, Java Version selections, TLS configurations, and System Tuning defaults.
- Create `examples/cassandra_3.11.rb` and `examples/cassandra_pem_tls.rb`.
- Add all Unreleased features and fixes to `CHANGELOG.md`.

---
*Generated by opencode.*
