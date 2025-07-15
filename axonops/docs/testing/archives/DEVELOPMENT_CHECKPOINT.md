AxonOps Chef Cookbook - Development Checkpoint

  Date: 2025-01-10

  Current Status

  What's Been Completed

  1. Chef Cookbook Structure Created
    - Basic cookbook with recipes for Cassandra installation
    - Templates for Cassandra configuration files
    - Test Kitchen configuration for offline testing
  2. Download Script
    - Created scripts/download_offline_packages.py
    - Currently has hardcoded URLs (needs updating to dynamic)
    - Supports checksum verification
    - Has both interactive and CLI modes
  3. Cassandra Installation Recipes
    - recipes/install_cassandra_tarball.rb - Installs from tarball
    - recipes/configure_cassandra.rb - Configures Cassandra
    - recipes/java.rb - Installs Java (supports tarball mode)
  4. Templates Created
    - templates/default/cassandra.yaml.erb
    - templates/default/cassandra-jvm-server.options.erb
    - templates/default/cassandra-logback.xml.erb
    - templates/default/cassandra-rackdc.properties.erb
  5. Test Configuration
    - .kitchen.offline.yml - Tests offline installation
    - Configured to use aarch64 Java for ARM VMs

  Current Issue

  - Architecture Mismatch: Fixed in .kitchen.offline.yml to use aarch64 Java
  - Claude Code File Persistence: Changes to files not being saved properly

  Pending Changes That Need to Be Applied

  1. Update Download Script for Dynamic Version Fetching

  The download script needs to be updated to dynamically fetch latest versions instead of hardcoding URLs.

  Key changes needed in scripts/download_offline_packages.py:

  # Add imports
  import re
  import time
  from html.parser import HTMLParser

  # Add to __init__
  self.version_cache_file = 'version_cache.json'
  self.cache_ttl = 3600  # 1 hour

  # Add --java-arch argument
  self.parser.add_argument('--java-arch', choices=['x64', 'aarch64'], default='x64',
                          help='Java architecture (default: x64)')

  # Add caching methods
  def get_cached_version(self, key):
      """Get cached version info if not expired."""
      # Implementation provided in previous messages

  def set_cached_version(self, key, data):
      """Cache version info."""
      # Implementation provided in previous messages

  # Update methods to fetch latest versions dynamically:
  # - get_latest_zulu_java_17_url() - Uses Azul API
  # - get_latest_cassandra_version() - Parses Apache website
  # - get_latest_elasticsearch_version() - Uses GitHub API

  2. Update .gitignore

  Add to .gitignore:
  # Version cache from download script
  scripts/version_cache.json

  Next Steps to Complete

  1. Fix Download Script
    - Apply all dynamic version fetching changes
    - Test with: python scripts/download_offline_packages.py --package-type deb --components java --java-arch aarch64
   --non-interactive
  2. Complete Offline Cassandra Test
    - Run: KITCHEN_YAML=.kitchen.offline.yml KITCHEN_LOCAL_YAML=.kitchen.local.yml bundle exec kitchen test
  cassandra-offline -c
    - Verify Cassandra starts successfully with correct Java architecture
  3. Implement AxonOps Components (TODO)
    - Create recipes/install_axonops_agent.rb
    - Create recipes/install_axonops_server.rb
    - Create recipes/install_axonops_dashboard.rb
    - Create recipes/install_elasticsearch_tarball.rb
  4. Create AxonOps Templates (TODO)
    - templates/default/axonops-agent.yml.erb
    - templates/default/axonops-server.properties.erb
    - templates/default/elasticsearch.yml.erb
  5. Complete Test Suite (TODO)
    - Add InSpec tests for all components
    - Create ChefSpec unit tests
    - Add integration tests for full stack

  Important Configuration Details

  Java Architecture Mapping:
  - x64 → downloads linux_x64 tarball
  - aarch64 → downloads linux_aarch64 tarball

  Offline Installation Path:
  - Downloads stored in ./offline_packages/
  - Mounted in VM at /tmp/offline_packages
  - Recipes check node['axonops']['offline_install'] attribute

  Component Versions:
  - Cassandra: Support 5.0.x, 4.1.x, 4.0.x, 3.11.x
  - Elasticsearch: 7.17.x (recommended), 8.x
  - Java: Azul Zulu JDK 17 (latest)
  - AxonOps: Always latest

  Commands for Quick Resume

  # Change to cookbook directory
  cd /Users/johnny/Development/axonops-chef/axonops

  # Download packages for ARM64
  python scripts/download_offline_packages.py --package-type deb --components java cassandra --java-arch aarch64
  --non-interactive

  # Test offline Cassandra installation
  KITCHEN_YAML=.kitchen.offline.yml KITCHEN_LOCAL_YAML=.kitchen.local.yml bundle exec kitchen test cassandra-offline
  -c

  # If test fails, check logs
  KITCHEN_YAML=.kitchen.offline.yml kitchen login cassandra-offline
  sudo journalctl -u cassandra -f

  User Requirements Reminder

  1. Only support tarball installation for Cassandra (no package managers)
  2. Implement checksum verification for all downloads
  3. Support both interactive and CLI modes for download script
  4. Group downloads by component type
  5. Test offline/airgapped installation first
  6. AxonOps components can use repositories for online installation

  Architecture Decision

  - Chef cookbook approach (not Ansible)
  - Comprehensive testing with Test Kitchen
  - Support for offline/airgapped deployments
  - Multi-platform support (Ubuntu, CentOS, etc.)

  Resume Instructions

  1. First, manually verify and apply the dynamic version fetching changes to the download script
  2. Test the download script with aarch64 architecture
  3. Run the offline Cassandra test to ensure it works with the correct Java architecture
  4. Continue with implementing AxonOps components installation

  Files That May Need Manual Verification

  Due to the persistence issue, verify these files have the correct content:
  - /Users/johnny/Development/axonops-chef/axonops/scripts/download_offline_packages.py
  - /Users/johnny/Development/axonops-chef/axonops/.kitchen.offline.yml
  - /Users/johnny/Development/axonops-chef/axonops/.gitignore