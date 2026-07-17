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
