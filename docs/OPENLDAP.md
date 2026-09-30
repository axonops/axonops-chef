# OpenLDAP for AxonOps Server

`axonops::openldap` installs a local OpenLDAP (`slapd`) directory and seeds it
with users and groups that match AxonOps Server's LDAP role mapping. Use it to
demo or test AxonOps LDAP login and RBAC without a corporate directory.

The recipe:

- installs OpenLDAP from the distribution repositories (EPEL on the RHEL family)
- configures `slapd` through `cn=config` (OLC), not `slapd.conf`
- creates the base DN, a users OU, a groups OU, `groupOfNames` groups and `inetOrgPerson` users
- loads the `memberof` and `refint` overlays, so each user carries a `memberOf` attribute
- optionally enables TLS (LDAPS on 636, StartTLS on 389) with a self-signed or your own certificate
- publishes a ready-made axon-server LDAP block in `node.run_state['axonops_openldap_ldap_setting']`, and can wire `axonops::server` to the directory in the same Chef run

`axonops::server` does not depend on this recipe. You can point axon-server at
any LDAP directory — see [SERVER.md](SERVER.md#authentication-configuration).

## Requirements

- A host with systemd and no OpenLDAP data you need to keep. The recipe replaces an *empty* package-default database (for example the EL `dc=my-domain,dc=com` placeholder created when `slapd` was started once). It stops with an error if that database holds entries.
- Supported platform families: `rhel` (Rocky Linux / RHEL 9) and `debian` (Ubuntu 22.04). Kitchen suites `openldap` and `openldap-tls` cover both.

| Platform family | Packages | Source |
|-----------------|----------|--------|
| `rhel` | `openldap-servers`, `openldap-clients` | EPEL (`openldap-servers`). `epel-release` is installed unless `install_epel` is `false`. |
| `debian` | `slapd`, `ldap-utils` | Distribution repositories. `slapd` is preseeded with `slapd/no_configuration`, so the package does not create its own database. |

## Quick start

Passwords never go in node attributes: those are saved to the Chef Server in
plain text. Set them in `node.run_state` from chef-vault or an encrypted data
bag, in a wrapper recipe that runs before `axonops::openldap`:

```ruby
# my_wrapper/recipes/ldap.rb
secrets = data_bag_item('axonops', 'ldap', Chef::EncryptedDataBagItem.load_secret)

node.run_state['axonops_openldap_admin_password'] = secrets['admin_password']
node.run_state['axonops_openldap_users'] = [
  { 'uid' => 'alice', 'cn' => 'Alice Smith', 'sn' => 'Smith', 'mail' => 'alice@example.com',
    'password' => secrets['alice_password'], 'groups' => ['axonops_super'] },
  { 'uid' => 'bob', 'password' => secrets['bob_password'], 'groups' => ['axonops_readonly'] },
]

include_recipe 'axonops::openldap'
```

Check that a user binds and has the expected groups:

```bash
ldapsearch -x -H ldap://localhost -D "uid=alice,ou=People,dc=axonops,dc=local" -W \
  -b "uid=alice,ou=People,dc=axonops,dc=local" -s base memberOf
```

## Attributes

All attributes live under `node['axonops']['openldap']`.

### Directory

| Attribute | Type | Default | Example | Description |
|-----------|------|---------|---------|-------------|
| `base_dn` | String | `dc=axonops,dc=local` | `dc=example,dc=com` | Directory suffix. Must start with `dc=`. Fixed after the first run |
| `organization` | String | `AxonOps` | `Example Ltd` | `o` attribute of the base entry |
| `admin_dn` | String | `nil` (`cn=admin,<base_dn>`) | `cn=manager,dc=example,dc=com` | Root DN of the database. Fixed after the first run |
| `admin_password` | String | `nil` (**required**) | — | Admin password. Prefer `node.run_state['axonops_openldap_admin_password']` |
| `users_ou` | String | `ou=People` | `ou=Users` | Users OU, relative to `base_dn` |
| `groups_ou` | String | `ou=Groups` | `ou=Teams` | Groups OU, relative to `base_dn` |
| `groups` | Array | four groups, one per AxonOps role | see below | `groupOfNames` groups to create |
| `users` | Array | `[]` | see below | `inetOrgPerson` users to create. Prefer `node.run_state['axonops_openldap_users']` |
| `enable_memberof` | Boolean | `true` | `false` | Load the `memberof` + `refint` overlays. One-way: `false` later does not remove them |

Each entry in `groups`:

| Key | Required | Example | Description |
|-----|----------|---------|-------------|
| `name` | yes | `axonops_admin` | Group `cn` |
| `description` | no | `AxonOps administrators` | Free text |
| `axon_role` | no | `adminRole` | AxonOps role the group maps to: `superUserRole`, `adminRole`, `readOnlyRole` or `backupAdminRole` |

The default groups are `axonops_super` (`superUserRole`), `axonops_admin`
(`adminRole`), `axonops_readonly` (`readOnlyRole`) and `axonops_backup`
(`backupAdminRole`). A group with no users holds the admin DN, because
`groupOfNames` needs at least one member.

Each entry in `users`:

| Key | Required | Example | Description |
|-----|----------|---------|-------------|
| `uid` | yes | `alice` | Login name. Unique |
| `password` | yes | — | Plaintext; stored as an `{SSHA}` hash |
| `cn` | no | `Alice Smith` | Common name. Defaults to `uid` |
| `sn` | no | `Smith` | Surname. Defaults to `uid` |
| `mail` | no | `alice@example.com` | Email address |
| `groups` | no | `['axonops_admin']` | Group names from `groups` |

### Listeners and TLS

| Attribute | Type | Default | Example | Description |
|-----------|------|---------|---------|-------------|
| `listen_ldap` | Boolean | `true` | `false` | Listen on plain LDAP (StartTLS when TLS is on) |
| `ldap_port` | Integer | `389` | `1389` | LDAP port |
| `listen_ldaps` | Boolean | `false` | `true` | Listen on LDAPS. Needs `tls_mode` `generate` or `custom` |
| `ldaps_port` | Integer | `636` | `1636` | LDAPS port |
| `tls_mode` | String | `disabled` | `generate` | `disabled`, `generate` (self-signed) or `custom` |
| `tls_cert` | String | `nil` | `/etc/pki/tls/certs/ldap.crt` | `custom`: certificate path **on the node** |
| `tls_key` | String | `nil` | `/etc/pki/tls/private/ldap.key` | `custom`: private key path on the node |
| `tls_ca` | String | `nil` | `/etc/pki/tls/certs/ca.crt` | `custom`: optional CA path on the node |
| `tls_generate_days` | Integer | `825` | `365` | `generate`: certificate lifetime |
| `tls_common_name` | String | `nil` (node FQDN) | `ldap.example.com` | `generate`: certificate CN |
| `tls_extra_sans` | Array | `[]` | `['DNS:ldap.example.com', 'IP:10.0.0.5']` | `generate`: extra subjectAltName entries |
| `tls_protocol_min` | String | `3.3` | `3.4` | Minimum TLS version: `3.3` = TLS 1.2, `3.4` = TLS 1.3 |

`ldapi:///` is always on: the recipe manages `cn=config` over it as root.

### Service and storage

| Attribute | Type | Default | Example | Description |
|-----------|------|---------|---------|-------------|
| `install_epel` | Boolean | `true` | `false` | RHEL: install `epel-release` |
| `start_on_install` | Boolean | `true` | `false` | Start `slapd`. `false` also skips all `cn=config` changes and seeding |
| `start_on_boot` | Boolean | `true` | `false` | Enable `slapd` at boot |
| `data_dir` | String | `/var/lib/ldap` | `/data/ldap` | MDB database directory |
| `db_max_size` | Integer | `1073741824` (1 GiB) | `4294967296` | MDB map size in bytes |
| `log_level` | String | `stats` | `none` | `olcLogLevel` |

### axon-server integration

| Attribute | Type | Default | Example | Description |
|-----------|------|---------|---------|-------------|
| `axon_server_host` | String | `nil` (`tls_common_name`) | `ldap.internal` | Host name axon-server uses to reach the directory |
| `axon_server_insecure_skip_verify` | Boolean | `nil` (`true` only for `generate`) | `false` | `insecureSkipVerify` for axon-server |
| `configure_server` | Boolean | `false` | `true` | Point `axonops::server` at this directory in the same run |

The recipe always stores this block in
`node.run_state['axonops_openldap_ldap_setting']` (camelCase, as axon-server
reads it; no `bindPassword`):

```ruby
{
  'host' => 'ldap.example.com', 'port' => 389, 'useSSL' => false, 'startTLS' => false,
  'insecureSkipVerify' => false, 'base' => 'dc=axonops,dc=local',
  'bindDN' => 'cn=admin,dc=axonops,dc=local', 'userFilter' => '(uid=%s)',
  'rolesAttribute' => 'memberOf', 'callAttempts' => 3,
  'rolesMapping' => { '_global_' => { 'superUserRole' => 'cn=axonops_super,ou=Groups,dc=axonops,dc=local', ... } }
}
```

With `configure_server` set, it also sets `node['axonops']['server']['auth']`
(enabled, host, port, `use_ssl`, `start_tls`, `insecure_skip_verify`, base,
bind DN, filter, roles) and passes the admin password to the server template
through `node.run_state['axonops_server_ldap_bind_password']`, so it is never
saved as a node attribute.

## Examples

### 1. Standalone directory

```ruby
node.run_state['axonops_openldap_admin_password'] = secrets['admin_password']
node.run_state['axonops_openldap_users'] = [
  { 'uid' => 'alice', 'password' => secrets['alice_password'], 'groups' => ['axonops_admin'] },
]

include_recipe 'axonops::openldap'
```

### 2. Directory with TLS

Self-signed certificate, LDAPS on 636 and StartTLS on 389:

```ruby
node.override['axonops']['openldap']['tls_mode'] = 'generate'
node.override['axonops']['openldap']['listen_ldaps'] = true
node.override['axonops']['openldap']['tls_extra_sans'] = ['DNS:ldap.example.com']
node.run_state['axonops_openldap_admin_password'] = secrets['admin_password']

include_recipe 'axonops::openldap'
```

With your own certificate (files already on the node):

```ruby
node.override['axonops']['openldap']['tls_mode'] = 'custom'
node.override['axonops']['openldap']['tls_cert'] = '/etc/pki/tls/certs/ldap.crt'
node.override['axonops']['openldap']['tls_key'] = '/etc/pki/tls/private/ldap.key'
node.override['axonops']['openldap']['tls_ca'] = '/etc/pki/tls/certs/ca.crt'
node.override['axonops']['openldap']['axon_server_insecure_skip_verify'] = false
```

### 3. Directory plus AxonOps Server with LDAP authentication

```ruby
node.override['axonops']['openldap']['configure_server'] = true
node.override['axonops']['openldap']['axon_server_host'] = '127.0.0.1'
node.run_state['axonops_openldap_admin_password'] = secrets['admin_password']
node.run_state['axonops_openldap_users'] = [
  { 'uid' => 'alice', 'password' => secrets['alice_password'], 'groups' => ['axonops_super'] },
  { 'uid' => 'bob', 'password' => secrets['bob_password'], 'groups' => ['axonops_readonly'] },
]

include_recipe 'axonops::openldap'
include_recipe 'axonops::server'
include_recipe 'axonops::dashboard'
```

Manual end-to-end check:

1. On the server host, confirm `/etc/axonops/axon-server.yml` has `auth.enabled: true`, `type: "LDAP"` and the expected `rolesMapping`.
2. Log in to axon-dash as `alice`. The user gets the super user role.
3. Log in as `bob`. The user gets read-only access.
4. Log in with a wrong password. The login fails.

## Security

- **Cleartext by default.** With `tls_mode` `disabled`, bind passwords cross the network unencrypted, and the recipe logs a warning. Use `generate` or `custom`, with LDAPS or StartTLS, for anything beyond local testing.
- **Anonymous access.** Anonymous clients read only the root DSE and the schema. Directory entries need an authenticated bind. `userPassword` is writable by the entry itself and used only for authentication.
- **Passwords.** No defaults. Set them through `node.run_state` from chef-vault or an encrypted data bag. They are stored as `{SSHA}` hashes, passed to the LDAP tools through a `0600` file (never on the command line), and every resource that handles them is `sensitive`.
- **Bind account for axon-server.** The published setting uses the admin DN as `bindDN`. In a shared environment, create a dedicated user and point axon-server at it instead.
- **`insecureSkipVerify`.** With `generate`, axon-server cannot verify the self-signed certificate, so the setting skips verification and the recipe logs a warning. Trust the CA on the axon-server host and set `axon_server_insecure_skip_verify` to `false`, or use `custom` with a certificate from a trusted CA.

## How it works

1. **Validate.** Checks the admin password, base DN, platform, TLS settings, groups and users. Fails at compile time, before any change.
2. **Install.** Installs the packages. On Debian/Ubuntu, `slapd` is preseeded not to create a database.
3. **Bootstrap.** On the first run only, builds a minimal `cn=config` with `slapadd -n 0`: modules, the core/cosine/nis/inetorgperson schemas and the MDB database at `olcDatabase={1}mdb`. An empty package-default database is replaced; one with entries stops the run.
4. **Service.** Sets the listeners (systemd drop-in on RHEL, `/etc/default/slapd` on Debian/Ubuntu) and starts `slapd`.
5. **Online configuration.** Over `ldapi:///`, the `axonops_ldap_entry` resource sets the log level, TLS files, ACLs and overlays, and `axonops_ldap_password` sets the admin password.
6. **Seeding.** Creates the base entry, OUs, users and groups. A password is re-hashed only when a bind with the configured password fails, so a second run updates nothing.
7. **Publish.** Stores the axon-server LDAP block in `node.run_state`, and wires `axonops::server` when `configure_server` is set.

## Limitations

- One directory host. No replication.
- `base_dn` and `admin_dn` are fixed after the first run.
- `enable_memberof` set to `false` later does not remove the overlays.
- `tls_mode` set back to `disabled` does not remove the TLS settings from `cn=config`.
- Users and groups removed from the attributes are not deleted from the directory.

## Testing

```bash
# Unit (no Docker required)
rspec --options /dev/null spec/unit/libraries/openldap_spec.rb spec/unit/templates/openldap_templates_spec.rb

# Integration (Docker required): Ubuntu 22.04 and Rocky Linux 9
KITCHEN_DRIVER=docker kitchen converge openldap
KITCHEN_DRIVER=docker kitchen converge openldap-tls
```

| Kitchen suite | What it checks (`test/integration/openldap`) |
|---------------|----------------------------------------------|
| `openldap` | Install, seeding, `memberOf`, correct and wrong admin password, anonymous access limits, idempotence |
| `openldap-tls` | `generate` mode, LDAPS on 636, StartTLS on 389, key permissions, idempotence |
