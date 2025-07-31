#
# Cookbook:: axonops
# Attributes:: server
#
# Attributes for AxonOps Server self-hosted deployment
#

# Internal Elasticsearch for AxonOps Server
default['axonops']['server']['elastic']['version'] = '7.17.26'
default['axonops']['server']['elastic']['heap_size'] = '512m'
default['axonops']['server']['elastic']['cluster_name'] = 'axonops-cluster'
default['axonops']['server']['elastic']['install_dir'] = '/opt/axonops-search'
default['axonops']['server']['elastic']['data_dir'] = '/var/lib/axonops-search/data'
default['axonops']['server']['elastic']['logs_dir'] = '/var/log/axonops-search'
default['axonops']['server']['elastic']['tarball_url'] = nil
default['axonops']['server']['elastic']['tarball_checksum'] = nil
default['axonops']['server']['elastic']['listen_address'] = '127.0.0.1'
default['axonops']['server']['elastic']['listen_port'] = 9200
default['axonops']['server']['elastic']['tarball_url'] = 'https://artifacts.elastic.co/downloads/elasticsearch'
default['axonops']['server']['elastic']['install'] = true

# Search DB configuration (new format)
default['axonops']['server']['search_db']['hosts'] = ['http://localhost:9200/']
default['axonops']['server']['search_db']['username'] = nil
default['axonops']['server']['search_db']['password'] = nil
default['axonops']['server']['search_db']['skip_verify'] = false
default['axonops']['server']['search_db']['replicas'] = 0
default['axonops']['server']['search_db']['shards'] = 1

# Internal Cassandra for AxonOps Metrics Storage
default['axonops']['server']['cassandra']['version'] = '5.0.4'
default['axonops']['server']['cassandra']['cluster_name'] = 'axonops-cluster'
default['axonops']['server']['cassandra']['dc'] = 'axonops'
default['axonops']['server']['cassandra']['username'] = 'cassandra'
default['axonops']['server']['cassandra']['password'] = 'cassandra'
default['axonops']['server']['cassandra']['install_dir'] = '/opt'
default['axonops']['server']['cassandra']['data_dir'] = '/var/lib/axonops-data'
default['axonops']['server']['cassandra']['data_file_directories'] = ['/var/lib/cassandra/data']
default['axonops']['server']['cassandra']['compaction_strategy'] = 'SizeTieredCompactionStrategy'
default['axonops']['server']['cassandra']['install'] = true
default['axonops']['server']['cassandra']['hosts'] = ['localhost:9042']

# TLS Configuration
default['axonops']['server']['tls']['mode'] = 'disabled' # 'disabled', 'TLS', 'mTLS'
default['axonops']['server']['tls']['cert_file'] = nil
default['axonops']['server']['tls']['key_file'] = nil
default['axonops']['server']['tls']['ca_file'] = nil

# Retention Configuration
default['axonops']['server']['retention']['events'] = '4w' # weeks
default['axonops']['server']['retention']['security_events'] = '8w' # weeks
default['axonops']['server']['retention']['metrics']['high_resolution'] = '30d' # days
default['axonops']['server']['retention']['metrics']['medium_resolution'] = '24w' # weeks
default['axonops']['server']['retention']['metrics']['low_resolution'] = '24M' # months
default['axonops']['server']['retention']['metrics']['super_low_resolution'] = '3y' # years
default['axonops']['server']['retention']['backups']['local'] = '10d' # days
default['axonops']['server']['retention']['backups']['remote'] = '30d' # days

# Server Configuration
# Package name is set in attributes/default.rb
# For offline installation, override with full RPM/DEB filename in node attributes

# Dashboard Configuration
default['axonops']['dashboard']['listen_address'] = node['ipaddress']
default['axonops']['dashboard']['listen_port'] = 3000
default['axonops']['dashboard']['server_endpoint'] = 'http://127.0.0.1:8080'
default['axonops']['dashboard']['context_path'] = ''
default['axonops']['dashboard']['package'] = 'axon-dash'
default['axonops']['dashboard']['nginx_proxy'] = false

# Nginx proxy configuration for dashboard
default['axonops']['dashboard']['nginx']['server_name'] = node['fqdn'] || node['hostname']
default['axonops']['dashboard']['nginx']['listen_port'] = 80
default['axonops']['dashboard']['nginx']['ssl_enabled'] = false
default['axonops']['dashboard']['nginx']['ssl_port'] = 443
default['axonops']['dashboard']['nginx']['ssl_certificate'] = nil
default['axonops']['dashboard']['nginx']['ssl_certificate_key'] = nil
default['axonops']['dashboard']['nginx']['client_max_body_size'] = '10M'
default['axonops']['dashboard']['nginx']['proxy_read_timeout'] = 90
default['axonops']['dashboard']['nginx']['proxy_connect_timeout'] = 30
default['axonops']['dashboard']['nginx']['proxy_send_timeout'] = 90
