name 'axonops'
maintainer 'AxonOps'
maintainer_email 'support@axonops.com'
license 'Apache-2.0'
description 'Installs/Configures AxonOps monitoring and management platform for Apache Cassandra'
version '0.1.0'
chef_version '>= 16.0'

# The long_description is optional and can be read from README.md if it exists
long_description <<-EOD
The AxonOps cookbook provides recipes for installing and configuring the AxonOps
monitoring and management platform. It supports:

- AxonOps Agent installation on Cassandra nodes
- AxonOps Server installation (self-hosted)
- AxonOps Dashboard installation
- Apache Cassandra installation (optional)
- Elasticsearch installation for metrics storage (optional)
- API-based configuration management
- Support for both SaaS and self-hosted deployments
- Airgapped/offline installation support
EOD

# Cookbook dependencies
depends 'yum', '>= 5.0'
depends 'apt', '>= 7.0'

# Supported platforms
supports 'ubuntu', '>= 18.04'
supports 'debian', '>= 9.0'
supports 'centos', '>= 7.0'
supports 'redhat', '>= 7.0'
supports 'amazon', '>= 2.0'

# Source and issues URLs
source_url 'https://github.com/axonops/axonops-chef'
issues_url 'https://github.com/axonops/axonops-chef/issues'

# Gems required
gem 'faraday'
gem 'faraday-multipart'

# Recipes
recipe 'axonops::default', 'Default recipe - includes common setup'
recipe 'axonops::agent', 'Installs and configures AxonOps agent on Cassandra nodes'
recipe 'axonops::server', 'Installs and configures AxonOps server (self-hosted)'
recipe 'axonops::dashboard', 'Installs and configures AxonOps dashboard'
recipe 'axonops::cassandra', 'Installs Apache Cassandra'
recipe 'axonops::elasticsearch', 'Installs Elasticsearch for metrics storage'
recipe 'axonops::java', 'Installs Java/Zulu JDK'
recipe 'axonops::configure', 'Configures AxonOps via API'
recipe 'axonops::system_tuning', 'Applies system tuning for Cassandra'
recipe 'axonops::offline', 'Supports offline/airgapped installation'

# Attributes
attribute 'axonops/agent/enabled',
  display_name: 'Enable AxonOps Agent',
  description: 'Whether to install and enable the AxonOps agent',
  type: 'boolean',
  default: 'true'

attribute 'axonops/server/enabled',
  display_name: 'Enable AxonOps Server',
  description: 'Whether to install and enable the AxonOps server',
  type: 'boolean',
  default: 'false'

attribute 'axonops/server/mode',
  display_name: 'AxonOps Server Mode',
  description: 'Server mode: "saas" or "self-hosted"',
  type: 'string',
  default: 'saas',
  choice: ['saas', 'self-hosted']

attribute 'axonops/cassandra/install',
  display_name: 'Install Cassandra',
  description: 'Whether to install Apache Cassandra',
  type: 'boolean',
  default: 'false'

attribute 'axonops/java/install',
  display_name: 'Install Java',
  description: 'Whether to install Java/Zulu JDK',
  type: 'boolean',
  default: 'true'

attribute 'axonops/elasticsearch/install',
  display_name: 'Install Elasticsearch',
  description: 'Whether to install Elasticsearch for metrics storage',
  type: 'boolean',
  default: 'false'