# Render tests for Reports v2 (ASB-4652), org_name/license_key, and the
# axon-server LDAP keys that axonops::openldap sets: axon-dash.yml
# reporting_url and axon-server.yml axon_reporting_url / org_name /
# license_key / auth. Plain rspec, no ChefSpec/Berkshelf:
#
#   rspec --options /dev/null spec/unit/templates/reporting_templates_spec.rb
#
require 'erb'
require 'yaml'
require 'json'
require_relative '../../../libraries/reporting'

# Hash that also answers node.run_state, which axon-server.yml.erb reads.
class FakeNode < Hash
  def run_state
    @run_state ||= {}
  end
end

class ReportingTemplateContext
  attr_reader :node

  def initialize(node = FakeNode.new)
    @node = node
  end

  def render(name, variables)
    variables.each { |k, v| instance_variable_set("@#{k}", v) }
    path = File.expand_path("../../../templates/default/#{name}", __dir__)
    ERB.new(File.read(path), trim_mode: '-').result(binding)
  end
end

RSpec.describe 'Reports v2 templates' do
  describe 'axon-dash.yml.erb' do
    def render_dash(reporting_url)
      ReportingTemplateContext.new.render('axon-dash.yml.erb',
                                          listen_host: '0.0.0.0', listen_port: 3000,
                                          server_endpoint: 'http://127.0.0.1:8080', context_path: '',
                                          reporting_url: reporting_url)
    end

    it 'writes axon-dash.reporting_url from the attribute' do
      yaml = YAML.safe_load(render_dash('http://127.0.0.1:8081'))
      expect(yaml['axon-dash']['reporting_url']).to eq('http://127.0.0.1:8081')
    end

    it 'omits reporting_url when the URL is empty or nil' do
      expect(YAML.safe_load(render_dash(''))['axon-dash']).not_to have_key('reporting_url')
      expect(YAML.safe_load(render_dash(nil))['axon-dash']).not_to have_key('reporting_url')
    end
  end

  describe 'axon-server.yml.erb' do
    let(:node) do
      n = FakeNode.new
      n['axonops'] = {
        'cassandra' => { 'ssl' => { 'enabled' => false } },
        'server' => {
          'cassandra' => { 'keyspace_replication' => "{ 'class' : 'SimpleStrategy', 'replication_factor' : 1 }" },
          'alert_log' => { 'enabled' => false, 'path' => '/var/log/a.log', 'max_size_mb' => 50, 'max_files' => 5 },
          'auth' => {
            'enabled' => false, 'type' => 'LDAP', 'base' => 'dc=axonops,dc=local',
            'bind_dn' => 'cn=admin,dc=axonops,dc=local', 'bind_password' => 'attr-pw',
            'host' => 'ldap.local', 'port' => 389, 'use_ssl' => false,
            'user_filter' => '(uid=%s)', 'roles_attribute' => 'memberOf',
            'roles_mapping' => { '_global_' => { 'adminRole' => 'cn=axonops_admin,ou=Groups,dc=axonops,dc=local' } },
            'start_tls' => nil, 'insecure_skip_verify' => nil, 'call_attempts' => nil
          },
        },
      }
      n
    end

    let(:retention) do
      { 'events' => '4w', 'security_events' => '8w',
        'metrics' => { 'high_resolution' => '30d', 'medium_resolution' => '24w',
                       'low_resolution' => '24M', 'super_low_resolution' => '3y' },
        'backups' => { 'local' => '10d', 'remote' => '30d' } }
    end

    def render_server(server_version, org_name: nil, license_key: nil, cassandra_dc: 'dc1')
      url = 'http://127.0.0.1:8081'
      YAML.safe_load(ReportingTemplateContext.new(node).render(
                       'axon-server.yml.erb',
                       listen_address: '0.0.0.0', listen_port: 8080, use_new_format: true,
                       search_db_hosts: ['http://localhost:9200/'], cassandra_hosts: ['127.0.0.1:9042'],
                       cassandra_dc: cassandra_dc, cassandra_username: 'cassandra', cassandra_password: 'cassandra',
                       tls_mode: 'disabled', retention: retention,
                       org_name: org_name, license_key: license_key,
                       reporting_url: (url if AxonOpsReporting.server_supports_reporting_url?(server_version))
                     ))
    end

    it 'writes axon_reporting_url for latest' do
      expect(render_server('latest')['axon_reporting_url']).to eq('http://127.0.0.1:8081')
    end

    it 'writes axon_reporting_url for 2.0.39' do
      expect(render_server('2.0.39')['axon_reporting_url']).to eq('http://127.0.0.1:8081')
    end

    it 'leaves axon_reporting_url out before 2.0.39' do
      expect(render_server('2.0.38')).not_to have_key('axon_reporting_url')
    end

    it 'never writes the legacy axon_dash_url' do
      expect(render_server('latest')).not_to have_key('axon_dash_url')
    end

    it 'writes org_name and a quoted license_key when set' do
      yaml = render_server('latest', org_name: 'mycompany', license_key: 'abc:123')
      expect(yaml['org_name']).to eq('mycompany')
      expect(yaml['license_key']).to eq('abc:123')
    end

    it 'writes a license key containing quotes and backslashes verbatim' do
      key = 'ab"c\\d'
      expect(render_server('latest', license_key: key)['license_key']).to eq(key)
    end

    it 'leaves org_name and license_key out when unset or empty' do
      expect(render_server('latest').keys).not_to include('org_name', 'license_key')
      expect(render_server('latest', org_name: '', license_key: '').keys).not_to include('org_name', 'license_key')
    end

    it 'writes cql_local_dc and cql_keyspace_replication when set' do
      yaml = render_server('latest')
      expect(yaml['cql_local_dc']).to eq('dc1')
      expect(yaml['cql_keyspace_replication']).to eq("{ 'class' : 'SimpleStrategy', 'replication_factor' : 1 }")
    end

    it 'leaves cql_local_dc and cql_keyspace_replication out when unset or empty' do
      node['axonops']['server']['cassandra']['keyspace_replication'] = nil
      expect(render_server('latest', cassandra_dc: nil).keys).not_to include('cql_local_dc', 'cql_keyspace_replication')
      node['axonops']['server']['cassandra']['keyspace_replication'] = ''
      expect(render_server('latest', cassandra_dc: '').keys).not_to include('cql_local_dc', 'cql_keyspace_replication')
    end

    context 'with LDAP auth enabled' do
      before { node['axonops']['server']['auth']['enabled'] = true }

      it 'omits the optional LDAP keys when unset' do
        settings = render_server('latest')['auth']['settings']
        expect(settings.keys).not_to include('startTLS', 'insecureSkipVerify', 'callAttempts')
        expect(settings['bindPassword']).to eq('attr-pw')
      end

      it 'writes startTLS, insecureSkipVerify and callAttempts when set' do
        node['axonops']['server']['auth'].merge!('start_tls' => true, 'insecure_skip_verify' => false,
                                                 'call_attempts' => 3)
        settings = render_server('latest')['auth']['settings']
        expect(settings.values_at('startTLS', 'insecureSkipVerify', 'callAttempts')).to eq([true, false, 3])
      end

      it 'writes bind passwords with YAML-significant characters verbatim' do
        ['p@ss #hash', 'a: b', '*anchor', '!tag', '"quoted" \\ back', '{flow}'].each do |password|
          node.run_state['axonops_server_ldap_bind_password'] = password
          expect(render_server('latest')['auth']['settings']['bindPassword']).to eq(password)
        end
      end

      it 'prefers the bind password passed through node.run_state' do
        node.run_state['axonops_server_ldap_bind_password'] = 'run-state-pw'
        expect(render_server('latest')['auth']['settings']['bindPassword']).to eq('run-state-pw')
      end
    end
  end
end
