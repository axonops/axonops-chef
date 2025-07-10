#
# Cookbook:: axonops
# Attributes:: server
#
# Attributes for AxonOps Server self-hosted deployment
#

# Internal Elasticsearch for AxonOps Server
default['axonops']['server']['elastic']['version'] = '7.17.16'
default['axonops']['server']['elastic']['heap_size'] = '512m'
default['axonops']['server']['elastic']['cluster_name'] = 'axonops-cluster'
default['axonops']['server']['elastic']['install_dir'] = '/opt/axonops-elasticsearch'
default['axonops']['server']['elastic']['data_dir'] = '/var/lib/axonops-elasticsearch'
default['axonops']['server']['elastic']['tarball_url'] = nil
default['axonops']['server']['elastic']['tarball_checksum'] = nil

# Internal Cassandra for AxonOps Metrics Storage
default['axonops']['server']['cassandra']['version'] = '5.0.4'
default['axonops']['server']['cassandra']['dc'] = 'axonops'
default['axonops']['server']['cassandra']['username'] = 'cassandra'
default['axonops']['server']['cassandra']['password'] = 'cassandra'
default['axonops']['server']['cassandra']['install_dir'] = '/opt/axonops-cassandra'
default['axonops']['server']['cassandra']['data_dir'] = '/var/lib/axonops-cassandra'
default['axonops']['server']['cassandra']['tarball_url'] = nil
default['axonops']['server']['cassandra']['tarball_checksum'] = nil

# TLS Configuration
default['axonops']['server']['tls']['mode'] = 'disabled' # 'disabled', 'TLS', 'mTLS'
default['axonops']['server']['tls']['cert_file'] = nil
default['axonops']['server']['tls']['key_file'] = nil
default['axonops']['server']['tls']['ca_file'] = nil

# Retention Configuration
default['axonops']['server']['retention']['events'] = 4 # weeks
default['axonops']['server']['retention']['security_events'] = 8 # weeks
default['axonops']['server']['retention']['metrics']['high_resolution'] = 30 # days
default['axonops']['server']['retention']['metrics']['medium_resolution'] = 24 # weeks
default['axonops']['server']['retention']['metrics']['low_resolution'] = 24 # months
default['axonops']['server']['retention']['metrics']['super_low_resolution'] = 3 # years
default['axonops']['server']['retention']['backups']['local'] = 10 # days
default['axonops']['server']['retention']['backups']['remote'] = 30 # days

# Dashboard Configuration
default['axonops']['dashboard']['server_endpoint'] = 'http://127.0.0.1:8080'
default['axonops']['dashboard']['context_path'] = ''
default['axonops']['dashboard']['package'] = 'axon-dash'
default['axonops']['dashboard']['nginx_proxy'] = false
