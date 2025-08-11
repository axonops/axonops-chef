#!/usr/bin/env ruby
require 'spec_helper'

describe 'axonops::alert_rules' do
  let(:chef_run) do
    ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '20.04') do |node|
      # Set default API configuration
      node.automatic['axonops']['api']['org'] = 'test-org'
      node.automatic['axonops']['api']['cluster'] = 'test-cluster'
      node.automatic['axonops']['api']['username'] = 'test-user'
      node.automatic['axonops']['api']['password'] = 'test-pass'
      node.automatic['axonops']['api']['base_url'] = 'https://test.axonops.com'
      node.automatic['axonops']['api']['auth_token'] = 'test-token'
    end
  end

  context 'when no configurations are provided' do
    it 'converges successfully with no resources' do
      expect { chef_run.converge(described_recipe) }.not_to raise_error
    end
  end

  context 'when alert rules are configured' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '20.04') do |node|
        node.automatic['axonops']['api']['org'] = 'test-org'
        node.automatic['axonops']['api']['cluster'] = 'test-cluster'
        node.automatic['axonops']['alert_rules'] = [
          {
            'name' => 'High CPU Alert',
            'dashboard' => 'System',
            'chart' => 'CPU usage per host',
            'metric' => 'host_CPU_Percent_Merge',
            'operator' => '>',
            'warning_value' => 80,
            'critical_value' => 90,
            'duration' => '15m',
            'description' => 'CPU usage is too high',
            'routing' => ['slack-alerts'],
            'action' => 'create'
          },
          {
            'name' => 'Memory Alert',
            'dashboard' => 'System',
            'chart' => 'Used memory',
            'operator' => '>',
            'warning_value' => 85,
            'critical_value' => 95,
            'duration' => '10m',
            'action' => 'delete'
          }
        ]
      end.converge(described_recipe)
    end

    it 'creates alert rules with correct properties' do
      expect(chef_run).to create_axonops_alert_rule('High CPU Alert').with(
        dashboard: 'System',
        chart: 'CPU usage per host',
        metric: 'host_CPU_Percent_Merge',
        operator: '>',
        warning_value: 80,
        critical_value: 90,
        duration: '15m',
        description: 'CPU usage is too high',
        routing: ['slack-alerts']
      )
    end

    it 'deletes alert rules when action is delete' do
      expect(chef_run).to delete_axonops_alert_rule('Memory Alert')
    end

    it 'uses environment variables when provided' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('AXONOPS_ORG').and_return('env-org')
      allow(ENV).to receive(:[]).with('AXONOPS_CLUSTER').and_return('env-cluster')

      chef_run = ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '20.04') do |node|
        node.automatic['axonops']['alert_rules'] = [
          {
            'name' => 'Test Alert',
            'dashboard' => 'System',
            'chart' => 'Test Chart',
            'operator' => '>',
            'warning_value' => 50,
            'critical_value' => 75,
            'duration' => '5m'
          }
        ]
      end.converge(described_recipe)

      expect(chef_run).to create_axonops_alert_rule('Test Alert').with(
        org: 'env-org',
        cluster: 'env-cluster'
      )
    end
  end

  context 'when TCP checks are configured' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '20.04') do |node|
        node.automatic['axonops']['api']['org'] = 'test-org'
        node.automatic['axonops']['api']['cluster'] = 'test-cluster'
        node.automatic['axonops']['tcp_checks'] = [
          {
            'name' => 'Storage Port Check',
            'interval' => '1m',
            'timeout' => '30s',
            'tcp' => '{{.comp_listen_address}}:{{.comp_storage_port}}',
            'action' => 'create'
          },
          {
            'name' => 'CQL Port Check',
            'tcp' => '{{.comp_rpc_address}}:9042',
            'action' => 'delete'
          }
        ]
      end.converge(described_recipe)
    end

    it 'creates TCP checks with correct properties' do
      expect(chef_run).to create_axonops_tcp_check('Storage Port Check').with(
        interval: '1m',
        timeout: '30s',
        tcp: '{{.comp_listen_address}}:{{.comp_storage_port}}'
      )
    end

    it 'uses default values when not specified' do
      expect(chef_run).to delete_axonops_tcp_check('CQL Port Check').with(
        interval: '1m',
        timeout: '1m'
      )
    end
  end

  context 'when shell checks are configured' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '20.04') do |node|
        node.automatic['axonops']['api']['org'] = 'test-org'
        node.automatic['axonops']['api']['cluster'] = 'test-cluster'
        node.automatic['axonops']['shell_checks'] = [
          {
            'name' => 'Node Health Check',
            'interval' => '5m',
            'timeout' => '2m',
            'shell' => '/bin/bash',
            'script' => 'nodetool status',
            'action' => 'create'
          }
        ]
      end.converge(described_recipe)
    end

    it 'creates shell checks with correct properties' do
      expect(chef_run).to create_axonops_shell_check('Node Health Check').with(
        interval: '5m',
        timeout: '2m',
        shell: '/bin/bash',
        script: 'nodetool status'
      )
    end
  end

  context 'when HTTP checks are configured' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '20.04') do |node|
        node.automatic['axonops']['api']['org'] = 'test-org'
        node.automatic['axonops']['api']['cluster'] = 'test-cluster'
        node.automatic['axonops']['http_checks'] = [
          {
            'name' => 'API Health Check',
            'url' => 'https://api.example.com/health',
            'http_method' => 'GET',
            'expected_status' => 200,
            'interval' => '1m',
            'timeout' => '30s',
            'headers' => { 'Accept' => 'application/json' },
            'action' => 'create'
          },
          {
            'name' => 'Webhook Test',
            'url' => 'https://webhook.site/test',
            'http_method' => 'POST',
            'body' => '{"test": true}',
            'expected_status' => 201
          }
        ]
      end.converge(described_recipe)
    end

    it 'creates HTTP checks with correct properties' do
      expect(chef_run).to create_axonops_http_check('API Health Check').with(
        url: 'https://api.example.com/health',
        http_method: 'GET',
        expected_status: 200,
        interval: '1m',
        timeout: '30s',
        headers: { 'Accept' => 'application/json' }
      )
    end

    it 'handles POST requests with body' do
      expect(chef_run).to create_axonops_http_check('Webhook Test').with(
        http_method: 'POST',
        body: '{"test": true}',
        expected_status: 201
      )
    end

    it 'uses default values when not specified' do
      expect(chef_run).to create_axonops_http_check('Webhook Test').with(
        interval: '1m',
        timeout: '30s'
      )
    end
  end

  context 'when backups are configured' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '20.04') do |node|
        node.automatic['axonops']['api']['org'] = 'test-org'
        node.automatic['axonops']['api']['cluster'] = 'test-cluster'
        node.automatic['axonops']['backups'] = [
          {
            'name' => 'Daily S3 Backup',
            'tag' => 'daily-s3',
            'local_retention_duration' => '1d',
            'remote_retention_duration' => '7d',
            'remote' => true,
            'remote_type' => 's3',
            's3_region' => 'us-east-1',
            's3_access_key_id' => 'test-key',
            's3_secret_access_key' => 'test-secret',
            'remote_path' => 'my-bucket/backups',
            'schedule' => true,
            'schedule_expr' => '0 2 * * *',
            'keyspaces' => ['system_auth', 'my_keyspace'],
            'all_nodes' => true,
            'action' => 'create'
          },
          {
            'name' => 'SFTP Backup',
            'tag' => 'sftp-backup',
            'remote_type' => 'sftp',
            'sftp_host' => 'backup.example.com',
            'sftp_user' => 'backup',
            'sftp_pass' => 'password',
            'action' => 'delete'
          }
        ]
      end.converge(described_recipe)
    end

    it 'creates S3 backups with correct properties' do
      expect(chef_run).to create_axonops_backup('Daily S3 Backup').with(
        tag: 'daily-s3',
        local_retention_duration: '1d',
        remote_retention_duration: '7d',
        remote: true,
        remote_type: 's3',
        s3_region: 'us-east-1',
        s3_access_key_id: 'test-key',
        s3_secret_access_key: 'test-secret',
        remote_path: 'my-bucket/backups',
        schedule: true,
        schedule_expr: '0 2 * * *',
        keyspaces: ['system_auth', 'my_keyspace'],
        all_nodes: true
      )
    end

    it 'deletes backups when action is delete' do
      expect(chef_run).to delete_axonops_backup('SFTP Backup')
    end

    it 'handles SFTP-specific properties' do
      expect(chef_run).to delete_axonops_backup('SFTP Backup').with(
        remote_type: 'sftp',
        sftp_host: 'backup.example.com',
        sftp_user: 'backup',
        sftp_pass: 'password'
      )
    end
  end

  context 'when integrations are configured' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '20.04') do |node|
        node.automatic['axonops']['api']['org'] = 'test-org'
        node.automatic['axonops']['api']['cluster'] = 'test-cluster'
        node.automatic['axonops']['integrations'] = [
          {
            'name' => 'slack-alerts',
            'integration_type' => 'slack',
            'slack_webhook_url' => 'https://hooks.slack.com/services/XXX',
            'slack_channel' => '#alerts',
            'action' => 'create'
          },
          {
            'name' => 'pagerduty',
            'integration_type' => 'pagerduty',
            'pagerduty_integration_key' => 'test-key',
            'action' => 'create'
          },
          {
            'name' => 'email-alerts',
            'integration_type' => 'smtp',
            'smtp_server' => 'smtp.example.com',
            'smtp_port' => '587',
            'smtp_username' => 'alerts@example.com',
            'smtp_password' => 'password',
            'smtp_from' => 'alerts@example.com',
            'smtp_receivers' => 'team@example.com',
            'action' => 'delete'
          }
        ]
      end.converge(described_recipe)
    end

    it 'creates Slack integrations with correct properties' do
      expect(chef_run).to create_axonops_integration('slack-alerts').with(
        integration_type: 'slack',
        slack_webhook_url: 'https://hooks.slack.com/services/XXX',
        slack_channel: '#alerts'
      )
    end

    it 'creates PagerDuty integrations' do
      expect(chef_run).to create_axonops_integration('pagerduty').with(
        integration_type: 'pagerduty',
        pagerduty_integration_key: 'test-key'
      )
    end

    it 'deletes SMTP integrations when action is delete' do
      expect(chef_run).to delete_axonops_integration('email-alerts').with(
        integration_type: 'smtp'
      )
    end
  end

  context 'with mixed environment and node attributes' do
    let(:chef_run) do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('AXONOPS_ORG').and_return('env-org')

      ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '20.04') do |node|
        node.automatic['axonops']['api']['org'] = 'node-org'
        node.automatic['axonops']['api']['cluster'] = 'node-cluster'
        node.automatic['axonops']['alert_rules'] = [
          {
            'name' => 'Test Alert',
            'org' => 'rule-org',
            'dashboard' => 'System',
            'chart' => 'Test',
            'operator' => '>',
            'warning_value' => 50,
            'critical_value' => 75,
            'duration' => '5m'
          }
        ]
      end.converge(described_recipe)
    end

    it 'prioritizes environment variables over node attributes' do
      expect(chef_run).to create_axonops_alert_rule('Test Alert').with(
        org: 'env-org'  # ENV var takes precedence
      )
    end
  end

  context 'with all resource types together' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '20.04') do |node|
        node.automatic['axonops']['api']['org'] = 'test-org'
        node.automatic['axonops']['api']['cluster'] = 'test-cluster'

        node.automatic['axonops']['alert_rules'] = [
          { 'name' => 'CPU Alert', 'dashboard' => 'System', 'chart' => 'CPU',
            'operator' => '>', 'warning_value' => 80, 'critical_value' => 90,
            'duration' => '5m' }
        ]

        node.automatic['axonops']['tcp_checks'] = [
          { 'name' => 'Port Check', 'tcp' => 'localhost:9042' }
        ]

        node.automatic['axonops']['shell_checks'] = [
          { 'name' => 'Health Check', 'shell' => '/bin/bash', 'script' => 'exit 0' }
        ]

        node.automatic['axonops']['http_checks'] = [
          { 'name' => 'API Check', 'url' => 'http://localhost/health' }
        ]

        node.automatic['axonops']['backups'] = [
          { 'name' => 'Daily Backup', 'tag' => 'daily', 'keyspaces' => ['test'] }
        ]

        node.automatic['axonops']['integrations'] = [
          { 'name' => 'slack', 'integration_type' => 'slack',
            'slack_webhook_url' => 'https://slack.com/hook' }
        ]
      end.converge(described_recipe)
    end

    it 'creates all resource types' do
      expect(chef_run).to create_axonops_alert_rule('CPU Alert')
      expect(chef_run).to create_axonops_tcp_check('Port Check')
      expect(chef_run).to create_axonops_shell_check('Health Check')
      expect(chef_run).to create_axonops_http_check('API Check')
      expect(chef_run).to create_axonops_backup('Daily Backup')
      expect(chef_run).to create_axonops_integration('slack')
    end
  end

  context 'edge cases and error handling' do
    it 'handles routing as a Hash structure' do
      chef_run = ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '20.04') do |node|
        node.automatic['axonops']['api']['org'] = 'test-org'
        node.automatic['axonops']['api']['cluster'] = 'test-cluster'
        node.automatic['axonops']['alert_rules'] = [
          {
            'name' => 'Hash Routing Alert',
            'dashboard' => 'System',
            'chart' => 'CPU usage',
            'operator' => '>',
            'warning_value' => 80,
            'critical_value' => 90,
            'duration' => '15m',
            'routing' => {
              'error' => ['example_pagerduty_integration_developer'],
              'warning' => ['example_pagerduty_integration_developer', 'example_pagerduty_integration_ops']
            }
          }
        ]
      end.converge(described_recipe)

      # The recipe should handle the Hash routing properly
      expect(chef_run).to create_axonops_alert_rule('Hash Routing Alert')
    end

    it 'handles empty configurations gracefully' do
      chef_run = ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '20.04') do |node|
        node.automatic['axonops']['alert_rules'] = []
        node.automatic['axonops']['tcp_checks'] = []
        node.automatic['axonops']['shell_checks'] = []
        node.automatic['axonops']['http_checks'] = []
        node.automatic['axonops']['backups'] = []
        node.automatic['axonops']['integrations'] = []
      end.converge(described_recipe)

      expect { chef_run }.not_to raise_error
    end

    it 'handles nil configurations' do
      chef_run = ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '20.04') do |node|
        node.automatic['axonops'] = nil
      end

      expect { chef_run.converge(described_recipe) }.not_to raise_error
    end

    it 'handles missing axonops key' do
      chef_run = ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '20.04')

      expect { chef_run.converge(described_recipe) }.not_to raise_error
    end
  end
end
