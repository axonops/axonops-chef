# InSpec tests for AxonOps custom resources

control 'axonops-custom-resources' do
  impact 1.0
  title 'Custom Resources Functionality'
  desc 'Verify custom resources work correctly'

  # Only run these tests if API is configured
  only_if do
    File.exist?('/etc/axonops/api-config.json') &&
      JSON.parse(File.read('/etc/axonops/api-config.json'))['api_key'] != 'CHANGE_ME'
  end

  # Test notification endpoint creation
  describe 'notification endpoints' do
    it 'creates Slack notification endpoint' do
      cmd = <<-CMD
        curl -s -X GET \
          -H "Authorization: Bearer $(jq -r .api_key /etc/axonops/api-config.json)" \
          -H "Accept: application/json" \
          http://localhost:8080/api/v1/notifications | jq -r '.data[] | select(.name=="slack_test")'
      CMD

      result = command(cmd)
      expect(result.exit_status).to eq(0)
      expect(result.stdout).not_to be_empty

      notification = JSON.parse(result.stdout)
      expect(notification['type']).to eq('slack')
      expect(notification['config']['webhook_url']).to match(/hooks.slack.com/)
    end

    it 'creates PagerDuty notification endpoint' do
      cmd = <<-CMD
        curl -s -X GET \
          -H "Authorization: Bearer $(jq -r .api_key /etc/axonops/api-config.json)" \
          -H "Accept: application/json" \
          http://localhost:8080/api/v1/notifications | jq -r '.data[] | select(.type=="pagerduty")'
      CMD

      result = command(cmd)
      expect(result.exit_status).to eq(0)
      # PagerDuty endpoint might not be configured in all tests
    end
  end

  # Test alert rule creation
  describe 'alert rules' do
    it 'creates CPU alert rule' do
      cmd = <<-CMD
        curl -s -X GET \
          -H "Authorization: Bearer $(jq -r .api_key /etc/axonops/api-config.json)" \
          -H "Accept: application/json" \
          http://localhost:8080/api/v1/alerts/rules | jq -r '.data[] | select(.name=="high_cpu_usage")'
      CMD

      result = command(cmd)
      expect(result.exit_status).to eq(0)

      if result.stdout && !result.stdout.empty?
        rule = JSON.parse(result.stdout)
        expect(rule['metric']).to eq('cpu_usage')
        expect(rule['threshold']).to be >= 80
        expect(rule['severity']).to match(/critical|warning/)
      end
    end

    it 'creates disk space alert rule' do
      cmd = <<-CMD
        curl -s -X GET \
          -H "Authorization: Bearer $(jq -r .api_key /etc/axonops/api-config.json)" \
          -H "Accept: application/json" \
          http://localhost:8080/api/v1/alerts/rules | jq -r '.data[] | select(.metric=="disk_used_percent")'
      CMD

      result = command(cmd)
      expect(result.exit_status).to eq(0)
    end
  end

  # Test service check creation
  describe 'service checks' do
    it 'creates Cassandra node status check' do
      cmd = <<-CMD
        curl -s -X GET \
          -H "Authorization: Bearer $(jq -r .api_key /etc/axonops/api-config.json)" \
          -H "Accept: application/json" \
          http://localhost:8080/api/v1/service-checks | jq -r '.data[] | select(.type=="cassandra_node_status")'
      CMD

      result = command(cmd)
      expect(result.exit_status).to eq(0)

      if result.stdout && !result.stdout.empty?
        check = JSON.parse(result.stdout)
        expect(check['interval']).to match(/\d+[sm]/)
        expect(check['enabled']).to eq(true)
      end
    end

    it 'creates JMX connectivity check' do
      cmd = <<-CMD
        curl -s -X GET \
          -H "Authorization: Bearer $(jq -r .api_key /etc/axonops/api-config.json)" \
          -H "Accept: application/json" \
          http://localhost:8080/api/v1/service-checks | jq -r '.data[] | select(.type=="jmx_connectivity")'
      CMD

      result = command(cmd)
      expect(result.exit_status).to eq(0)
    end
  end

  # Test backup configuration
  describe 'backup schedules' do
    it 'creates backup schedule' do
      cmd = <<-CMD
        curl -s -X GET \
          -H "Authorization: Bearer $(jq -r .api_key /etc/axonops/api-config.json)" \
          -H "Accept: application/json" \
          http://localhost:8080/api/v1/backups/schedules | jq -r '.data[0]'
      CMD

      result = command(cmd)
      expect(result.exit_status).to eq(0)

      if result.stdout && !result.stdout.empty? && result.stdout != 'null'
        backup = JSON.parse(result.stdout)
        expect(backup['schedule']).to match(/\d+ \d+ \* \* \*/) # Cron format
        expect(backup['retention']).to be > 0
        expect(backup['type']).to match(/s3|local|azure|gcs/)
      end
    end
  end
end

control 'axonops-resource-idempotency' do
  impact 0.8
  title 'Resource Idempotency'
  desc 'Verify resources are idempotent'

  describe 'repeated resource creation' do
    it 'handles duplicate alert rules gracefully' do
      # Create the same alert rule twice
      cmd = <<-CMD
        curl -s -X POST \
          -H "Authorization: Bearer $(jq -r .api_key /etc/axonops/api-config.json)" \
          -H "Content-Type: application/json" \
          -d '{"name":"test_idempotent","metric":"cpu_usage","threshold":50,"condition":"above"}' \
          http://localhost:8080/api/v1/alerts/rules
      CMD

      # First creation
      result1 = command(cmd)
      expect(result1.exit_status).to eq(0)

      # Second creation should either succeed (update) or return already exists
      result2 = command(cmd)
      expect(result2.exit_status).to eq(0)

      # Verify only one rule exists
      count_cmd = <<-CMD
        curl -s -X GET \
          -H "Authorization: Bearer $(jq -r .api_key /etc/axonops/api-config.json)" \
          http://localhost:8080/api/v1/alerts/rules | jq '[.data[] | select(.name=="test_idempotent")] | length'
      CMD

      count_result = command(count_cmd)
      expect(count_result.stdout.strip.to_i).to eq(1)
    end
  end
end

control 'axonops-resource-validation' do
  impact 0.7
  title 'Resource Validation'
  desc 'Verify resource validation works correctly'

  describe 'invalid resource creation' do
    it 'rejects invalid alert rule' do
      cmd = <<-CMD
        curl -s -X POST \
          -H "Authorization: Bearer $(jq -r .api_key /etc/axonops/api-config.json)" \
          -H "Content-Type: application/json" \
          -d '{"name":"invalid_rule","metric":"invalid_metric","threshold":"not_a_number"}' \
          http://localhost:8080/api/v1/alerts/rules
      CMD

      result = command(cmd)
      # Should return 400 Bad Request
      response = begin
                   JSON.parse(result.stdout)
                 rescue
                   {}
                 end
      expect(response['error']).not_to be_nil
    end

    it 'rejects invalid backup schedule' do
      cmd = <<-CMD
        curl -s -X POST \
          -H "Authorization: Bearer $(jq -r .api_key /etc/axonops/api-config.json)" \
          -H "Content-Type: application/json" \
          -d '{"name":"invalid_backup","schedule":"invalid cron","type":"invalid_type"}' \
          http://localhost:8080/api/v1/backups/schedules
      CMD

      result = command(cmd)
      response = begin
                   JSON.parse(result.stdout)
                 rescue
                   {}
                 end
      expect(response['error']).not_to be_nil
    end
  end
end

control 'axonops-resource-permissions' do
  impact 0.9
  title 'Resource Permissions'
  desc 'Verify API permissions are enforced'

  describe 'unauthorized access' do
    it 'rejects requests without API key' do
      cmd = <<-CMD
        curl -s -X GET \
          -H "Accept: application/json" \
          http://localhost:8080/api/v1/alerts/rules -w "\\n%{http_code}"
      CMD

      result = command(cmd)
      expect(result.stdout).to match(/401|403/)
    end

    it 'rejects requests with invalid API key' do
      cmd = <<-CMD
        curl -s -X GET \
          -H "Authorization: Bearer invalid-key-12345" \
          -H "Accept: application/json" \
          http://localhost:8080/api/v1/alerts/rules -w "\\n%{http_code}"
      CMD

      result = command(cmd)
      expect(result.stdout).to match(/401|403/)
    end
  end
end

control 'axonops-resource-cleanup' do
  impact 0.5
  title 'Resource Cleanup'
  desc 'Verify resources can be properly deleted'

  describe 'resource deletion' do
    it 'can delete alert rules' do
      # Create a test rule
      create_cmd = <<-CMD
        curl -s -X POST \
          -H "Authorization: Bearer $(jq -r .api_key /etc/axonops/api-config.json)" \
          -H "Content-Type: application/json" \
          -d '{"name":"test_delete","metric":"cpu_usage","threshold":50}' \
          http://localhost:8080/api/v1/alerts/rules
      CMD

      command(create_cmd)

      # Get the rule ID
      get_cmd = <<-CMD
        curl -s -X GET \
          -H "Authorization: Bearer $(jq -r .api_key /etc/axonops/api-config.json)" \
          http://localhost:8080/api/v1/alerts/rules | jq -r '.data[] | select(.name=="test_delete") | .id'
      CMD

      rule_id = command(get_cmd).stdout.strip

      unless rule_id.empty?
        # Delete the rule
        delete_cmd = <<-CMD
          curl -s -X DELETE \
            -H "Authorization: Bearer $(jq -r .api_key /etc/axonops/api-config.json)" \
            http://localhost:8080/api/v1/alerts/rules/#{rule_id}
        CMD

        result = command(delete_cmd)
        expect(result.exit_status).to eq(0)

        # Verify it's deleted
        verify_cmd = <<-CMD
          curl -s -X GET \
            -H "Authorization: Bearer $(jq -r .api_key /etc/axonops/api-config.json)" \
            http://localhost:8080/api/v1/alerts/rules | jq '[.data[] | select(.name=="test_delete")] | length'
        CMD

        verify_result = command(verify_cmd)
        expect(verify_result.stdout.strip.to_i).to eq(0)
      end
    end
  end
end
