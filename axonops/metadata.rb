name 'axonops'
maintainer 'AxonOps Team'
maintainer_email 'support@axonops.com'
license 'Apache-2.0'
description 'Installs and configures AxonOps monitoring platform for Apache Cassandra'
version '0.1.0'
chef_version '>= 14.0'

issues_url 'https://github.com/axonops/axonops-chef/issues'
source_url 'https://github.com/axonops/axonops-chef'

supports 'ubuntu', '>= 20.04'
supports 'debian', '>= 11.0'
supports 'almalinux', '>= 8.0'
supports 'rocky', '>= 8.0'
supports 'redhat', '>= 8.0'

# Dependencies are managed within recipes for testing
# In production, uncomment these:
# depends 'java', '~> 8.0'
# depends 'ark', '~> 5.0'
# depends 'ulimit', '~> 1.0'
