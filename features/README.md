# BDD specifications — Cassandra

These Gherkin `.feature` files are the living specification for the Cassandra
work tracked in [epic #19](https://github.com/axonops/axonops-chef/issues/19).
They are executable via two layers, per the AxonOps BDD standard:

| Layer | Harness | Location | What it proves |
|-------|---------|----------|----------------|
| Unit | ChefSpec + plain RSpec | `spec/unit/` | Recipe logic, version/Java selection, template rendering — runs without Docker |
| Integration | InSpec via Test Kitchen | `test/integration/` | A real converged node: Java, layout, service, valid YAML |

## Scenario → check mapping

| Feature scenario | Verified by |
|------------------|-------------|
| Java major follows Cassandra version | `spec/unit/libraries/cassandra_version_spec.rb`, `test/integration/*/controls/java_spec.rb` |
| cassandra.yaml schema follows version | `spec/unit/templates/cassandra_3_11_yaml_spec.rb`, `test/integration/cassandra-3.11/controls/cassandra_yaml_spec.rb` |
| 3.11 legacy integer-unit schema | `spec/unit/templates/cassandra_3_11_yaml_spec.rb` |
| Per-version JVM option files | `test/integration/*/controls/jvm_options_spec.rb` |
| Temporary directories on/off /tmp (#47) | `spec/unit/templates/cassandra_env_tmpdir_spec.rb` |
| Agent loaded via axonops-jvm.options (ASB-4712) | `spec/unit/templates/cassandra_env_agent_spec.rb`, `spec/unit/libraries/agent_env_spec.rb` |
| Unsupported version fails fast | `spec/unit/libraries/cassandra_version_spec.rb` |
| Converged node layout / service | `test/integration/*/controls/*_spec.rb` |

## Running

```bash
# Unit (no Docker required):
rspec --options /dev/null spec/unit/libraries/cassandra_version_spec.rb
rspec --options /dev/null spec/unit/templates/cassandra_3_11_yaml_spec.rb

# Integration (Docker required):
kitchen test cassandra-3-11
kitchen test cassandra-default
```

Scenarios tagged `@wip` are specified but not yet implemented — they track the
remaining epic #19 sub-issues (package-repo install #23, PEM TLS #26).

## DSE 5.1 monitoring and Amazon Linux install support (epic AD-29)

`features/dse_monitoring.feature` and `features/amazon_linux_install.feature`
cover this epic.

| Feature scenario | Verified by |
|------------------|-------------|
| DSE auto-detection (`/opt/dse`, `/etc/dse/cassandra`) | `spec/unit/recipes/dse_detection_spec.rb` |
| DSE selects `axon-dse-agent` / DSE template branch | `spec/unit/recipes/dse_detection_spec.rb` |
| `axonops::cassandra` never installs/reinstalls DSE | `spec/unit/recipes/dse_detection_spec.rb` |
| Apache Cassandra java-agent package regression check | `spec/unit/recipes/dse_detection_spec.rb` |
| DSE/Apache series → Java major | `spec/unit/libraries/cassandra_version_spec.rb` |
| Amazon Linux yum repository configured | `spec/unit/recipes/dse_detection_spec.rb` (repo.rb not yet covered — see gap below), `test/integration/*` via `kitchen.yml`'s `amazonlinux-2`/`amazonlinux-2023` platforms |
| Amazon Linux offline agent install uses rpm | ChefSpec gap — not yet covered; tracked for a follow-up ticket |
| Fresh Cassandra install on Amazon Linux | `test/integration/cassandra-default` (reused automatically for the new platforms) |

**No DSE Kitchen/InSpec coverage**: DataStax does not distribute a
redistributable DSE Docker image suitable for public CI, so DSE support is
unit-tested only (ChefSpec + the pure-Ruby version library spec).

```bash
# Unit (no Docker required):
rspec --options /dev/null spec/unit/libraries/cassandra_version_spec.rb
chef exec rspec spec/unit/recipes/dse_detection_spec.rb   # requires Chef Workstation; ChefSpec is broken under plain `rspec` locally without Berkshelf

# Integration (Docker required) — exercises amazonlinux-2/amazonlinux-2023 automatically:
kitchen test cassandra-default
```

## Airgapped / offline install (epic AD-37)

`features/airgapped_install.feature` covers this epic.

| Feature scenario | Verified by |
|------------------|-------------|
| Top-level flag propagates into java.offline_install | `spec/unit/recipes/java_offline_spec.rb` |
| Real end-to-end offline Cassandra install, zero egress | `kitchen.yml`'s `cassandra-offline` suite, `.github/workflows/ci.yml`'s `kitchen-offline` job (stages real Cassandra + Java tarballs; agent packages not covered here — see the ChefSpec above) |
| Standalone `java.offline_install` override still works | `spec/unit/recipes/java_offline_spec.rb` |
| `chef_workstation` is a documented exception | manual — see README.md's airgapped section |

```bash
# Unit (no Docker required):
chef exec rspec spec/unit/recipes/java_offline_spec.rb   # requires Chef Workstation; broken under plain `rspec` locally without Berkshelf

# Integration (Docker + network access to stage packages first):
kitchen test cassandra-offline
```

## Agent detection via a nested Cassandra install

`axonops::agent`'s java-agent-package selection originally matched Cassandra
only via a literal `recipe[axonops::cassandra]` entry in `node.run_list`. A
node running `axonops::server` (which installs Cassandra through a *nested*
`include_recipe`, never itself listed in `node.run_list`) never matched, so
the agent package — including the java agent — was silently never installed,
and axon-server's own Cassandra started without it.

| Scenario | Verified by |
|----------|-------------|
| `axonops::agent` installs the Cassandra java agent when only `axonops::server` (not `axonops::cassandra`) is in run_list | `spec/unit/recipes/agent_via_server_spec.rb` (ChefSpec; `continue-on-error` in CI like the other recipe specs, alongside `spec/unit/recipes/dse_detection_spec.rb`) |
| `axonops::agent` still installs it via the pre-existing literal-run_list path | `spec/unit/recipes/dse_detection_spec.rb` |

## Reports v2 (ASB-4652)

`features/reports_v2.feature` covers the `axon-reporting` service.

| Feature scenario | Verified by |
|------------------|-------------|
| axon-dash reporting_url (set, empty, independent of install) | `spec/unit/templates/reporting_templates_spec.rb` |
| axon-server axon_reporting_url gated on 2.0.39 / latest | `spec/unit/libraries/reporting_spec.rb`, `spec/unit/templates/reporting_templates_spec.rb` |
| Package install / offline skip | not covered — `axon-reporting` is not in the public repositories yet |

## OpenSearch snapshot repositories (`axonops::opensearch`)

`features/opensearch/snapshot.feature` covers S3/GCS snapshot repositories.

| Feature scenario | Verified by |
|------------------|-------------|
| Off by default | `spec/unit/templates/opensearch_snapshot_yml_spec.rb` |
| Invalid settings fail before any change | `spec/unit/libraries/opensearch_snapshot_spec.rb` |
| Client settings in opensearch.yml, never credentials | `spec/unit/libraries/opensearch_snapshot_spec.rb`, `spec/unit/templates/opensearch_snapshot_yml_spec.rb` |
| Keystore entries, instance identity, stale entries removed | `spec/unit/libraries/opensearch_snapshot_spec.rb` |
| S3 and GCS plugin, keystore and opensearch.yml on a node | `test/integration/opensearch-snapshot` via Kitchen suites `opensearch-snapshot-s3`, `opensearch-snapshot-gcs` |
| Second converge changes nothing | `.github/workflows/test.yml` job `kitchen-opensearch-snapshot` |
| Repository and policy registration | `spec/unit/libraries/opensearch_snapshot_spec.rb` (request bodies, policy diff); not covered against a live bucket |

```bash
rspec --options /dev/null spec/unit/libraries/opensearch_snapshot_spec.rb spec/unit/templates/opensearch_snapshot_yml_spec.rb
KITCHEN_DRIVER=docker kitchen converge opensearch-snapshot-s3
```

## OpenLDAP (`axonops::openldap`)

`features/openldap.feature` covers the local directory.

| Feature scenario | Verified by |
|------------------|-------------|
| Invalid settings fail before any change | `spec/unit/libraries/openldap_spec.rb` |
| Group membership, role mapping, published axon-server setting | `spec/unit/libraries/openldap_spec.rb` |
| Bootstrap LDIF, systemd listeners | `spec/unit/templates/openldap_templates_spec.rb` |
| Optional LDAP keys and run_state bind password in axon-server.yml | `spec/unit/templates/reporting_templates_spec.rb` |
| Fresh host, anonymous limits, wrong password, TLS | `test/integration/openldap` via Kitchen suites `openldap`, `openldap-tls` |
| Second converge changes nothing | `.github/workflows/test.yml` job `kitchen-openldap` |
| Existing directory with data is refused | not covered by an automated test |

```bash
# Unit (no Docker required):
rspec --options /dev/null spec/unit/libraries/openldap_spec.rb spec/unit/libraries/reporting_spec.rb \
  spec/unit/templates/openldap_templates_spec.rb spec/unit/templates/reporting_templates_spec.rb

# Integration (Docker required):
KITCHEN_DRIVER=docker kitchen converge openldap
KITCHEN_DRIVER=docker kitchen converge openldap-tls
```
