require 'spec_helper'

describe 'axonops::configure' do
  include_context 'chef_run'

  context 'without API key in SaaS mode' do
    let(:node_attributes) do
      {
        'axonops' => {
          'deployment_mode' => 'saas',
          'api' => {
            'key' => nil,
          },
        },
      }
    end

    it 'fails when API key is missing' do
      expect { chef_run }.to raise_error(SystemExit, /API key required/)
    end
  end

  context 'with alert endpoints configured' do
    let(:node_attributes) do
      {
        'axonops' => {
          'api' => {
            'key' => 'test-key',
            'organization' => 'test-org',
          },
          'alerts' => {
            'endpoints' => {
              'slack_critical' => {
                'type' => 'slack',
                'webhook_url' => 'https://hooks.slack.com/test',
                'channel' => '#alerts',
              },
              'pagerduty_oncall' => {
                'type' => 'pagerduty',
                'api_key' => 'pd-key',
                'service_key' => 'service-123',
              },
            },
          },
        },
      }
    end

    it 'creates notification endpoints' do
      expect(chef_run).to create_axonops_notification('slack_critical').with(
        type: 'slack',
        config: {
          'type' => 'slack',
          'webhook_url' => 'https://hooks.slack.com/test',
          'channel' => '#alerts',
        }
      )

      expect(chef_run).to create_axonops_notification('pagerduty_oncall').with(
        type: 'pagerduty',
        config: {
          'type' => 'pagerduty',
          'api_key' => 'pd-key',
          'service_key' => 'service-123',
        }
      )
    end
  end

  context 'with alert rules configured' do
    let(:node_attributes) do
      {
        'axonops' => {
          'api' => {
            'key' => 'test-key',
          },
          'alerts' => {
            'rules' => {
              'high_cpu' => {
                'metric' => 'cpu_usage',
                'threshold' => 90,
                'duration' => '5m',
                'severity' => 'critical',
              },
              'disk_space' => {
                'metric' => 'disk_used_percent',
                'threshold' => 85,
                'condition' => 'above',
                'clusters' => ['prod-cluster'],
              },
            },
          },
        },
      }
    end

    it 'creates alert rules' do
      expect(chef_run).to create_axonops_alert_rule('high_cpu').with(
        metric: 'cpu_usage',
        threshold: 90,
        duration: '5m',
        severity: 'critical'
      )

      expect(chef_run).to create_axonops_alert_rule('disk_space').with(
        metric: 'disk_used_percent',
        threshold: 85,
        condition: 'above',
        clusters: ['prod-cluster']
      )
    end
  end

  context 'with service checks configured' do
    let(:node_attributes) do
      {
        'axonops' => {
          'api' => {
            'key' => 'test-key',
          },
          'service_checks' => {
            'cassandra_health' => {
              'type' => 'cassandra_node_status',
              'interval' => '60s',
              'timeout' => '30s',
            },
          },
        },
      }
    end

    it 'creates service checks' do
      expect(chef_run).to create_axonops_service_check('cassandra_health').with(
        check_type: 'cassandra_node_status',
        interval: '60s',
        timeout: '30s'
      )
    end
  end

  context 'with backups configured' do
    let(:node_attributes) do
      {
        'axonops' => {
          'api' => {
            'key' => 'test-key',
          },
          'backups' => {
            'daily_backup' => {
              'type' => 's3',
              'schedule' => '0 2 * * *',
              'retention' => 7,
              'destination' => 's3://my-bucket/cassandra-backups',
            },
          },
        },
      }
    end

    it 'creates backup configurations' do
      expect(chef_run).to create_axonops_backup('daily_backup').with(
        backup_type: 's3',
        schedule: '0 2 * * *',
        retention: 7,
        destination: 's3://my-bucket/cassandra-backups'
      )
    end
  end

  context 'with self-hosted deployment' do
    let(:node_attributes) do
      {
        'axonops' => {
          'deployment_mode' => 'self-hosted',
          'server' => {
            'listen_address' => '192.168.1.10',
            'listen_port' => 8080,
          },
          'alerts' => {
            'rules' => {
              'test_rule' => {
                'metric' => 'test',
                'threshold' => 50,
              },
            },
          },
        },
      }
    end

    it 'configures API client for self-hosted server' do
      # The API client should use the self-hosted server URL
      expect(chef_run).to create_axonops_alert_rule('test_rule')
    end
  end
end
