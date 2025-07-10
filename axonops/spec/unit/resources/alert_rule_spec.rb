require 'spec_helper'
require_relative '../../../libraries/axonops_api'

describe 'axonops_alert_rule' do
  let(:chef_run) do
    ChefSpec::ServerRunner.new(
      platform: 'ubuntu',
      version: '20.04',
      step_into: ['axonops_alert_rule']
    ) do |node|
      node.override['axonops']['api']['key'] = 'test-key'
      node.override['axonops']['api']['organization'] = 'test-org'
    end
  end

  let(:api_client) { instance_double(AxonOps::API) }

  before do
    allow(AxonOps::API).to receive(:new).and_return(api_client)
  end

  context 'create action' do
    let(:recipe_content) do
      <<-RECIPE
        axonops_alert_rule 'high_cpu' do
          metric 'cpu_usage'
          condition 'above'
          threshold 90
          duration '5m'
          severity 'critical'
          clusters ['prod']
          action :create
        end
      RECIPE
    end

    before do
      chef_run.converge_dsl('axonops', recipe_content)
    end

    it 'creates the alert rule via API' do
      expect(api_client).to receive(:create_alert_rule).with(
        hash_including(
          name: 'high_cpu',
          metric: 'cpu_usage',
          condition: 'above',
          threshold: 90,
          duration: '5m',
          severity: 'critical',
          clusters: ['prod']
        )
      ).and_return(success: true)

      chef_run
    end

    context 'when API call fails' do
      it 'raises an error' do
        allow(api_client).to receive(:create_alert_rule).and_return(
          success: false,
          body: { 'error' => 'API error' }
        )

        expect { chef_run }.to raise_error(SystemExit, /Failed to create alert rule/)
      end
    end
  end

  context 'update action' do
    let(:recipe_content) do
      <<-RECIPE
        axonops_alert_rule 'high_cpu' do
          metric 'cpu_usage'
          threshold 95
          action :update
        end
      RECIPE
    end

    before do
      chef_run.converge_dsl('axonops', recipe_content)
    end

    it 'updates the alert rule via API' do
      expect(api_client).to receive(:get_alert_rules).and_return(
        success: true,
        body: { 'data' => [{ 'id' => '123', 'name' => 'high_cpu' }] }
      )

      expect(api_client).to receive(:update_alert_rule).with(
        '123',
        hash_including(
          name: 'high_cpu',
          metric: 'cpu_usage',
          threshold: 95
        )
      ).and_return(success: true)

      chef_run
    end

    context 'when rule does not exist' do
      it 'creates a new rule' do
        expect(api_client).to receive(:get_alert_rules).and_return(
          success: true,
          body: { 'data' => [] }
        )

        expect(api_client).to receive(:create_alert_rule).and_return(success: true)

        chef_run
      end
    end
  end

  context 'delete action' do
    let(:recipe_content) do
      <<-RECIPE
        axonops_alert_rule 'high_cpu' do
          action :delete
        end
      RECIPE
    end

    before do
      chef_run.converge_dsl('axonops', recipe_content)
    end

    it 'deletes the alert rule via API' do
      expect(api_client).to receive(:get_alert_rules).and_return(
        success: true,
        body: { 'data' => [{ 'id' => '123', 'name' => 'high_cpu' }] }
      )

      expect(api_client).to receive(:delete_alert_rule).with('123').and_return(success: true)

      chef_run
    end

    context 'when rule does not exist' do
      it 'does nothing' do
        expect(api_client).to receive(:get_alert_rules).and_return(
          success: true,
          body: { 'data' => [] }
        )

        expect(api_client).not_to receive(:delete_alert_rule)

        chef_run
      end
    end
  end
end
