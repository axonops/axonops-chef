#
# Cookbook:: axonops
# Library:: axonops_api
#
# AxonOps API helper library for configuration management
#

require 'net/http'
require 'json'
require 'uri'

module AxonOps
  class API
    attr_reader :base_url, :api_key, :org_name

    def initialize(base_url, api_key = nil, org_name = nil)
      @base_url = base_url.chomp('/')
      @api_key = api_key
      @org_name = org_name
    end

    # Generic API request method
    def request(method, endpoint, body = nil)
      uri = URI.parse("#{@base_url}#{endpoint}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = 30
      http.open_timeout = 10

      case method.upcase
      when 'GET'
        request = Net::HTTP::Get.new(uri.request_uri)
      when 'POST'
        request = Net::HTTP::Post.new(uri.request_uri)
      when 'PUT'
        request = Net::HTTP::Put.new(uri.request_uri)
      when 'DELETE'
        request = Net::HTTP::Delete.new(uri.request_uri)
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end

      # Set headers
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'application/json'

      # Authentication
      if @api_key
        request['X-API-Key'] = @api_key
      end

      if @org_name
        request['X-Organization'] = @org_name
      end

      # Set body if provided
      request.body = body.to_json if body

      # Make request
      response = http.request(request)

      # Parse response
      {
        code: response.code.to_i,
        body: response.body.empty? ? {} : JSON.parse(response.body),
        success: response.code.to_i >= 200 && response.code.to_i < 300,
      }
    rescue StandardError => e
      Chef::Log.error("AxonOps API request failed: #{e.message}")
      {
        code: 0,
        body: { 'error' => e.message },
        success: false,
      }
    end

    # Alert Rules
    def create_alert_rule(rule)
      request('POST', '/api/v1/alerts/rules', rule)
    end

    def update_alert_rule(rule_id, rule)
      request('PUT', "/api/v1/alerts/rules/#{rule_id}", rule)
    end

    def delete_alert_rule(rule_id)
      request('DELETE', "/api/v1/alerts/rules/#{rule_id}")
    end

    def get_alert_rules
      request('GET', '/api/v1/alerts/rules')
    end

    # Alert Endpoints (Notification Channels)
    def create_alert_endpoint(endpoint)
      request('POST', '/api/v1/alerts/endpoints', endpoint)
    end

    def update_alert_endpoint(endpoint_id, endpoint)
      request('PUT', "/api/v1/alerts/endpoints/#{endpoint_id}", endpoint)
    end

    def delete_alert_endpoint(endpoint_id)
      request('DELETE', "/api/v1/alerts/endpoints/#{endpoint_id}")
    end

    def get_alert_endpoints
      request('GET', '/api/v1/alerts/endpoints')
    end

    # Alert Routes
    def create_alert_route(route)
      request('POST', '/api/v1/alerts/routes', route)
    end

    def update_alert_route(route_id, route)
      request('PUT', "/api/v1/alerts/routes/#{route_id}", route)
    end

    def delete_alert_route(route_id)
      request('DELETE', "/api/v1/alerts/routes/#{route_id}")
    end

    def get_alert_routes
      request('GET', '/api/v1/alerts/routes')
    end

    # Service Checks
    def create_service_check(check)
      request('POST', '/api/v1/service-checks', check)
    end

    def update_service_check(check_id, check)
      request('PUT', "/api/v1/service-checks/#{check_id}", check)
    end

    def delete_service_check(check_id)
      request('DELETE', "/api/v1/service-checks/#{check_id}")
    end

    def get_service_checks
      request('GET', '/api/v1/service-checks')
    end

    # Backup Configurations
    def create_backup_config(config)
      request('POST', '/api/v1/backups/configs', config)
    end

    def update_backup_config(config_id, config)
      request('PUT', "/api/v1/backups/configs/#{config_id}", config)
    end

    def delete_backup_config(config_id)
      request('DELETE', "/api/v1/backups/configs/#{config_id}")
    end

    def get_backup_configs
      request('GET', '/api/v1/backups/configs')
    end

    # Log Parsing Rules
    def create_log_rule(rule)
      request('POST', '/api/v1/logs/rules', rule)
    end

    def update_log_rule(rule_id, rule)
      request('PUT', "/api/v1/logs/rules/#{rule_id}", rule)
    end

    def delete_log_rule(rule_id)
      request('DELETE', "/api/v1/logs/rules/#{rule_id}")
    end

    def get_log_rules
      request('GET', '/api/v1/logs/rules')
    end

    # Helper method to check if a resource exists
    def resource_exists?(type, name)
      case type
      when :alert_rule
        response = get_alert_rules
      when :alert_endpoint
        response = get_alert_endpoints
      when :service_check
        response = get_service_checks
      when :backup_config
        response = get_backup_configs
      else
        return false
      end

      return false unless response[:success]

      resources = response[:body]['data'] || response[:body]
      resources.any? { |r| r['name'] == name }
    end
  end
end

# Helper methods for use in recipes
module AxonOpsHelper
  def axonops_api
    @axonops_api ||= begin
      # Determine API endpoint
      base_url = if node['axonops']['deployment_mode'] == 'self-hosted'
                   "http://#{node['axonops']['server']['listen_address']}:#{node['axonops']['server']['listen_port']}"
                 else
                   'https://api.axonops.cloud'
                 end

      AxonOps::API.new(
        base_url,
        node['axonops']['api']['key'],
        node['axonops']['api']['organization']
      )
    end
  end
end

# Make helper available to recipes
Chef::DSL::Recipe.send(:include, AxonOpsHelper)
Chef::Resource.send(:include, AxonOpsHelper)
