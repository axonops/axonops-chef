require 'spec_helper_simple'

RSpec.describe AxonOps::API do
  let(:api_client) { described_class.new('https://api.example.com', 'test-key', 'test-org') }

  describe '#initialize' do
    it 'sets the base URL, API key, and organization' do
      expect(api_client.instance_variable_get(:@base_url)).to eq('https://api.example.com')
      expect(api_client.instance_variable_get(:@api_key)).to eq('test-key')
      expect(api_client.instance_variable_get(:@org_name)).to eq('test-org')
    end

    it 'removes trailing slash from base URL' do
      client = described_class.new('https://api.example.com/', 'key', 'org')
      expect(client.instance_variable_get(:@base_url)).to eq('https://api.example.com')
    end
  end

  describe '#request' do
    let(:mock_response) { double('response', code: '200', body: '{"success": true}') }
    let(:mock_http) { double('http') }

    before do
      allow(Net::HTTP).to receive(:new).and_return(mock_http)
      allow(mock_http).to receive(:use_ssl=)
      allow(mock_http).to receive(:read_timeout=)
      allow(mock_http).to receive(:open_timeout=)
      allow(mock_http).to receive(:request).and_return(mock_response)
    end

    it 'makes a GET request' do
      result = api_client.request('GET', '/test')
      expect(result[:code]).to eq(200)
      expect(result[:success]).to be true
    end

    it 'includes authentication headers' do
      request = double('request')
      allow(Net::HTTP::Get).to receive(:new).and_return(request)
      expect(request).to receive(:[]=).with('Content-Type', 'application/json')
      expect(request).to receive(:[]=).with('Accept', 'application/json')
      expect(request).to receive(:[]=).with('X-API-Key', 'test-key')
      expect(request).to receive(:[]=).with('X-Organization', 'test-org')

      api_client.request('GET', '/test')
    end

    it 'handles errors gracefully' do
      allow(mock_http).to receive(:request).and_raise(StandardError.new('Connection failed'))

      result = api_client.request('GET', '/test')
      expect(result[:success]).to be false
      expect(result[:code]).to eq(0)
      expect(result[:body]['error']).to eq('Connection failed')
    end
  end

  describe 'API methods' do
    let(:mock_response) { { success: true, body: { 'id' => '123' } } }

    before do
      allow(api_client).to receive(:request).and_return(mock_response)
    end

    describe '#create_alert_rule' do
      it 'sends a POST request to create an alert rule' do
        rule = { name: 'test', metric: 'cpu', threshold: 90 }
        expect(api_client).to receive(:request).with('POST', '/api/v1/alerts/rules', rule)
        api_client.create_alert_rule(rule)
      end
    end

    describe '#update_alert_rule' do
      it 'sends a PUT request to update an alert rule' do
        rule = { name: 'test', threshold: 95 }
        expect(api_client).to receive(:request).with('PUT', '/api/v1/alerts/rules/123', rule)
        api_client.update_alert_rule('123', rule)
      end
    end

    describe '#delete_alert_rule' do
      it 'sends a DELETE request to delete an alert rule' do
        expect(api_client).to receive(:request).with('DELETE', '/api/v1/alerts/rules/123')
        api_client.delete_alert_rule('123')
      end
    end

    describe '#get_alert_rules' do
      it 'sends a GET request to retrieve alert rules' do
        expect(api_client).to receive(:request).with('GET', '/api/v1/alerts/rules')
        api_client.get_alert_rules
      end
    end
  end

  describe '#resource_exists?' do
    it 'returns true when resource exists' do
      allow(api_client).to receive(:get_alert_rules).and_return({
        success: true,
        body: { 'data' => [{ 'name' => 'test-rule' }] },
      })

      expect(api_client.resource_exists?(:alert_rule, 'test-rule')).to be true
    end

    it 'returns false when resource does not exist' do
      allow(api_client).to receive(:get_alert_rules).and_return({
        success: true,
        body: { 'data' => [] },
      })

      expect(api_client.resource_exists?(:alert_rule, 'test-rule')).to be false
    end

    it 'returns false when API call fails' do
      allow(api_client).to receive(:get_alert_rules).and_return({
        success: false,
        body: { 'error' => 'Failed' },
      })

      expect(api_client.resource_exists?(:alert_rule, 'test-rule')).to be false
    end
  end
end
