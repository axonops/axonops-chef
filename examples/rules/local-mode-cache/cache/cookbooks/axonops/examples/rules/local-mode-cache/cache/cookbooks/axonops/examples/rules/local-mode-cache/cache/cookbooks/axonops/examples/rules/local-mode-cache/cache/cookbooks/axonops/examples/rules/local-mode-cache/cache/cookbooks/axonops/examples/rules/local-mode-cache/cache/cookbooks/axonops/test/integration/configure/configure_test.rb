# InSpec test for recipe axonops::configure and custom resources

control 'axonops-api-configuration' do
  impact 1.0
  title 'AxonOps API Configuration'
  desc 'Verify API client is configured'

  describe file('/etc/axonops/api-config.json') do
    it { should exist }
    its('owner') { should eq 'axonops' }
    its('mode') { should cmp '0600' }

    describe json(content: File.read('/etc/axonops/api-config.json')) do
      its('api_key') { should_not be_nil }
      its('api_key') { should_not eq 'CHANGE_ME' }
      its('organization') { should_not be_nil }
    end
  end
end

control 'axonops-alert-endpoints' do
  impact 0.8
  title 'Alert Notification Endpoints'
  desc 'Verify notification endpoints are configured'
  only_if { node['axonops']['alerts']['endpoints'] && !node['axonops']['alerts']['endpoints'].empty? }

  # Test Slack endpoint if configured
  describe http("#{node['axonops']['api']['base_url']}/api/v1/notifications",
    headers: {
      'Authorization' => "Bearer #{node['axonops']['api']['key']}",
      'Accept' => 'application/json',
    }) do
    its('status') { should eq 200 }

    describe json(content: subject.body) do
      its('data') { should_not be_empty }
    end
  end
end

control 'axonops-alert-rules' do
  impact 0.9
  title 'Alert Rules Configuration'
  desc 'Verify alert rules are properly configured'
  only_if { node['axonops']['alerts']['rules'] && !node['axonops']['alerts']['rules'].empty? }

  # Test that alert rules are created
  describe http("#{node['axonops']['api']['base_url']}/api/v1/alerts/rules",
    headers: {
      'Authorization' => "Bearer #{node['axonops']['api']['key']}",
      'Accept' => 'application/json',
    }) do
    its('status') { should eq 200 }

    describe json(content: subject.body) do
      its(%w(data length)) { should be >= 1 }
    end
  end
end

control 'axonops-service-checks' do
  impact 0.8
  title 'Service Health Checks'
  desc 'Verify service checks are configured'
  only_if { node['axonops']['service_checks'] && !node['axonops']['service_checks'].empty? }

  describe http("#{node['axonops']['api']['base_url']}/api/v1/service-checks",
    headers: {
      'Authorization' => "Bearer #{node['axonops']['api']['key']}",
      'Accept' => 'application/json',
    }) do
    its('status') { should eq 200 }

    describe json(content: subject.body) do
      its('data') { should_not be_empty }

      # Verify Cassandra health check exists
      its(['data']) { should include(include('type' => 'cassandra_node_status')) }
    end
  end
end

control 'axonops-backup-configuration' do
  impact 0.9
  title 'Backup Configuration'
  desc 'Verify backup schedules are configured'
  only_if { node['axonops']['backups'] && !node['axonops']['backups'].empty? }

  describe http("#{node['axonops']['api']['base_url']}/api/v1/backups/schedules",
    headers: {
      'Authorization' => "Bearer #{node['axonops']['api']['key']}",
      'Accept' => 'application/json',
    }) do
    its('status') { should eq 200 }

    describe json(content: subject.body) do
      its('data') { should_not be_empty }

      # Verify backup schedule properties
      its(['data', 0]) { should include('schedule') }
      its(['data', 0]) { should include('retention') }
      its(['data', 0]) { should include('type') }
    end
  end
end

control 'axonops-cluster-configuration' do
  impact 0.7
  title 'Cluster Configuration'
  desc 'Verify cluster configurations via API'

  describe http("#{node['axonops']['api']['base_url']}/api/v1/clusters",
    headers: {
      'Authorization' => "Bearer #{node['axonops']['api']['key']}",
      'Accept' => 'application/json',
    }) do
    its('status') { should eq 200 }

    describe json(content: subject.body) do
      its('data') { should_not be_empty }

      # Verify cluster has been registered
      its(['data', 0, 'name']) { should_not be_nil }
      its(['data', 0, 'nodes']) { should_not be_empty }
    end
  end
end

control 'axonops-log-collection' do
  impact 0.6
  title 'Log Collection Configuration'
  desc 'Verify log collection is configured'
  only_if { node['axonops']['log_collection']['enabled'] }

  describe http("#{node['axonops']['api']['base_url']}/api/v1/logs/config",
    headers: {
      'Authorization' => "Bearer #{node['axonops']['api']['key']}",
      'Accept' => 'application/json',
    }) do
    its('status') { should eq 200 }

    describe json(content: subject.body) do
      its('enabled') { should eq true }
      its('log_paths') { should include('/var/log/cassandra/system.log') }
    end
  end
end

control 'axonops-metrics-collection' do
  impact 0.8
  title 'Metrics Collection Configuration'
  desc 'Verify metrics collection is properly configured'

  describe http("#{node['axonops']['api']['base_url']}/api/v1/metrics/config",
    headers: {
      'Authorization' => "Bearer #{node['axonops']['api']['key']}",
      'Accept' => 'application/json',
    }) do
    its('status') { should eq 200 }

    describe json(content: subject.body) do
      its('collection_interval') { should be <= 60 }
      its('retention_days') { should be >= 7 }
      its('metrics_enabled') { should include('cpu', 'memory', 'disk', 'network') }
    end
  end
end

control 'axonops-dashboard-access' do
  impact 0.7
  title 'Dashboard Access Configuration'
  desc 'Verify dashboard access and user configuration'

  # Test dashboard is accessible
  describe http("#{node['axonops']['dashboard']['url']}/") do
    its('status') { should eq 200 }
  end

  # Test API integration from dashboard
  describe http("#{node['axonops']['dashboard']['url']}/api/v1/health") do
    its('status') { should eq 200 }
  end
end

control 'axonops-configuration-validation' do
  impact 0.9
  title 'Configuration Validation'
  desc 'Verify all configurations are valid and applied'

  # Validate agent configuration matches API
  describe http("#{node['axonops']['api']['base_url']}/api/v1/agents",
    headers: {
      'Authorization' => "Bearer #{node['axonops']['api']['key']}",
      'Accept' => 'application/json',
    }) do
    its('status') { should eq 200 }

    describe json(content: subject.body) do
      its(%w(data length)) { should be >= 1 }

      # Agent should be reporting
      its(['data', 0, 'status']) { should eq 'active' }
      its(['data', 0, 'last_seen']) { should_not be_nil }
    end
  end

  # Validate all scheduled tasks
  describe command('curl -s -H "Authorization: Bearer $API_KEY" http://localhost:8080/api/v1/scheduled-tasks | jq -r .status') do
    let(:env) { { 'API_KEY' => node['axonops']['api']['key'] } }
    its('stdout') { should match /active/ }
  end
end

control 'axonops-configuration-persistence' do
  impact 0.6
  title 'Configuration Persistence'
  desc 'Verify configurations persist across service restarts'

  describe command('systemctl restart axon-server && sleep 5') do
    its('exit_status') { should eq 0 }
  end

  # Verify configurations still exist after restart
  describe http("#{node['axonops']['api']['base_url']}/api/v1/alerts/rules",
    headers: {
      'Authorization' => "Bearer #{node['axonops']['api']['key']}",
      'Accept' => 'application/json',
    }) do
    its('status') { should eq 200 }

    describe json(content: subject.body) do
      its(%w(data length)) { should be >= 1 }
    end
  end
end
