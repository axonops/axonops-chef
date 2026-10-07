# InSpec controls for the OpenSearch snapshot repository (kitchen suites
# opensearch-snapshot-s3, opensearch-snapshot-gcs). Values match the
# kitchen.yml suite attributes; they are throwaway test data.

s3 = file('/usr/share/opensearch/plugins/repository-s3').directory?
plugin = s3 ? 'repository-s3' : 'repository-gcs'
cli_env = 'OPENSEARCH_PATH_CONF=/etc/opensearch OPENSEARCH_JAVA_OPTS=-Djava.io.tmpdir=/var/lib/opensearch/tmp'

control 'opensearch-snapshot-plugin' do
  title 'The repository plugin is installed and OpenSearch runs with it'
  describe command("#{cli_env} /usr/share/opensearch/bin/opensearch-plugin list") do
    its('stdout') { should match(/^#{plugin}$/) }
  end
  describe service('opensearch') do
    it { should be_enabled }
    it { should be_running }
  end
end

control 'opensearch-snapshot-keystore' do
  title 'Credentials are in the keystore only'
  describe file('/etc/opensearch/opensearch.keystore') do
    it { should exist }
    its('owner') { should eq 'root' }
    its('group') { should eq 'opensearch' }
    its('mode') { should cmp '0640' }
  end
  describe command("#{cli_env} /usr/share/opensearch/bin/opensearch-keystore list") do
    if s3
      its('stdout') { should match(/^s3\.client\.default\.access_key$/) }
      its('stdout') { should match(/^s3\.client\.default\.secret_key$/) }
      its('stdout') { should_not match(/^s3\.client\.default\.session_token$/) }
      its('stdout') { should_not match(/^gcs\./) }
    else
      its('stdout') { should match(/^gcs\.client\.default\.credentials_file$/) }
      its('stdout') { should_not match(/^s3\./) }
    end
  end
  describe file('/etc/opensearch/.snapshot-gcs-credentials.json') do
    it { should_not exist }
  end
end

control 'opensearch-snapshot-settings' do
  title 'opensearch.yml holds the client settings but no secrets'
  describe file('/etc/opensearch/opensearch.yml') do
    if s3
      its('content') { should include 's3.client.default.region: "eu-west-1"' }
      its('content') { should include 's3.client.default.endpoint: "minio.kitchen.test:9000"' }
      its('content') { should include 's3.client.default.protocol: "http"' }
      its('content') { should include 's3.client.default.path_style_access: true' }
      its('content') { should include 's3.client.default.disable_chunked_encoding: true' }
    else
      its('content') { should include 'gcs.client.default.project_id: "kitchen-project"' }
      its('content') { should include 'gcs.client.default.endpoint: "https://gcs.kitchen.test"' }
    end
    its('content') { should_not include 'KITCHENDUMMYACCESSKEY' }
    its('content') { should_not include 'kitchen-dummy-secret-key-value' }
    its('content') { should_not include 'PRIVATE KEY' }
    its('content') { should_not match(/access_key|secret_key|credentials_file/) }
  end
end
