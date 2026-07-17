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
