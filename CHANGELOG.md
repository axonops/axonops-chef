# Changelog

All notable changes to the AxonOps Chef Cookbook will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - 2025-07-27

### Added

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

### Migration Notes

For existing users:
- The new `skip_vm_max_map_count` attribute defaults to `false`, maintaining current behavior
- The chef_workstation recipe is optional and doesn't affect existing deployments
- All changes are backward compatible

### Contributors
- Brian Stark - Initial Chef Server deployment documentation and implementation