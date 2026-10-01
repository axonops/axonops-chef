# Pure-Ruby unit spec for the AxonOpsOpenLDAP library (axonops::openldap).
#
# Evaluates attributes/openldap.rb so the real cookbook defaults are tested.
# No ChefSpec/Berkshelf:
#
#   rspec --options /dev/null spec/unit/libraries/openldap_spec.rb
#
require_relative '../../../libraries/openldap'

RSpec.describe AxonOpsOpenLDAP do
  # Evaluates attributes/openldap.rb against an auto-vivifying hash so
  # `default['axonops']['openldap'][key] = value` works outside Chef.
  let(:defaults) do
    store = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
    evaluator = Object.new
    evaluator.define_singleton_method(:default) { store }
    evaluator.instance_eval(File.read(File.expand_path('../../../attributes/openldap.rb', __dir__)))
    described_class.deep_dup(store['axonops']['openldap'])
  end

  let(:users) do
    [
      { 'uid' => 'alice', 'password' => 'alice-pw', 'cn' => 'Alice Smith', 'sn' => 'Smith',
        'mail' => 'alice@example.com', 'groups' => ['axonops_admin'] },
      { 'uid' => 'bob', 'password' => 'bob-pw', 'groups' => %w(axonops_readonly axonops_admin) },
    ]
  end

  let(:cfg) do
    described_class.resolve(defaults.merge('admin_password' => 'admin-pw', 'users' => users),
                            fqdn: 'ldap.example.com')
  end

  def validation_error(overrides, family = 'debian')
    described_class.validate!(cfg.merge(overrides), family)
    nil
  rescue ArgumentError => e
    e.message
  end

  describe '.resolve' do
    it 'derives the admin DN from the base DN' do
      expect(cfg['admin_dn']).to eq('cn=admin,dc=axonops,dc=local')
    end

    it 'uses the FQDN as TLS common name and axon-server host' do
      expect(cfg['tls_common_name']).to eq('ldap.example.com')
      expect(cfg['axon_server_host']).to eq('ldap.example.com')
    end

    it 'skips certificate verification only for a generated certificate' do
      expect(cfg['axon_server_insecure_skip_verify']).to be false
      generated = described_class.resolve(defaults.merge('tls_mode' => 'generate'), fqdn: 'h')
      expect(generated['axon_server_insecure_skip_verify']).to be true
    end

    it 'keeps an explicit axon-server host' do
      explicit = described_class.resolve(defaults.merge('axon_server_host' => 'dir.internal'), fqdn: 'h')
      expect(explicit['axon_server_host']).to eq('dir.internal')
    end
  end

  describe '.validate!' do
    it 'accepts the defaults with an admin password' do
      expect(described_class.validate!(cfg, 'debian')).to be true
      expect(described_class.validate!(cfg, 'rhel')).to be true
    end

    it 'rejects a missing admin password without printing a password' do
      message = validation_error('admin_password' => nil)
      expect(message).to include('admin password is not set')
      expect(message).not_to include('alice-pw')
    end

    it 'rejects a base DN that does not start with dc=' do
      expect(validation_error('base_dn' => 'o=axonops')).to include('must start with a dc= component')
    end

    it 'rejects an unsupported platform family' do
      expect(validation_error({}, 'suse')).to include("unsupported platform_family 'suse'")
    end

    it 'rejects an unknown TLS mode' do
      expect(validation_error('tls_mode' => 'maybe')).to include('tls_mode must be one of')
    end

    it 'rejects custom TLS without certificate and key' do
      expect(validation_error('tls_mode' => 'custom')).to include('custom needs tls_cert and tls_key')
    end

    it 'rejects LDAPS without TLS' do
      expect(validation_error('listen_ldaps' => true)).to include('listen_ldaps needs tls_mode')
    end

    it 'rejects turning off every listener' do
      expect(validation_error('listen_ldap' => false)).to include('at least one of listen_ldap')
    end

    it 'rejects a TLS protocol other than 1.2 or 1.3' do
      expect(validation_error('tls_protocol_min' => '3.1')).to include('tls_protocol_min must be 3.3')
    end

    it 'rejects an unknown axon role' do
      groups = [{ 'name' => 'ops', 'axon_role' => 'godRole' }]
      expect(validation_error('groups' => groups, 'users' => [])).to include("axon_role 'godRole'")
    end

    it 'rejects a group without a name' do
      expect(validation_error('groups' => [{ 'name' => '' }], 'users' => [])).to include('needs a name')
    end

    it 'rejects duplicate uids' do
      dupes = [{ 'uid' => 'a', 'password' => 'x' }, { 'uid' => 'a', 'password' => 'y' }]
      expect(validation_error('users' => dupes)).to include('uids must be unique')
    end

    it 'rejects a user without a password and does not echo other passwords' do
      message = validation_error('users' => users + [{ 'uid' => 'carol' }])
      expect(message).to include('non-empty string password')
      expect(message).not_to include('alice-pw')
    end

    it 'rejects a user in an undeclared group' do
      bad = [{ 'uid' => 'dave', 'password' => 'x', 'groups' => ['nope'] }]
      expect(validation_error('users' => bad)).to include('not listed in groups: nope')
    end
  end

  describe '.listener_urls' do
    it 'serves ldap and ldapi by default' do
      expect(described_class.listener_urls(cfg)).to eq(['ldap://:389/', 'ldapi:///'])
    end

    it 'adds ldaps when enabled and always keeps ldapi' do
      urls = described_class.listener_urls(cfg.merge('listen_ldap' => false, 'listen_ldaps' => true))
      expect(urls).to eq(['ldaps://:636/', 'ldapi:///'])
    end
  end

  describe '.group_members' do
    it 'lists user DNs per group' do
      members = described_class.group_members(cfg)
      expect(members['axonops_admin']).to eq(['uid=alice,ou=People,dc=axonops,dc=local',
                                              'uid=bob,ou=People,dc=axonops,dc=local'])
      expect(members['axonops_readonly']).to eq(['uid=bob,ou=People,dc=axonops,dc=local'])
    end

    it 'puts the admin DN in an empty group (groupOfNames needs a member)' do
      expect(described_class.group_members(cfg)['axonops_super']).to eq(['cn=admin,dc=axonops,dc=local'])
    end
  end

  describe '.axon_server_ldap_setting' do
    let(:setting) { described_class.axon_server_ldap_setting(cfg) }

    it 'maps every axon role to its group DN' do
      expect(setting['rolesMapping']['_global_']).to eq(
        'superUserRole' => 'cn=axonops_super,ou=Groups,dc=axonops,dc=local',
        'adminRole' => 'cn=axonops_admin,ou=Groups,dc=axonops,dc=local',
        'readOnlyRole' => 'cn=axonops_readonly,ou=Groups,dc=axonops,dc=local',
        'backupAdminRole' => 'cn=axonops_backup,ou=Groups,dc=axonops,dc=local'
      )
    end

    it 'uses plain LDAP on 389 without TLS' do
      expect(setting.values_at('port', 'useSSL', 'startTLS')).to eq([389, false, false])
    end

    it 'uses StartTLS on 389 when TLS is on but LDAPS is off' do
      tls = described_class.axon_server_ldap_setting(cfg.merge('tls_mode' => 'custom'))
      expect(tls.values_at('port', 'useSSL', 'startTLS')).to eq([389, false, true])
    end

    it 'uses LDAPS on 636 when LDAPS is on' do
      ldaps = described_class.axon_server_ldap_setting(cfg.merge('tls_mode' => 'generate', 'listen_ldaps' => true))
      expect(ldaps.values_at('port', 'useSSL', 'startTLS')).to eq([636, true, false])
    end

    it 'never carries a bind password' do
      expect(setting.keys).not_to include('bindPassword')
      expect(setting.to_s).not_to include('admin-pw')
    end
  end

  describe '.tls_attrs' do
    it 'sets the CA file for a generated certificate' do
      attrs = described_class.tls_attrs(cfg.merge('tls_mode' => 'generate'), '/etc/ldap')
      expect(attrs['olcTLSCACertificateFile']).to eq('/etc/ldap/tls/ca.crt')
      expect(attrs['olcTLSProtocolMin']).to eq('3.3')
    end

    it 'leaves the CA file out for custom TLS without a CA' do
      attrs = described_class.tls_attrs(cfg.merge('tls_mode' => 'custom'), '/etc/openldap')
      expect(attrs).not_to have_key('olcTLSCACertificateFile')
    end
  end

  describe '.tls_sans' do
    it 'adds the host names, localhost and extra SANs without duplicates' do
      sans = described_class.tls_sans(cfg.merge('tls_extra_sans' => ['IP:10.0.0.5', 'DNS:localhost']), 'ldap1')
      expect(sans).to eq(['DNS:ldap.example.com', 'DNS:ldap1', 'DNS:localhost', 'IP:127.0.0.1', 'IP:10.0.0.5'])
    end
  end

  describe '.ssha' do
    it 'produces a slapd {SSHA} hash that verifies against the password' do
      salt = 'saltsalt'
      hash = described_class.ssha('secret', salt)
      raw = Base64.decode64(hash.delete_prefix('{SSHA}'))
      expect(hash).to start_with('{SSHA}')
      expect(raw[0, 20]).to eq(Digest::SHA1.digest('secret' + salt))
      expect(raw[20..]).to eq(salt)
    end

    it 'hashes a non-ASCII password as UTF-8 bytes' do
      salt = 'saltsalt'.b
      raw = Base64.decode64(described_class.ssha('pässwörd', salt).delete_prefix('{SSHA}'))
      expect(raw[0, 20]).to eq(Digest::SHA1.digest('pässwörd'.b + salt))
    end
  end

  describe 'LDIF helpers' do
    it 'adds the RDN attribute when it is missing' do
      ldif = described_class.add_ldif('ou=People,dc=axonops,dc=local', %w(organizationalUnit), {})
      expect(ldif).to eq("dn: ou=People,dc=axonops,dc=local\nobjectClass: organizationalUnit\nou: People\n")
    end

    it 'base64-encodes values LDIF cannot carry verbatim' do
      expect(described_class.ldif_line('cn', 'José')).to eq("cn:: #{Base64.strict_encode64('José')}")
      expect(described_class.ldif_line('description', ':colon')).to start_with('description:: ')
      expect(described_class.ldif_line('cn', 'plain')).to eq('cn: plain')
    end

    it 'replaces several attributes in one modify operation' do
      ldif = described_class.replace_ldif('cn=config', 'olcLogLevel' => 'stats', 'olcTLSProtocolMin' => '3.3')
      expect(ldif).to eq("dn: cn=config\nchangetype: modify\nreplace: olcLogLevel\nolcLogLevel: stats\n-\n" \
                         "replace: olcTLSProtocolMin\nolcTLSProtocolMin: 3.3\n")
    end

    it 'parses folded and base64 ldapsearch output' do
      text = "dn: cn=config\nolcLogLevel: stats\ndescription:: #{Base64.strict_encode64('Jos' + 'é')}\n" \
             "olcAccess: {0}to * by self read by users re\n ad by * none\n"
      expect(described_class.parse_ldif(text)).to eq(
        'olclogLevel'.downcase => ['stats'],
        'description' => ['José'],
        'olcaccess' => ['{0}to * by self read by users read by * none']
      )
    end
  end

  describe '.changed_attrs' do
    it 'reports nothing when multi-valued attributes match in any order' do
      current = { 'member' => %w(b a) }
      expect(described_class.changed_attrs(current, { 'member' => %w(a b) })).to eq({})
    end

    it 'ignores slapd ordering prefixes on ordered attributes' do
      current = { 'olcaccess' => ['{0}to a', '{1}to b'] }
      expect(described_class.changed_attrs(current, { 'olcAccess' => ['to a', 'to b'] }, ordered: ['olcAccess'])).to eq({})
    end

    it 'reports an ordered attribute whose order changed' do
      current = { 'olcaccess' => ['{0}to b', '{1}to a'] }
      changes = described_class.changed_attrs(current, { 'olcAccess' => ['to a', 'to b'] }, ordered: ['olcAccess'])
      expect(changes).to eq('olcAccess' => ['to a', 'to b'])
    end

    it 'reports a missing attribute' do
      expect(described_class.changed_attrs({}, { 'mail' => 'a@b.c' })).to eq('mail' => ['a@b.c'])
    end
  end
end
