# Pure-Ruby unit spec for the AxonOpsOpenSearchSnapshot library (S3/GCS
# snapshot repositories).
#
#   rspec --options /dev/null spec/unit/libraries/opensearch_snapshot_spec.rb
#
require_relative '../../../libraries/opensearch_snapshot'

RSpec.describe AxonOpsOpenSearchSnapshot do
  let(:defaults) do
    {
      'enabled' => true, 'type' => 's3', 'client' => 'default', 'repository_name' => nil,
      'bucket' => 'backups', 'base_path' => '', 'register' => true,
      's3' => {
        'access_key' => '', 'secret_key' => '', 'session_token' => '', 'region' => '',
        'endpoint' => '', 'protocol' => '', 'path_style_access' => false, 'extra_settings' => {}
      },
      'gcs' => { 'credentials_json' => '', 'project_id' => '', 'endpoint' => '' },
      'policy' => {}
    }
  end

  def cfg(override = {})
    described_class.config(defaults, override)
  end

  describe '.config' do
    it 'defaults the repository name from the type' do
      expect(cfg['repository_name']).to eq('s3-snapshots')
      expect(cfg('type' => 'gcs')['repository_name']).to eq('gcs-snapshots')
    end

    it 'keeps an explicit repository name' do
      expect(cfg('repository_name' => 'nightly')['repository_name']).to eq('nightly')
    end

    it 'overrides nested keys without dropping their siblings' do
      merged = cfg('s3' => { 'region' => 'eu-west-1' })
      expect(merged['s3']['region']).to eq('eu-west-1')
      expect(merged['s3']).to include('access_key' => '', 'path_style_access' => false)
    end
  end

  describe '.validate!' do
    it 'accepts the defaults with a bucket' do
      expect(described_class.validate!(cfg)).to be true
    end

    it 'accepts complete GCS credentials as a hash or a string' do
      creds = { 'type' => 'service_account', 'client_id' => '1', 'client_email' => 'a@b',
                'private_key' => "-----BEGIN PRIVATE KEY-----\nMII\n-----END PRIVATE KEY-----\n", 'private_key_id' => 'k' }
      expect(described_class.validate!(cfg('type' => 'gcs', 'gcs' => { 'credentials_json' => creds }))).to be true
      expect(described_class.validate!(cfg('type' => 'gcs', 'gcs' => { 'credentials_json' => JSON.generate(creds) }))).to be true
    end

    {
      'an unknown type' => { 'type' => 'azure' },
      'an empty bucket' => { 'bucket' => '' },
      'a client name with dots' => { 'client' => 'a.b' },
      'an upper-case repository name' => { 'repository_name' => 'Nightly' },
      'an access key without a secret key' => { 's3' => { 'access_key' => 'AK' } },
      'a secret key without an access key' => { 's3' => { 'secret_key' => 'SK' } },
      'a session token without keys' => { 's3' => { 'session_token' => 'ST' } },
      'an unknown protocol' => { 's3' => { 'protocol' => 'ftp' } },
      'extra settings that are not a hash' => { 's3' => { 'extra_settings' => 'x' } },
      'an extra setting with a dotted key' => { 's3' => { 'extra_settings' => { 'a.b' => 1 } } },
      'a credential in the extra settings' => { 's3' => { 'extra_settings' => { 'secret_key' => 'x' } } },
      'a policy without a name' => { 'policy' => { 'creation' => {} } },
      'a policy name with a slash' => { 'policy' => { 'name' => 'a/b' } },
      'GCS credentials with a non-PEM private key' => {
        'type' => 'gcs',
        'gcs' => { 'credentials_json' => { 'client_id' => '1', 'client_email' => 'a@b', 'private_key_id' => 'k', 'private_key' => 'dummy' } },
      },
      'GCS credentials with a PKCS#1 private key' => {
        'type' => 'gcs',
        'gcs' => { 'credentials_json' => { 'client_id' => '1', 'client_email' => 'a@b', 'private_key_id' => 'k',
                                           'private_key' => "-----BEGIN RSA PRIVATE KEY-----\nMII\n-----END RSA PRIVATE KEY-----\n" } },
      },
      'GCS credentials that are not JSON' => { 'type' => 'gcs', 'gcs' => { 'credentials_json' => 'nope' } },
      'GCS credentials without a private key' => {
        'type' => 'gcs', 'gcs' => { 'credentials_json' => { 'client_id' => '1', 'client_email' => 'a@b', 'private_key_id' => 'k' } }
      },
    }.each do |label, override|
      it "rejects #{label}" do
        expect { described_class.validate!(cfg(override)) }.to raise_error(ArgumentError, /Invalid OpenSearch snapshot settings/)
      end
    end
  end

  describe '.client_settings' do
    it 'renders only path_style_access for a bare S3 config' do
      expect(described_class.client_settings(cfg)).to eq('s3.client.default.path_style_access' => false)
    end

    it 'renders S3-compatible store settings and extra settings' do
      settings = described_class.client_settings(cfg(
        'client' => 'backups',
        's3' => {
          'region' => 'fsn1', 'endpoint' => 'fsn1.your-objectstorage.com', 'protocol' => 'http',
          'path_style_access' => true, 'extra_settings' => { 'disable_chunked_encoding' => true }
        }
      ))
      expect(settings).to eq(
        's3.client.backups.region' => 'fsn1',
        's3.client.backups.endpoint' => 'fsn1.your-objectstorage.com',
        's3.client.backups.protocol' => 'http',
        's3.client.backups.path_style_access' => true,
        's3.client.backups.disable_chunked_encoding' => true
      )
    end

    it 'renders GCS settings and nothing for S3' do
      settings = described_class.client_settings(cfg(
        'type' => 'gcs', 'gcs' => { 'project_id' => 'p1', 'endpoint' => 'https://gcs.example.com' }
      ))
      expect(settings).to eq('gcs.client.default.project_id' => 'p1', 'gcs.client.default.endpoint' => 'https://gcs.example.com')
    end

    it 'never renders credentials' do
      settings = described_class.client_settings(cfg('s3' => { 'access_key' => 'AK', 'secret_key' => 'SK' }))
      expect(settings.keys.grep(/access_key|secret_key|session_token|credentials_file/)).to be_empty
      expect(settings.values).not_to include('AK', 'SK')
    end
  end

  describe '.keystore_entries' do
    it 'is empty without static credentials (instance identity)' do
      expect(described_class.keystore_entries(cfg)).to eq({})
      expect(described_class.keystore_entries(cfg('type' => 'gcs'))).to eq({})
    end

    it 'holds the S3 key pair and the optional session token' do
      entries = described_class.keystore_entries(cfg('s3' => { 'access_key' => 'AK', 'secret_key' => 'SK', 'session_token' => 'ST' }))
      expect(entries).to eq(
        's3.client.default.access_key' => 'AK',
        's3.client.default.secret_key' => 'SK',
        's3.client.default.session_token' => 'ST'
      )
    end

    it 'serialises a GCS credentials hash to JSON' do
      entries = described_class.keystore_entries(cfg('type' => 'gcs', 'gcs' => { 'credentials_json' => { 'type' => 'service_account' } }))
      expect(entries).to eq('gcs.client.default.credentials_file' => '{"type":"service_account"}')
    end
  end

  describe '.keystore_in_sync?' do
    let(:config) { cfg }
    let(:entries) { { 's3.client.default.access_key' => 'AK', 's3.client.default.secret_key' => 'SK' } }
    let(:marker) { described_class.marker(entries) }

    it 'is true when entries exist and the marker matches' do
      listed = ['keystore.seed'] + entries.keys
      expect(described_class.keystore_in_sync?(listed, entries, config, "#{marker}\n")).to be true
    end

    it 'is false when a value changed' do
      other = described_class.marker(entries.merge('s3.client.default.secret_key' => 'NEW'))
      expect(described_class.keystore_in_sync?(entries.keys, entries, config, other)).to be false
    end

    it 'is false when an entry is missing' do
      expect(described_class.keystore_in_sync?(['keystore.seed'], entries, config, marker)).to be false
    end

    it 'is false without a marker or with a corrupt one' do
      expect(described_class.keystore_in_sync?(entries.keys, entries, config, nil)).to be false
      expect(described_class.keystore_in_sync?(entries.keys, entries, config, 'not json')).to be false
    end

    it 'removes credentials an earlier run wrote for another client' do
      old = described_class.marker('gcs.client.old.credentials_file' => '{}')
      listed = entries.keys + ['gcs.client.old.credentials_file']
      expect(described_class.keystore_in_sync?(listed, entries, config, old)).to be false
      expect(described_class.unwanted_entries(listed, entries, config, ['gcs.client.old.credentials_file']))
        .to eq(['gcs.client.old.credentials_file'])
    end

    it 'removes unwanted credentials of the configured client' do
      listed = entries.keys + ['s3.client.default.session_token']
      expect(described_class.unwanted_entries(listed, entries, config)).to eq(['s3.client.default.session_token'])
    end

    it 'leaves credentials of other clients it did not write' do
      listed = entries.keys + ['s3.client.manual.access_key', 's3.client.manual.secret_key']
      expect(described_class.unwanted_entries(listed, entries, config)).to be_empty
      expect(described_class.keystore_in_sync?(listed, entries, config, marker)).to be true
    end

    it 'needs no marker with no credentials and nothing to remove' do
      expect(described_class.keystore_in_sync?(['keystore.seed', 'plugins.security.foo'], {}, config, nil)).to be true
    end

    it 'removes credentials dropped for the instance identity' do
      expect(described_class.keystore_in_sync?(entries.keys, {}, config, marker)).to be false
    end
  end

  describe '.repository_body' do
    it 'includes base_path only when set' do
      expect(described_class.repository_body(cfg)).to eq('type' => 's3', 'settings' => { 'bucket' => 'backups', 'client' => 'default' })
      expect(described_class.repository_body(cfg('base_path' => 'prod'))['settings']).to include('base_path' => 'prod')
    end
  end

  describe '.policy_body and .policy_in_sync?' do
    let(:policy) do
      cfg('policy' => {
            'name' => 'daily',
            'creation' => { 'schedule' => { 'cron' => { 'expression' => '0 2 * * *', 'timezone' => 'UTC' } } },
            'snapshot_config' => { 'indices' => '*' },
          })
    end
    let(:body) { described_class.policy_body(policy) }

    it 'drops the name and defaults the repository' do
      expect(body).not_to have_key('name')
      expect(body['snapshot_config']).to eq('repository' => 's3-snapshots', 'indices' => '*')
    end

    it 'treats a stored policy with extra server fields as in sync' do
      stored = body.merge('enabled' => true, 'schema_version' => 21,
                          'snapshot_config' => body['snapshot_config'].merge('date_format' => 'yyyy'))
      expect(described_class.policy_in_sync?(stored, body)).to be true
    end

    it 'detects a changed schedule' do
      stored = described_class.deep_merge(body, 'creation' => { 'schedule' => { 'cron' => { 'expression' => '0 3 * * *' } } })
      expect(described_class.policy_in_sync?(stored, body)).to be false
    end
  end

  describe AxonOpsOpenSearchSnapshot::Client do
    let(:client) { described_class.new('http://127.0.0.1:9200') }

    it 'retries 500/503 until the node answers' do
      allow(client).to receive(:safe_request).and_return([503, {}], [500, {}], [200, { 'ok' => true }])
      expect(client.request!(:get, '/x', delay: 0)).to eq([200, { 'ok' => true }])
    end

    it 'gives up after the retries with the last status' do
      allow(client).to receive(:safe_request).and_return([503, { 'error' => 'busy' }])
      expect { client.request!(:get, '/x', retries: 2, delay: 0) }.to raise_error(/returned 503/)
    end

    it 'does not retry a client error and hints at credentials on 401' do
      expect(client).to receive(:safe_request).once.and_return([401, {}])
      expect { client.request!(:get, '/x', delay: 0) }.to raise_error(/401 \(set search_db username/)
    end
  end

  describe '.plugin_version' do
    it 'reads the version from plugin-descriptor.properties' do
      expect(described_class.plugin_version("name=repository-s3\nversion=3.8.0\nopensearch.version=3.8.0\n")).to eq('3.8.0')
      expect(described_class.plugin_version(nil)).to be_nil
    end
  end
end
