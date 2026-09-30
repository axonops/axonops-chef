# InSpec controls for axonops::openldap (kitchen suites openldap, openldap-tls).
# Values match the kitchen.yml suite attributes; they are throwaway test data.

base_dn = 'dc=axonops,dc=local'
people = "ou=People,#{base_dn}"
groups = "ou=Groups,#{base_dn}"
admin_dn = "cn=admin,#{base_dn}"
config_root = os.debian? ? '/etc/ldap' : '/etc/openldap'
tls = file("#{config_root}/tls/server.crt").exist?

control 'openldap-service' do
  title 'slapd is installed, enabled and listening'
  describe service('slapd') do
    it { should be_enabled }
    it { should be_running }
  end
  describe port(389) do
    it { should be_listening }
  end
  describe file("#{config_root}/slapd.d/cn=config/olcDatabase={1}mdb.ldif") do
    it { should exist }
  end
  describe file("#{config_root}/axonops-bootstrap.ldif") do
    it { should_not exist }
  end
end

control 'openldap-admin-bind' do
  title 'The admin DN binds with the configured password only'
  describe command("ldapwhoami -x -H ldap://127.0.0.1 -D '#{admin_dn}' -w kitchen-admin-pw") do
    its('exit_status') { should eq 0 }
  end
  describe command("ldapwhoami -x -H ldap://127.0.0.1 -D '#{admin_dn}' -w wrong-password") do
    its('exit_status') { should eq 49 }
  end
end

control 'openldap-users-and-groups' do
  title 'Seeded users bind and carry memberOf for their groups'
  describe command("ldapsearch -LLL -x -H ldap://127.0.0.1 -D 'uid=alice,#{people}' -w kitchen-alice-pw " \
                   "-b 'uid=alice,#{people}' -s base memberOf") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/^memberOf: cn=axonops_admin,#{groups}$/) }
  end
  describe command("ldapsearch -LLL -x -H ldap://127.0.0.1 -D '#{admin_dn}' -w kitchen-admin-pw " \
                   "-b 'cn=axonops_super,#{groups}' -s base member") do
    its('stdout') { should match(/^member: #{admin_dn}$/) }
  end
end

control 'openldap-anonymous-access' do
  title 'Anonymous clients read the root DSE but not the directory'
  describe command("ldapsearch -LLL -x -H ldap://127.0.0.1 -b '#{people}' '(uid=*)' uid") do
    its('stdout') { should_not match(/^uid:/) }
  end
  describe command("ldapsearch -LLL -x -H ldap://127.0.0.1 -b '' -s base namingContexts") do
    its('stdout') { should match(/namingContexts: #{base_dn}/) }
  end
end

control 'openldap-tls' do
  title 'Generated certificate is served over LDAPS and StartTLS'
  only_if('TLS suite') { tls }
  describe port(636) do
    it { should be_listening }
  end
  describe file("#{config_root}/tls/server.key") do
    its('mode') { should cmp '0640' }
  end
  describe command("LDAPTLS_REQCERT=never ldapwhoami -x -H ldaps://127.0.0.1 -D 'uid=alice,#{people}' -w kitchen-alice-pw") do
    its('exit_status') { should eq 0 }
  end
  describe command("LDAPTLS_REQCERT=never ldapwhoami -ZZ -x -H ldap://127.0.0.1 -D 'uid=alice,#{people}' -w kitchen-alice-pw") do
    its('exit_status') { should eq 0 }
  end
end
