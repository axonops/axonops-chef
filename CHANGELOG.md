# Changelog

All notable changes to the AxonOps Chef Cookbook will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-07-27

### Added
- Added `skip_vm_swappiness` attribute to control vm.swappiness setting
- Added not_if condition to vm.swappiness sysctl resource in system_tuning recipe
- Updated example node configurations to include skip_vm_swappiness attribute

### Changed
- Updated cookbook version from 0.1.0 to 0.2.0 in metadata.rb
- Updated cookbook_version field in all example JSON files to match new version

## [Unreleased] - 2025-07-27

### Added

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
