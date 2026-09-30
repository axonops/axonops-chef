#
# Cookbook:: axonops
# Recipe:: openldap
#
# Installs a local OpenLDAP (slapd) directory and seeds it with users and
# groups that match axon-server's LDAP rolesMapping, so LDAP login and RBAC
# can be demoed and tested without a corporate directory. Ported from the
# axonops.axonops.openldap Ansible role.
#
# - cn=config is bootstrapped once with slapadd; everything that can change
#   later (log level, TLS, ACLs, overlays, passwords, entries) is applied
#   online over ldapi:/// so reruns are idempotent.
# - Publishes node.run_state['axonops_openldap_ldap_setting'], a ready-made
#   axon-server auth block (without bindPassword). With
#   node['axonops']['openldap']['configure_server'] it also points
#   axonops::server at this directory.
#
# Secrets: set node.run_state['axonops_openldap_admin_password'] (and
# node.run_state['axonops_openldap_users'] when users carry passwords) from
# chef-vault or an encrypted data bag in a wrapper recipe that runs first.
#

attrs = node['axonops']['openldap'].to_hash
attrs['admin_password'] = node.run_state['axonops_openldap_admin_password'] if node.run_state['axonops_openldap_admin_password']
attrs['users'] = node.run_state['axonops_openldap_users'] if node.run_state['axonops_openldap_users']

cfg = AxonOpsOpenLDAP.resolve(attrs, fqdn: node['fqdn'] || node['hostname'])
AxonOpsOpenLDAP.validate!(cfg, node['platform_family'])

plat = AxonOpsOpenLDAP.platform(node['platform_family'])
config_root = plat['config_root']
slapd_d = "#{config_root}/slapd.d"
tls_dir = "#{config_root}/tls"
data_dir = cfg['data_dir']
start = cfg['start_on_install']
admin_dn = cfg['admin_dn']
admin_password = cfg['admin_password']

# ----------------------------------------------------------------------------
# Install
# ----------------------------------------------------------------------------

apt_update 'openldap' do
  action :periodic
  only_if { platform_family?('debian') }
end

package 'epel-release' do
  only_if { platform_family?('rhel') && cfg['install_epel'] }
end

# Stop the Debian package from creating its own directory and database.
execute 'openldap-preseed-slapd' do
  command 'echo "slapd slapd/no_configuration boolean true" | debconf-set-selections'
  only_if { platform_family?('debian') }
  not_if { ::File.exist?('/usr/sbin/slapd') }
end

package plat['packages']

# ----------------------------------------------------------------------------
# Bootstrap cn=config (first run only)
# ----------------------------------------------------------------------------

# Decided at compile time: installing the packages neither creates the
# role-managed {1}mdb config nor starts slapd, so the on-disk state here is
# what the converge phase sees.
mdb_config = "#{slapd_d}/cn=config/olcDatabase={1}mdb.ldif"
bootstrap = !::File.exist?(mdb_config)
replace_default_db = false

# A data.mdb without our {1}mdb config usually means slapd was started once
# with the package default database (dc=my-domain,dc=com on EL). That is safe
# to replace only if every existing MDB database is empty.
if bootstrap && ::File.exist?("#{data_dir}/data.mdb")
  listing = shell_out!('slapcat', '-F', slapd_d, '-n', '0', '-a', '(objectClass=olcMdbConfig)')
  suffixes = listing.stdout.scan(/^olcSuffix: (.+)$/).flatten
  populated = suffixes.reject { |suffix| shell_out!('slapcat', '-F', slapd_d, '-b', suffix).stdout.strip.empty? }
  unless populated.empty?
    raise "#{data_dir}/data.mdb exists but #{slapd_d} has no olcDatabase={1}mdb entry, and the existing " \
          "database (#{suffixes.join(', ')}) holds entries. This host already runs an OpenLDAP directory " \
          'that axonops::openldap did not create, and it will not replace it. Move the existing data and ' \
          'configuration away, or use a clean host.'
  end
  replace_default_db = true
end

if replace_default_db
  service 'openldap-stop-default-slapd' do
    service_name 'slapd'
    action :stop
  end

  %w(data.mdb lock.mdb).each do |db_file|
    file "#{data_dir}/#{db_file}" do
      action :delete
    end
  end
end

if bootstrap
  bootstrap_ldif = "#{config_root}/axonops-bootstrap.ldif"

  directory 'openldap-remove-package-cn-config' do
    path slapd_d
    recursive true
    action :delete
  end

  directory slapd_d do
    owner plat['user']
    group plat['group']
    mode '0750'
  end

  template bootstrap_ldif do
    source 'openldap-bootstrap.ldif.erb'
    owner 'root'
    group 'root'
    mode '0600'
    variables(
      run_dir: plat['run_dir'],
      module_path: plat['module_path'],
      modules: plat['modules'],
      schema_dir: plat['schema_dir'],
      data_dir: data_dir,
      base_dn: cfg['base_dn'],
      admin_dn: admin_dn,
      db_max_size: cfg['db_max_size']
    )
  end

  execute 'openldap-slapadd-cn-config' do
    command ['slapadd', '-n', '0', '-F', slapd_d, '-l', bootstrap_ldif]
    creates mdb_config
  end

  execute 'openldap-chown-cn-config' do
    command ['chown', '-R', "#{plat['user']}:#{plat['group']}", slapd_d]
  end

  file bootstrap_ldif do
    action :delete
  end
end

directory data_dir do
  owner plat['user']
  group plat['group']
  mode '0700'
end

# ----------------------------------------------------------------------------
# TLS material
# ----------------------------------------------------------------------------

unless cfg['tls_mode'] == 'disabled'
  directory tls_dir do
    owner 'root'
    group plat['group']
    mode '0750'
  end

  if cfg['tls_mode'] == 'generate'
    package 'openssl'

    sans = AxonOpsOpenLDAP.tls_sans(cfg, node['hostname'])
    execute 'openldap-generate-self-signed-certificate' do
      command ['openssl', 'req', '-x509', '-newkey', 'rsa:4096', '-sha256', '-nodes',
               '-days', cfg['tls_generate_days'].to_s,
               '-subj', "/CN=#{cfg['tls_common_name']}",
               '-addext', "subjectAltName=#{sans.join(',')}",
               '-keyout', "#{tls_dir}/server.key",
               '-out', "#{tls_dir}/server.crt"]
      creates "#{tls_dir}/server.crt"
    end

    # Ownership and mode for the generated files.
    { 'server.key' => '0640', 'server.crt' => '0644' }.each do |name, file_mode|
      file "#{tls_dir}/#{name}" do
        owner 'root'
        group plat['group']
        mode file_mode
      end
    end

    # The self-signed certificate is its own CA.
    file "#{tls_dir}/ca.crt" do
      content lazy { ::File.read("#{tls_dir}/server.crt") }
      owner 'root'
      group plat['group']
      mode '0644'
    end
  else
    { 'server.crt' => cfg['tls_cert'], 'ca.crt' => cfg['tls_ca'] }.each do |dest, src|
      next if AxonOpsOpenLDAP.blank?(src)

      file "#{tls_dir}/#{dest}" do
        content lazy { ::File.read(src) }
        owner 'root'
        group plat['group']
        mode '0644'
        notifies :restart, 'service[slapd]', :delayed if start
      end
    end

    file "#{tls_dir}/server.key" do
      content lazy { ::File.read(cfg['tls_key']) }
      owner 'root'
      group plat['group']
      mode '0640'
      sensitive true
      notifies :restart, 'service[slapd]', :delayed if start
    end
  end
end

# ----------------------------------------------------------------------------
# Listeners and service
# ----------------------------------------------------------------------------

urls = AxonOpsOpenLDAP.listener_urls(cfg)

execute 'openldap-systemd-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

if platform_family?('rhel')
  directory '/etc/systemd/system/slapd.service.d' do
    owner 'root'
    group 'root'
    mode '0755'
  end

  template '/etc/systemd/system/slapd.service.d/axonops.conf' do
    source 'openldap-slapd-override.conf.erb'
    owner 'root'
    group 'root'
    mode '0644'
    variables(user: plat['user'], urls: urls)
    notifies :run, 'execute[openldap-systemd-daemon-reload]', :immediately
    notifies :restart, 'service[slapd]', :immediately if start
  end
else
  services_line = "SLAPD_SERVICES=\"#{urls.join(' ')}\""

  ruby_block 'openldap-set-slapd-services' do
    block do
      edit = Chef::Util::FileEdit.new('/etc/default/slapd')
      edit.search_file_replace_line(/^SLAPD_SERVICES=/, services_line)
      edit.insert_line_if_no_match(/^SLAPD_SERVICES=/, services_line)
      edit.write_file
    end
    not_if { ::File.readlines('/etc/default/slapd', chomp: true).include?(services_line) }
    notifies :restart, 'service[slapd]', :immediately if start
  end
end

service 'slapd' do
  supports status: true, restart: true
  actions = []
  actions << (cfg['start_on_boot'] ? :enable : :disable)
  actions << :start if start
  action actions
end

# ----------------------------------------------------------------------------
# cn=config settings and directory entries (need a running slapd)
# ----------------------------------------------------------------------------

if start
  ruby_block 'openldap-wait-for-ldapi' do
    block do
      client = AxonOpsOpenLDAP::Client.new
      ready = 10.times.any? do
        next true if client.ready?

        sleep 2
        false
      end
      raise 'slapd did not answer on ldapi:/// after 20 seconds' unless ready
    end
    not_if { AxonOpsOpenLDAP::Client.new.ready? }
  end

  axonops_ldap_entry 'cn=config' do
    ldap_attrs('olcLogLevel' => cfg['log_level'])
  end

  unless cfg['tls_mode'] == 'disabled'
    axonops_ldap_entry 'openldap-tls-config' do
      dn 'cn=config'
      ldap_attrs AxonOpsOpenLDAP.tls_attrs(cfg, config_root)
      notifies :restart, 'service[slapd]', :delayed
    end
  end

  # Anonymous reads of the root DSE and schema only.
  axonops_ldap_entry 'olcDatabase={-1}frontend,cn=config' do
    ldap_attrs('olcAccess' => ['to dn.base="" by * read', 'to dn.base="cn=Subschema" by * read'])
    ordered ['olcAccess']
  end

  # Directory data readable only by authenticated users.
  axonops_ldap_entry 'olcDatabase={1}mdb,cn=config' do
    ldap_attrs('olcAccess' => ['to attrs=userPassword by self write by anonymous auth by * none',
                               'to * by self read by users read by * none'])
    ordered ['olcAccess']
  end

  if cfg['enable_memberof']
    axonops_ldap_entry 'olcOverlay={0}memberof,olcDatabase={1}mdb,cn=config' do
      object_classes %w(olcOverlayConfig olcMemberOf)
      create_attrs(
        'olcOverlay' => '{0}memberof',
        'olcMemberOfRefInt' => 'TRUE',
        'olcMemberOfGroupOC' => 'groupOfNames',
        'olcMemberOfMemberAD' => 'member',
        'olcMemberOfMemberOfAD' => 'memberOf'
      )
    end

    axonops_ldap_entry 'olcOverlay={1}refint,olcDatabase={1}mdb,cn=config' do
      object_classes %w(olcOverlayConfig olcRefintConfig)
      create_attrs('olcOverlay' => '{1}refint', 'olcRefintAttribute' => %w(memberof member))
    end
  end

  # A bind to the root DN fails with "Invalid credentials" until olcRootPW
  # holds the right hash; only that result rewrites it.
  axonops_ldap_password admin_dn do
    password admin_password
    target_dn 'olcDatabase={1}mdb,cn=config'
    password_attr 'olcRootPW'
    rewrite_on :invalid_credentials
    sensitive true
  end

  # --- Seed entries, bound as the admin DN --------------------------------

  axonops_ldap_entry cfg['base_dn'] do
    object_classes %w(dcObject organization)
    create_attrs('dc' => AxonOpsOpenLDAP.base_dc(cfg['base_dn']), 'o' => cfg['organization'])
    bind_dn admin_dn
    bind_password admin_password
    sensitive true
  end

  [AxonOpsOpenLDAP.users_dn(cfg), AxonOpsOpenLDAP.groups_dn(cfg)].each do |ou_dn|
    axonops_ldap_entry ou_dn do
      object_classes %w(organizationalUnit)
      bind_dn admin_dn
      bind_password admin_password
      sensitive true
    end
  end

  cfg['users'].each do |user|
    user_dn = AxonOpsOpenLDAP.user_dn(cfg, user['uid'])
    user_attrs = { 'cn' => user['cn'] || user['uid'], 'sn' => user['sn'] || user['uid'] }
    user_attrs['mail'] = user['mail'] if user['mail']

    axonops_ldap_entry user_dn do
      object_classes %w(inetOrgPerson)
      ldap_attrs user_attrs
      bind_dn admin_dn
      bind_password admin_password
      sensitive true
    end

    axonops_ldap_password user_dn do
      password user['password']
      target_dn user_dn
      manager_dn admin_dn
      manager_password admin_password
      sensitive true
    end
  end

  members = AxonOpsOpenLDAP.group_members(cfg)
  cfg['groups'].each do |group|
    group_attrs = { 'member' => members[group['name']] }
    group_attrs['description'] = group['description'] if group['description']

    axonops_ldap_entry AxonOpsOpenLDAP.group_dn(cfg, group['name']) do
      object_classes %w(groupOfNames)
      ldap_attrs group_attrs
      bind_dn admin_dn
      bind_password admin_password
      sensitive true
    end
  end
end

# ----------------------------------------------------------------------------
# axon-server integration
# ----------------------------------------------------------------------------

ldap_setting = AxonOpsOpenLDAP.axon_server_ldap_setting(cfg)
node.run_state['axonops_openldap_ldap_setting'] = ldap_setting

if cfg['configure_server']
  auth = node.default['axonops']['server']['auth']
  auth['enabled'] = true
  auth['type'] = 'LDAP'
  auth['host'] = ldap_setting['host']
  auth['port'] = ldap_setting['port']
  auth['use_ssl'] = ldap_setting['useSSL']
  auth['start_tls'] = ldap_setting['startTLS']
  auth['insecure_skip_verify'] = ldap_setting['insecureSkipVerify']
  auth['base'] = ldap_setting['base']
  auth['bind_dn'] = ldap_setting['bindDN']
  auth['user_filter'] = ldap_setting['userFilter']
  auth['roles_attribute'] = ldap_setting['rolesAttribute']
  auth['call_attempts'] = ldap_setting['callAttempts']
  auth['roles_mapping'] = ldap_setting['rolesMapping']
  # Kept out of node attributes so it is never saved to the Chef Server.
  node.run_state['axonops_server_ldap_bind_password'] = admin_password
end

if cfg['tls_mode'] == 'disabled'
  log 'openldap-tls-disabled' do
    message "axonops.openldap.tls_mode is 'disabled': bind passwords cross the network in cleartext. " \
            "Use this only for local testing; set tls_mode to 'generate' or 'custom' and use ldaps or " \
            'StartTLS for anything else.'
    level :warn
  end
elsif ldap_setting['insecureSkipVerify']
  log 'openldap-insecure-skip-verify' do
    message 'axon-server LDAP settings use insecureSkipVerify: true, so axon-server will not verify this ' \
            "directory's certificate. Trust the CA on the axon-server host and set " \
            'axonops.openldap.axon_server_insecure_skip_verify to false.'
    level :warn
  end
end
