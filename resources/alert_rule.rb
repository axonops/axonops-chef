#
# Cookbook:: axonops
# Resource:: alert_rule
#
# Custom resource for managing AxonOps alert rules via API
#

resource_name :axonops_alert_rule
provides :axonops_alert_rule
unified_mode true

property :rule_name, String, name_property: true
property :metric, String, required: true
property :condition, String, default: 'above', equal_to: %w(above below equal not_equal)
property :threshold, [Integer, Float], required: true
property :duration, String, default: '5m'
property :severity, String, default: 'warning', equal_to: %w(info warning critical)
property :clusters, Array, default: []
property :description, String
property :enabled, [true, false], default: true
property :api_base_url, String
property :api_key, String
property :organization, String

action :create do
  converge_by("Create alert rule #{new_resource.rule_name}") do
    api = get_api_client

    rule = {
      name: new_resource.rule_name,
      metric: new_resource.metric,
      condition: new_resource.condition,
      threshold: new_resource.threshold,
      duration: new_resource.duration,
      severity: new_resource.severity,
      clusters: new_resource.clusters,
      description: new_resource.description || "Alert when #{new_resource.metric} is #{new_resource.condition} #{new_resource.threshold}",
      enabled: new_resource.enabled,
    }

    response = api.create_alert_rule(rule)

    if response[:success]
      Chef::Log.info("Created alert rule: #{new_resource.rule_name}")
    else
      raise("Failed to create alert rule: #{response[:body]['error'] || 'Unknown error'}")
    end
  end
end

action :update do
  converge_by("Update alert rule #{new_resource.rule_name}") do
    api = get_api_client

    # First, get existing rules to find the ID
    response = api.get_alert_rules
    unless response[:success]
      raise("Failed to get alert rules: #{response[:body]['error']}")
    end

    existing_rule = response[:body]['data'].find { |r| r['name'] == new_resource.rule_name }
    unless existing_rule
      Chef::Log.warn("Alert rule #{new_resource.rule_name} not found, creating it")
      action_create
      return
    end

    rule = {
      name: new_resource.rule_name,
      metric: new_resource.metric,
      condition: new_resource.condition,
      threshold: new_resource.threshold,
      duration: new_resource.duration,
      severity: new_resource.severity,
      clusters: new_resource.clusters,
      description: new_resource.description || existing_rule['description'],
      enabled: new_resource.enabled,
    }

    response = api.update_alert_rule(existing_rule['id'], rule)

    if response[:success]
      Chef::Log.info("Updated alert rule: #{new_resource.rule_name}")
    else
      raise("Failed to update alert rule: #{response[:body]['error'] || 'Unknown error'}")
    end
  end
end

action :delete do
  converge_by("Delete alert rule #{new_resource.rule_name}") do
    api = get_api_client

    # First, get existing rules to find the ID
    response = api.get_alert_rules
    unless response[:success]
      raise("Failed to get alert rules: #{response[:body]['error']}")
    end

    existing_rule = response[:body]['data'].find { |r| r['name'] == new_resource.rule_name }
    unless existing_rule
      Chef::Log.info("Alert rule #{new_resource.rule_name} already deleted")
      return
    end

    response = api.delete_alert_rule(existing_rule['id'])

    if response[:success]
      Chef::Log.info("Deleted alert rule: #{new_resource.rule_name}")
    else
      raise("Failed to delete alert rule: #{response[:body]['error'] || 'Unknown error'}")
    end
  end
end

action_class do
  def get_api_client
    require_relative '../libraries/axonops_api'

    base_url = new_resource.api_base_url || begin
      if node['axonops']['deployment_mode'] == 'self-hosted'
        "http://#{node['axonops']['server']['listen_address']}:#{node['axonops']['server']['listen_port']}"
      else
        'https://api.axonops.cloud'
      end
    end

    AxonOps::API.new(
      base_url,
      new_resource.api_key || node['axonops']['api']['key'],
      new_resource.organization || node['axonops']['api']['organization']
    )
  end
end
