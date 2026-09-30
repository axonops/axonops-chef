#
# Cookbook:: axonops
# Attributes:: openldap
#
# Local OpenLDAP (slapd) directory for axon-server LDAP authentication and
# role mapping — see recipes/openldap.rb and docs/OPENLDAP.md. Configuration
# uses cn=config (OLC). Ported from the axonops.axonops.openldap Ansible role.
#

# Directory suffix. Changing it after the first run is not supported: the
# database is bootstrapped once and the suffix is fixed from then on.
default['axonops']['openldap']['base_dn'] = 'dc=axonops,dc=local'
# Value of the "o" attribute on the base entry.
default['axonops']['openldap']['organization'] = 'AxonOps'
# Root (admin) DN of the directory database. nil = "cn=admin,<base_dn>".
default['axonops']['openldap']['admin_dn'] = nil

# REQUIRED, no default. Prefer node.run_state['axonops_openldap_admin_password']
# set from chef-vault or an encrypted data bag in a wrapper recipe: node
# attributes are saved to the Chef Server in plain text.
default['axonops']['openldap']['admin_password'] = nil

default['axonops']['openldap']['users_ou'] = 'ou=People'
default['axonops']['openldap']['groups_ou'] = 'ou=Groups'

# Groups created as groupOfNames under groups_ou.
#   name:        group cn (required)
#   description: free text (optional)
#   axon_role:   axon-server rolesMapping key (optional): superUserRole,
#                adminRole, readOnlyRole or backupAdminRole.
default['axonops']['openldap']['groups'] = [
  { 'name' => 'axonops_super', 'description' => 'AxonOps super users', 'axon_role' => 'superUserRole' },
  { 'name' => 'axonops_admin', 'description' => 'AxonOps administrators', 'axon_role' => 'adminRole' },
  { 'name' => 'axonops_readonly', 'description' => 'AxonOps read-only users', 'axon_role' => 'readOnlyRole' },
  { 'name' => 'axonops_backup', 'description' => 'AxonOps backup administrators', 'axon_role' => 'backupAdminRole' },
]

# Users created as inetOrgPerson under users_ou.
#   uid:      login name (required)
#   password: plaintext password, stored as an {SSHA} hash (required)
#   cn, sn:   common name / surname (optional, default to uid)
#   mail:     email address (optional)
#   groups:   list of group names from 'groups' (optional)
# As with admin_password, set users with passwords from a wrapper recipe
# (node.run_state['axonops_openldap_users']) rather than node attributes.
default['axonops']['openldap']['users'] = []

# Load the memberof + refint overlays so users carry memberOf. axon-server
# needs this when rolesAttribute is memberOf. One-way switch: false after the
# first run does not remove the overlays.
default['axonops']['openldap']['enable_memberof'] = true

# Listeners
default['axonops']['openldap']['listen_ldap'] = true
default['axonops']['openldap']['ldap_port'] = 389
default['axonops']['openldap']['listen_ldaps'] = false
default['axonops']['openldap']['ldaps_port'] = 636

# TLS: 'disabled', 'generate' (self-signed certificate) or 'custom'.
default['axonops']['openldap']['tls_mode'] = 'disabled'
# Paths ON THE NODE to the certificate, key and optional CA, for 'custom'.
default['axonops']['openldap']['tls_cert'] = nil
default['axonops']['openldap']['tls_key'] = nil
default['axonops']['openldap']['tls_ca'] = nil
# Settings for 'generate'.
default['axonops']['openldap']['tls_generate_days'] = 825
# nil = the node's FQDN.
default['axonops']['openldap']['tls_common_name'] = nil
# Extra subjectAltName entries, e.g. ['DNS:ldap.example.com', 'IP:10.0.0.5'].
default['axonops']['openldap']['tls_extra_sans'] = []
# Minimum TLS version: '3.3' = TLS 1.2, '3.4' = TLS 1.3.
default['axonops']['openldap']['tls_protocol_min'] = '3.3'

# Server
default['axonops']['openldap']['install_epel'] = true # RHEL: server packages come from EPEL
# false skips starting slapd AND all cn=config changes and seeding, because
# those need a running slapd on ldapi:///. Only install and bootstrap run.
default['axonops']['openldap']['start_on_install'] = true
default['axonops']['openldap']['start_on_boot'] = true
default['axonops']['openldap']['data_dir'] = '/var/lib/ldap'
default['axonops']['openldap']['db_max_size'] = 1_073_741_824 # 1 GiB
default['axonops']['openldap']['log_level'] = 'stats'

# axon-server integration
# Host name axon-server uses to reach this directory. nil = tls_common_name.
default['axonops']['openldap']['axon_server_host'] = nil
# insecureSkipVerify for axon-server. nil = true only for tls_mode 'generate',
# because axon-server does not trust the self-signed certificate.
default['axonops']['openldap']['axon_server_insecure_skip_verify'] = nil
# When true, point axonops::server's LDAP auth at this directory in the same
# Chef run (sets node['axonops']['server']['auth'] and passes the admin
# password to the server template through node.run_state).
default['axonops']['openldap']['configure_server'] = false
