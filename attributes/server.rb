#
# Cookbook:: axonops
# Attributes:: server
#
# Attributes for AxonOps Server self-hosted deployment
#

default['axonops']['server']['version'] = 'latest' # Default to latest version
default['axonops']['server']['package'] = 'axon-server'

# Organisation name. Must match the agents' ['axonops']['agent']['org_name'].
# Written to axon-server.yml as org_name when set.
default['axonops']['server']['org_name'] = nil
# License key. Without it axon-server runs in development mode and ignores
# LDAP auth. Prefer node.run_state['axonops_server_license_key'] (from
# chef-vault or an encrypted data bag): node attributes are saved to the Chef
# Server in plain text.
default['axonops']['server']['license_key'] = nil

# Internal OpenSearch for AxonOps Server (previously Elasticsearch — switched
# to OpenSearch, installed as a real RPM/deb package from OpenSearch's own
# repo rather than a manually-extracted tarball; see recipes/opensearch.rb
# and docs/OPENSEARCH.md). The 'elastic' attribute namespace is kept as-is
# to minimize disruption for existing node configs — it now configures
# OpenSearch, not Elasticsearch.
default['axonops']['server']['elastic']['version'] = '3.8.0'
default['axonops']['server']['elastic']['heap_size'] = '512m'
default['axonops']['server']['elastic']['cluster_name'] = 'axonops-cluster'
default['axonops']['server']['elastic']['data_dir'] = '/var/lib/opensearch'
default['axonops']['server']['elastic']['logs_dir'] = '/var/log/opensearch'
default['axonops']['server']['elastic']['listen_address'] = '127.0.0.1'
default['axonops']['server']['elastic']['listen_port'] = 9200
default['axonops']['server']['elastic']['install'] = true
# Java temporary directory (-Djava.io.tmpdir). OpenSearch's JVM unpacks and
# executes native libraries here at startup; on a CIS-hardened host /tmp is
# mounted noexec and the JVM fails to load them. Point java.io.tmpdir (and
# OPENSEARCH_TMPDIR, which the launcher otherwise derives from mktemp under
# /tmp) at an executable directory the cookbook owns. Set to '' or '/tmp' to
# keep the OS default and create no directory. See recipes/opensearch.rb.
default['axonops']['server']['elastic']['java_tmp_dir'] = '/var/lib/opensearch/tmp'
# OpenSearch's security plugin (auth + TLS) is enabled by default upstream and
# needs its own certs/admin password setup, unrelated to the manual
# self-signed-cert approach the old Elasticsearch tarball install used —
# disabled by default here to match that install's previous no-auth
# behavior. Set true and configure plugins.security.* yourself (see
# docs/OPENSEARCH.md) for a production-hardened setup.
default['axonops']['server']['elastic']['security_plugin_enabled'] = false

# Snapshot repository (S3 or GCS). Installs the repository-s3/repository-gcs
# plugin, loads credentials into opensearch.keystore and registers the
# repository. Installing the plugin restarts OpenSearch. See
# docs/OPENSEARCH.md#snapshot-repositories-s3gcs.
default['axonops']['server']['elastic']['snapshot']['enabled'] = false
# 's3' (AWS S3 or any S3-compatible store) or 'gcs'
default['axonops']['server']['elastic']['snapshot']['type'] = 's3'
# Client name used in the s3.client.<name>.* / gcs.client.<name>.* settings
default['axonops']['server']['elastic']['snapshot']['client'] = 'default'
# nil means '<type>-snapshots'
default['axonops']['server']['elastic']['snapshot']['repository_name'] = nil
default['axonops']['server']['elastic']['snapshot']['bucket'] = ''
default['axonops']['server']['elastic']['snapshot']['base_path'] = ''
# Register the repository and policy through the REST API. Set false when
# they are managed elsewhere; the plugin and credentials are still installed.
default['axonops']['server']['elastic']['snapshot']['register'] = true
# Leave access_key/secret_key empty to use the instance identity (EC2
# instance profile or IRSA). Keep real keys in an encrypted data bag or vault.
default['axonops']['server']['elastic']['snapshot']['s3']['access_key'] = ''
default['axonops']['server']['elastic']['snapshot']['s3']['secret_key'] = ''
default['axonops']['server']['elastic']['snapshot']['s3']['session_token'] = ''
default['axonops']['server']['elastic']['snapshot']['s3']['region'] = ''
# For S3-compatible stores (Hetzner Object Storage, MinIO, Ceph RGW), e.g.
# 'fsn1.your-objectstorage.com' with region 'fsn1'
default['axonops']['server']['elastic']['snapshot']['s3']['endpoint'] = ''
# 'http' or 'https'; empty keeps the plugin default (https)
default['axonops']['server']['elastic']['snapshot']['s3']['protocol'] = ''
default['axonops']['server']['elastic']['snapshot']['s3']['path_style_access'] = false
# Other non-secret s3.client.<client>.* settings, e.g.
# { 'max_retries' => 5 }
default['axonops']['server']['elastic']['snapshot']['s3']['extra_settings'] = {}
# Service-account JSON, as a string or a hash. Leave empty to use the GCE/GKE
# workload identity.
default['axonops']['server']['elastic']['snapshot']['gcs']['credentials_json'] = ''
default['axonops']['server']['elastic']['snapshot']['gcs']['project_id'] = ''
default['axonops']['server']['elastic']['snapshot']['gcs']['endpoint'] = ''
# Snapshot Management policy, created or updated when not empty. 'name' is the
# policy name; the other keys are the _plugins/_sm/policies request body.
# snapshot_config.repository defaults to the repository name.
default['axonops']['server']['elastic']['snapshot']['policy'] = {}

# Preferred alias namespace — set any of these to override the matching
# 'elastic' key above without touching it. recipes/opensearch.rb merges
# 'elastic' as the base and 'opensearch' as the override (opensearch wins
# key-by-key when set). Left empty by default so the merge is a no-op.
default['axonops']['server']['opensearch'] = {}

# Search DB configuration (new format) — axon-server's own connection to
# OpenSearch. http:// by default to match security_plugin_enabled = false
# above; switch to https:// if you enable the security plugin.
default['axonops']['server']['search_db']['hosts'] = ['http://localhost:9200/']
default['axonops']['server']['search_db']['username'] = nil
default['axonops']['server']['search_db']['password'] = nil
default['axonops']['server']['search_db']['skip_verify'] = true
default['axonops']['server']['search_db']['replicas'] = 0
default['axonops']['server']['search_db']['shards'] = 1

# Internal Cassandra for AxonOps Metrics Storage
default['axonops']['server']['cassandra']['version'] = '5.0.9'
default['axonops']['server']['cassandra']['cluster_name'] = nil
default['axonops']['server']['cassandra']['dc'] = nil
default['axonops']['server']['cassandra']['rack'] = nil
default['axonops']['server']['cassandra']['username'] = 'cassandra'
default['axonops']['server']['cassandra']['password'] = 'cassandra'
default['axonops']['server']['cassandra']['install_dir'] = '/opt'
default['axonops']['server']['cassandra']['data_dir'] = '/var/lib/axonops-data'
default['axonops']['server']['cassandra']['data_file_directories'] = ['/var/lib/cassandra/data']
default['axonops']['server']['cassandra']['compaction_strategy'] = 'SizeTieredCompactionStrategy'
default['axonops']['server']['cassandra']['install'] = true
default['axonops']['server']['cassandra']['hosts'] = ['127.0.0.1:9042']
default['axonops']['server']['cassandra']['keyspace_replication'] = "{ 'class' : 'SimpleStrategy', 'replication_factor' : 1 }"

# TLS Configuration
default['axonops']['server']['tls']['mode'] = 'disabled' # 'disabled', 'TLS', 'mTLS'
default['axonops']['server']['tls']['cert_file'] = nil
default['axonops']['server']['tls']['key_file'] = nil
default['axonops']['server']['tls']['ca_file'] = nil

# Alert Log Configuration
default['axonops']['server']['alert_log']['enabled'] = false
default['axonops']['server']['alert_log']['path'] = '/var/log/axonops/axon-server-alert.log'
default['axonops']['server']['alert_log']['max_size_mb'] = 50
default['axonops']['server']['alert_log']['max_files'] = 5

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

default['axonops']['dashboard']['package'] = 'axon-dash'

# LDAP Authentication Configuration (optional, disabled by default)
default['axonops']['server']['auth']['enabled'] = false
default['axonops']['server']['auth']['type'] = 'LDAP'
default['axonops']['server']['auth']['base'] = 'ou=Users,o=example,dc=example,dc=com'
default['axonops']['server']['auth']['bind_dn'] = 'uid=ldapbind,ou=Users,o=example,dc=example,dc=com'
default['axonops']['server']['auth']['bind_password'] = 'changeme'
default['axonops']['server']['auth']['host'] = 'ldap.example.com'
default['axonops']['server']['auth']['port'] = 636
default['axonops']['server']['auth']['use_ssl'] = true
default['axonops']['server']['auth']['user_filter'] = '(uid=%s)'
default['axonops']['server']['auth']['roles_attribute'] = 'memberOf'
# Optional axon-server LDAP keys. nil leaves the key out of axon-server.yml.
default['axonops']['server']['auth']['start_tls'] = nil
default['axonops']['server']['auth']['insecure_skip_verify'] = nil
default['axonops']['server']['auth']['call_attempts'] = nil

# LDAP Role Mappings
default['axonops']['server']['auth']['roles_mapping'] = {
  '_global_' => {
    'adminRole' => 'cn=axonops-admin,ou=Groups,o=example,dc=example,dc=com',
    'backupAdminRole' => 'cn=axonops-backup-admin,ou=Groups,o=example,dc=example,dc=com',
    'readOnlyRole' => 'cn=axonops-readonly,ou=Groups,o=example,dc=example,dc=com',
    'superUserRole' => 'cn=axonops-superuser,ou=Groups,o=example,dc=example,dc=com'
  }
}

# Dashboard Configuration
default['axonops']['dashboard']['listen_address'] = node['ipaddress']
default['axonops']['dashboard']['listen_port'] = 3000
default['axonops']['dashboard']['server_endpoint'] = 'http://127.0.0.1:8080'
default['axonops']['dashboard']['context_path'] = ''
default['axonops']['dashboard']['nginx_proxy'] = false

# Reports v2 (ASB-4652) — axon-reporting replaces axon-dash-pdf/axon-dash-pdf2.
# It MUST run on the same host as axon-dash, so axonops::dashboard installs it
# (see recipes/reporting.rb). Set enabled to false when reporting runs
# elsewhere, for example in a separate container.
default['axonops']['dashboard']['reporting']['enabled'] = true
# AXON_REPORTING_URL: where axon-dash reaches the reporting service. Written to
# axon-dash.yml as axon-dash.reporting_url. Independent of 'enabled' so
# axon-dash can target a remote reporting service. Set to '' or nil to omit.
default['axonops']['dashboard']['reporting']['url'] = 'http://127.0.0.1:8081'

# axon-reporting package settings.
default['axonops']['reporting']['package'] = 'axon-reporting'
default['axonops']['reporting']['version'] = 'latest'
default['axonops']['reporting']['state'] = 'present' # 'present' or 'absent'
default['axonops']['reporting']['start_at_boot'] = true

# URL where axon-server reaches axon-reporting (AXON_REPORTING_URL). Written to
# axon-server.yml as axon_reporting_url for axon-server >= 2.0.39 (and
# 'latest'). Override when axon-dash runs on a different host to axon-server.
default['axonops']['server']['reporting_url'] = 'http://127.0.0.1:8081'

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
