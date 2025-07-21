# Shared InSpec test helpers

# Helper method to check if a service is properly configured
def service_properly_configured?(service_name)
  svc = systemd_service(service_name)
  svc.installed? && svc.enabled? && svc.running?
end

# Helper to parse JSON config files
def parse_config_file(path)
  return unless File.exist?(path)
  JSON.parse(File.read(path))
rescue JSON::ParserError
  nil
end

# Helper to check AxonOps API connectivity
def axonops_api_available?
  config = parse_config_file('/etc/axonops/api-config.json')
  return false unless config && config['api_key']

  cmd = command("curl -s -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer #{config['api_key']}' http://localhost:8080/api/v1/health")
  cmd.exit_status == 0 && cmd.stdout.strip == '200'
end

# Helper to wait for service to be ready
def wait_for_service(_service_name, port, timeout = 30)
  start_time = Time.now

  loop do
    if port(port).listening?
      return true
    end

    if Time.now - start_time > timeout
      return false
    end

    sleep 1
  end
end

# Helper to check Java version
def java_version
  cmd = command('java -version 2>&1')
  return unless cmd.exit_status == 0

  version_match = cmd.stderr.match(/version "?(\d+)\.?/)
  version_match ? version_match[1].to_i : nil
end

# Helper to check if running in offline mode
def offline_mode?
  File.exist?('/etc/axonops/offline.flag') ||
    ENV['AXONOPS_OFFLINE_MODE'] == 'true'
end

# Shared examples for common service checks
RSpec.shared_examples 'axonops service' do |service_name, service_port|
  describe systemd_service(service_name) do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  describe port(service_port) do
    it { should be_listening }
  end

  describe user('axonops') do
    it { should exist }
  end

  describe group('axonops') do
    it { should exist }
  end
end

# Shared examples for configuration files
RSpec.shared_examples 'configuration file' do |file_path, owner = 'axonops', mode = '0600'|
  describe file(file_path) do
    it { should exist }
    its('owner') { should eq owner }
    its('group') { should eq owner }
    its('mode') { should cmp mode }
  end
end

# Helper to check Cassandra cluster health
def cassandra_cluster_healthy?
  cmd = command('nodetool status')
  return false unless cmd.exit_status == 0

  # Check if all nodes are Up and Normal (UN)
  cmd.stdout.lines.select { |line| line.match(/^UN\s+/) }.any?
end

# Helper to test API endpoints
def test_api_endpoint(endpoint, expected_status = 200, headers = {})
  config = parse_config_file('/etc/axonops/api-config.json')
  return false unless config

  auth_header = "-H 'Authorization: Bearer #{config['api_key']}'"
  additional_headers = headers.map { |k, v| "-H '#{k}: #{v}'" }.join(' ')

  cmd = command("curl -s -o /dev/null -w '%{http_code}' #{auth_header} #{additional_headers} http://localhost:8080#{endpoint}")
  cmd.exit_status == 0 && cmd.stdout.strip == expected_status.to_s
end
