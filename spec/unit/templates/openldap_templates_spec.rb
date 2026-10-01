# Render tests for the axonops::openldap templates. Plain rspec:
#
#   rspec --options /dev/null spec/unit/templates/openldap_templates_spec.rb
#
require 'erb'
require_relative '../../../libraries/openldap'

class OpenLDAPTemplateContext
  def render(name, variables)
    variables.each { |k, v| instance_variable_set("@#{k}", v) }
    path = File.expand_path("../../../templates/default/#{name}", __dir__)
    ERB.new(File.read(path), trim_mode: '-').result(binding)
  end
end

RSpec.describe 'OpenLDAP templates' do
  describe 'openldap-bootstrap.ldif.erb' do
    def render(family)
      plat = AxonOpsOpenLDAP.platform(family)
      OpenLDAPTemplateContext.new.render('openldap-bootstrap.ldif.erb',
                                         run_dir: plat['run_dir'], module_path: plat['module_path'],
                                         modules: plat['modules'], schema_dir: plat['schema_dir'],
                                         data_dir: '/var/lib/ldap', base_dn: 'dc=axonops,dc=local',
                                         admin_dn: 'cn=admin,dc=axonops,dc=local', db_max_size: 1_073_741_824)
    end

    it 'loads back_mdb as a module on Debian only' do
      expect(render('debian')).to include("olcModuleLoad: {0}back_mdb\nolcModuleLoad: {1}memberof\nolcModuleLoad: {2}refint\n")
      expect(render('rhel')).to include("olcModuleLoad: {0}memberof\nolcModuleLoad: {1}refint\n")
      expect(render('rhel')).not_to include('back_mdb')
    end

    it 'defines the mdb database with the suffix and root DN but no password' do
      ldif = render('rhel')
      expect(ldif).to include('olcSuffix: dc=axonops,dc=local')
      expect(ldif).to include('olcRootDN: cn=admin,dc=axonops,dc=local')
      expect(ldif).not_to include('olcRootPW')
    end

    it 'gives root over ldapi manage access to cn=config only' do
      expect(render('debian')).to include(
        'olcAccess: {0}to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * none'
      )
    end

    it 'uses the platform schema directory' do
      expect(render('debian')).to include('include: file:///etc/ldap/schema/inetorgperson.ldif')
      expect(render('rhel')).to include('include: file:///etc/openldap/schema/inetorgperson.ldif')
    end
  end

  describe 'openldap-slapd-override.conf.erb' do
    it 'resets ExecStart and passes the listener URLs' do
      out = OpenLDAPTemplateContext.new.render('openldap-slapd-override.conf.erb',
                                               user: 'ldap', urls: ['ldap://:389/', 'ldapi:///'])
      expect(out).to include("ExecStart=\nExecStart=/usr/sbin/slapd -u ldap -h \"ldap://:389/ ldapi:///\"\n")
    end
  end
end
