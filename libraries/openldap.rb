#
# Cookbook:: axonops
# Library:: openldap
#
# Helpers for axonops::openldap, which installs a local OpenLDAP (slapd)
# directory seeded with users and groups that match axon-server's LDAP
# rolesMapping. Ported from the axonops.axonops.openldap Ansible role.
#
# Everything except AxonOpsOpenLDAP::Client is pure Ruby so it can be unit
# tested with plain rspec (spec/unit/libraries/openldap_spec.rb).
#
require 'base64'
require 'digest/sha1'
require 'securerandom'

module AxonOpsOpenLDAP
  # axon-server rolesMapping keys a group may map to.
  AXON_ROLES = %w(superUserRole adminRole readOnlyRole backupAdminRole).freeze
  TLS_MODES = %w(disabled generate custom).freeze

  # Per platform family layout. back_mdb is built into slapd on EL, so only
  # Debian loads it as a module.
  PLATFORMS = {
    'debian' => {
      'packages' => %w(slapd ldap-utils),
      'user' => 'openldap',
      'group' => 'openldap',
      'config_root' => '/etc/ldap',
      'schema_dir' => '/etc/ldap/schema',
      'module_path' => '/usr/lib/ldap',
      'modules' => %w(back_mdb memberof refint),
      'run_dir' => '/run/slapd',
    },
    'rhel' => {
      'packages' => %w(openldap-servers openldap-clients),
      'user' => 'ldap',
      'group' => 'ldap',
      'config_root' => '/etc/openldap',
      'schema_dir' => '/etc/openldap/schema',
      'module_path' => '/usr/lib64/openldap',
      'modules' => %w(memberof refint),
      'run_dir' => '/run/openldap',
    },
  }.freeze

  def self.platform(platform_family)
    PLATFORMS.fetch(platform_family.to_s) do
      raise ArgumentError, "axonops::openldap does not support platform_family '#{platform_family}'. " \
                           "Supported: #{PLATFORMS.keys.join(', ')}."
    end
  end

  # Returns a copy of the attribute hash with derived defaults filled in.
  # fqdn is the host name used when tls_common_name is not set.
  def self.resolve(attrs, fqdn:)
    cfg = deep_dup(attrs)
    cfg['groups'] ||= []
    cfg['users'] ||= []
    cfg['tls_extra_sans'] ||= []
    cfg['admin_dn'] = "cn=admin,#{cfg['base_dn']}" if blank?(cfg['admin_dn'])
    cfg['tls_common_name'] = fqdn if blank?(cfg['tls_common_name'])
    cfg['axon_server_host'] = cfg['tls_common_name'] if blank?(cfg['axon_server_host'])
    if cfg['axon_server_insecure_skip_verify'].nil?
      # axon-server does not trust a self-signed certificate.
      cfg['axon_server_insecure_skip_verify'] = cfg['tls_mode'].to_s == 'generate'
    end
    cfg
  end

  # Raises ArgumentError listing every problem found. Never includes a
  # password in the message.
  def self.validate!(cfg, platform_family)
    errors = []

    if blank?(cfg['admin_password']) || !cfg['admin_password'].is_a?(String)
      errors << 'admin password is not set. Set node.run_state[\'axonops_openldap_admin_password\'] ' \
                '(preferred, from chef-vault or an encrypted data bag) or axonops.openldap.admin_password.'
    end

    unless cfg['base_dn'].to_s.match?(/\Adc=[^,]+/)
      errors << "base_dn '#{cfg['base_dn']}' must start with a dc= component, for example dc=axonops,dc=local."
    end

    errors << "unsupported platform_family '#{platform_family}'." unless PLATFORMS.key?(platform_family.to_s)

    tls_mode = cfg['tls_mode'].to_s
    errors << "tls_mode must be one of #{TLS_MODES.join(', ')}, got '#{tls_mode}'." unless TLS_MODES.include?(tls_mode)
    if tls_mode == 'custom' && (blank?(cfg['tls_cert']) || blank?(cfg['tls_key']))
      errors << 'tls_mode custom needs tls_cert and tls_key.'
    end
    errors << 'listen_ldaps needs tls_mode generate or custom.' if cfg['listen_ldaps'] && tls_mode == 'disabled'
    errors << 'at least one of listen_ldap and listen_ldaps must be true.' unless cfg['listen_ldap'] || cfg['listen_ldaps']
    unless %w(3.3 3.4).include?(cfg['tls_protocol_min'].to_s)
      errors << 'tls_protocol_min must be 3.3 (TLS 1.2) or 3.4 (TLS 1.3).'
    end

    group_names = []
    cfg['groups'].each do |group|
      name = group['name'].to_s
      if name.empty?
        errors << 'every entry in groups needs a name.'
        next
      end
      group_names << name
      role = group['axon_role']
      unless role.nil? || AXON_ROLES.include?(role)
        errors << "group '#{name}' has axon_role '#{role}'; it must be one of #{AXON_ROLES.join(', ')}."
      end
    end

    uids = cfg['users'].map { |user| user['uid'].to_s }
    errors << 'every entry in users needs a non-empty uid.' if uids.any?(&:empty?)
    errors << 'user uids must be unique.' if uids.uniq.length != uids.length
    if cfg['users'].any? { |user| !user['password'].is_a?(String) || user['password'].empty? }
      errors << 'every entry in users needs a non-empty string password.'
    end
    unknown = cfg['users'].flat_map { |user| Array(user['groups']) }.uniq - group_names
    errors << "users reference groups not listed in groups: #{unknown.join(', ')}." unless unknown.empty?

    raise ArgumentError, "Invalid axonops.openldap settings: #{errors.join(' ')}" unless errors.empty?

    true
  end

  # slapd -h listener URLs. ldapi:/// is always on: the cookbook manages
  # cn=config over it as root.
  def self.listener_urls(cfg)
    urls = []
    urls << "ldap://:#{cfg['ldap_port']}/" if cfg['listen_ldap']
    urls << "ldaps://:#{cfg['ldaps_port']}/" if cfg['listen_ldaps']
    urls << 'ldapi:///'
  end

  def self.users_dn(cfg)
    "#{cfg['users_ou']},#{cfg['base_dn']}"
  end

  def self.groups_dn(cfg)
    "#{cfg['groups_ou']},#{cfg['base_dn']}"
  end

  def self.user_dn(cfg, uid)
    "uid=#{uid},#{users_dn(cfg)}"
  end

  def self.group_dn(cfg, name)
    "cn=#{name},#{groups_dn(cfg)}"
  end

  # The first dc value of the base DN, for the base entry's dc attribute.
  def self.base_dc(base_dn)
    base_dn.to_s[/\Adc=([^,]+)/, 1]
  end

  # { group name => [member DNs] }. groupOfNames needs at least one member,
  # so an empty group holds the admin DN.
  def self.group_members(cfg)
    cfg['groups'].each_with_object({}) do |group, out|
      members = cfg['users']
                .select { |user| Array(user['groups']).include?(group['name']) }
                .map { |user| user_dn(cfg, user['uid']) }
      out[group['name']] = members.empty? ? [cfg['admin_dn']] : members
    end
  end

  # axon-server rolesMapping for the groups that set axon_role.
  def self.roles_mapping(cfg)
    cfg['groups'].each_with_object({}) do |group, out|
      next if group['axon_role'].nil?

      out[group['axon_role']] = group_dn(cfg, group['name'])
    end
  end

  # Ready-made axon-server auth settings (camelCase keys, as axon-server reads
  # them). bindPassword is left out on purpose.
  def self.axon_server_ldap_setting(cfg)
    ldaps = cfg['listen_ldaps'] ? true : false
    {
      'host' => cfg['axon_server_host'],
      'port' => Integer(ldaps ? cfg['ldaps_port'] : cfg['ldap_port']),
      'useSSL' => ldaps,
      'startTLS' => !ldaps && cfg['tls_mode'].to_s != 'disabled',
      'insecureSkipVerify' => cfg['axon_server_insecure_skip_verify'] ? true : false,
      'base' => cfg['base_dn'],
      'bindDN' => cfg['admin_dn'],
      'userFilter' => '(uid=%s)',
      'rolesAttribute' => 'memberOf',
      'callAttempts' => 3,
      'rolesMapping' => { '_global_' => roles_mapping(cfg) },
    }
  end

  # cn=config TLS attributes. The CA file is set for generate (the
  # self-signed certificate is its own CA) or when a custom CA is given.
  def self.tls_attrs(cfg, config_root)
    attrs = {
      'olcTLSCertificateFile' => "#{config_root}/tls/server.crt",
      'olcTLSCertificateKeyFile' => "#{config_root}/tls/server.key",
      'olcTLSProtocolMin' => cfg['tls_protocol_min'].to_s,
    }
    if cfg['tls_mode'].to_s == 'generate' || !blank?(cfg['tls_ca'])
      attrs['olcTLSCACertificateFile'] = "#{config_root}/tls/ca.crt"
    end
    attrs
  end

  # subjectAltName entries for a generated certificate.
  def self.tls_sans(cfg, hostname)
    (["DNS:#{cfg['tls_common_name']}", "DNS:#{hostname}", 'DNS:localhost', 'IP:127.0.0.1'] +
      Array(cfg['tls_extra_sans'])).uniq
  end

  # Salted SHA-1 hash in the {SSHA} scheme slapd understands. Matches
  # `slappasswd -h {SSHA}` without shelling out with the password.
  def self.ssha(password, salt = SecureRandom.random_bytes(8))
    '{SSHA}' + Base64.strict_encode64(Digest::SHA1.digest(password + salt) + salt)
  end

  # ------------------------------------------------------------------------
  # LDIF helpers
  # ------------------------------------------------------------------------

  # One "attr: value" line, base64-encoded when LDIF (RFC 2849) requires it.
  def self.ldif_line(attr, value)
    value = value.to_s
    safe = value.match?(/\A[\x01-\x09\x0b\x0c\x0e-\x1f\x21-\x39\x3b\x3d-\x7f][\x01-\x09\x0b\x0c\x0e-\x7f]*\z/) &&
           !value.end_with?(' ')
    if value.empty? || safe
      "#{attr}: #{value}"
    else
      "#{attr}:: #{Base64.strict_encode64(value)}"
    end
  end

  # LDIF that adds an entry. The RDN attribute is added when missing, since
  # slapd rejects an entry without its naming attribute.
  def self.add_ldif(dn, object_classes, attrs)
    attrs = normalize_attrs(attrs)
    rdn_attr, rdn_value = dn.split(',', 2).first.split('=', 2)
    unless attrs.keys.any? { |key| key.casecmp?(rdn_attr) }
      attrs = { rdn_attr => [rdn_value] }.merge(attrs)
    end

    lines = [ldif_line('dn', dn)]
    object_classes.each { |oc| lines << ldif_line('objectClass', oc) }
    attrs.each { |attr, values| values.each { |value| lines << ldif_line(attr, value) } }
    lines.join("\n") + "\n"
  end

  # LDIF that replaces each attribute's values in one modify operation.
  def self.replace_ldif(dn, attrs)
    lines = [ldif_line('dn', dn), 'changetype: modify']
    normalize_attrs(attrs).each_with_index do |(attr, values), index|
      lines << '-' if index > 0
      lines << "replace: #{attr}"
      values.each { |value| lines << ldif_line(attr, value) }
    end
    lines.join("\n") + "\n"
  end

  # Parses ldapsearch -LLL output for a single entry into
  # { lowercased attr => [values] }. Handles folded lines and base64 values.
  def self.parse_ldif(text)
    unfolded = text.to_s.gsub(/\r?\n /, '')
    unfolded.each_line.with_object({}) do |line, out|
      line = line.chomp
      next if line.empty? || line.start_with?('#')

      match = line.match(/\A([^:]+)(::?)\s?(.*)\z/)
      next unless match

      attr = match[1].downcase
      next if attr == 'dn'

      value = match[2] == '::' ? Base64.decode64(match[3]).force_encoding('UTF-8') : match[3]
      (out[attr] ||= []) << value
    end
  end

  # Returns the subset of desired attributes whose current values differ.
  # Attributes listed in ordered keep their order and are compared without
  # the "{n}" index prefix slapd adds; others are compared as sets.
  def self.changed_attrs(current, desired, ordered: [])
    ordered = ordered.map(&:downcase)
    normalize_attrs(desired).each_with_object({}) do |(attr, values), out|
      have = Array(current[attr.downcase])
      same = if ordered.include?(attr.downcase)
               strip_ordering(have) == values
             else
               have.sort == values.sort
             end
      out[attr] = values unless same
    end
  end

  def self.strip_ordering(values)
    values.map { |value| value.sub(/\A\{-?\d+\}/, '') }
  end

  # { attr => [String values] }, dropping nil values.
  def self.normalize_attrs(attrs)
    attrs.each_with_object({}) do |(attr, values), out|
      list = Array(values).compact.map(&:to_s)
      out[attr.to_s] = list unless list.empty?
    end
  end

  def self.blank?(value)
    value.nil? || value.to_s.strip.empty?
  end

  def self.deep_dup(value)
    case value
    when Hash then value.each_with_object({}) { |(k, v), out| out[k.to_s] = deep_dup(v) }
    when Array then value.map { |v| deep_dup(v) }
    else value
    end
  end

  # ------------------------------------------------------------------------
  # Client: runs the OpenLDAP command line tools against ldapi:///.
  # Binds as root over SASL EXTERNAL when bind_dn is nil, otherwise with a
  # simple bind whose password is passed through a 0600 file (-y), never on
  # the command line.
  # ------------------------------------------------------------------------
  class Client
    LDAPI = 'ldapi:///'.freeze
    NO_SUCH_OBJECT = 32
    INVALID_CREDENTIALS = 49

    def initialize(bind_dn: nil, password: nil)
      @bind_dn = bind_dn
      @password = password
    end

    # Attributes of dn as { lowercased attr => [values] }, or nil when the
    # entry does not exist.
    def read(dn, attrs = [])
      result = with_auth do |auth|
        run(['ldapsearch', '-LLL', '-o', 'ldif-wrap=no', '-H', LDAPI, *auth, '-b', dn, '-s', 'base',
             '(objectClass=*)', *attrs])
      end
      return nil if result.exitstatus == NO_SUCH_OBJECT

      check!(result, "ldapsearch #{dn}")
      AxonOpsOpenLDAP.parse_ldif(result.stdout)
    end

    def ready?
      with_auth { |auth| run(['ldapsearch', '-LLL', '-H', LDAPI, *auth, '-b', 'cn=config', '-s', 'base', 'dn']) }
        .exitstatus.zero?
    end

    def add(ldif)
      apply('ldapadd', ldif)
    end

    def modify(ldif)
      apply('ldapmodify', ldif)
    end

    # :ok, :invalid_credentials or :error for a simple bind as dn.
    def self.bind_status(dn, password)
      client = new(bind_dn: dn, password: password)
      result = client.with_auth { |auth| client.run(['ldapwhoami', '-H', LDAPI, *auth]) }
      return :ok if result.exitstatus.zero?
      return :invalid_credentials if result.exitstatus == INVALID_CREDENTIALS

      :error
    end

    def with_auth
      return yield(['-Q', '-Y', 'EXTERNAL']) if @bind_dn.nil?

      require 'tempfile'
      Tempfile.create('axonops-ldap') do |file|
        file.chmod(0o600)
        file.write(@password)
        file.flush
        yield(['-x', '-D', @bind_dn, '-y', file.path])
      end
    end

    def run(argv, input: nil)
      require 'mixlib/shellout'
      cmd = Mixlib::ShellOut.new(*argv, input: input, timeout: 60)
      cmd.run_command
      cmd
    end

    private

    def apply(tool, ldif)
      result = with_auth { |auth| run([tool, '-H', LDAPI, *auth], input: ldif) }
      check!(result, tool)
    end

    def check!(result, what)
      return result if result.exitstatus.zero?

      raise "#{what} failed (exit #{result.exitstatus}): #{result.stderr.strip}"
    end
  end
end
