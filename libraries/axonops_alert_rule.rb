require_relative 'axonops'
require_relative 'axonops_utils'

class Chef
  class Resource::AxonopsAlertRule < Chef::Resource
    resource_name :axonops_alert_rule
    provides :axonops_alert_rule

    property :name, String, name_property: true
    property :description, String, default: ''
    property :dashboard, String, required: true
    property :org, String, required: false
    property :cluster, String, required: false
    property :chart, String, required: true
    property :metric, String, default: ''
    property :operator, String, equal_to: ['=', '>=', '>', '<=', '<', '!=']
    property :warning_value, Integer, default: 80
    property :critical_value, Integer, default: 90
    property :duration, String
    property :url_filter, String, default: ''
    property :scope, Array, default: []
    property :dc, Array, default: []
    property :rack, Array, default: []
    property :host_id, Array, default: []
    property :group_by, Array, default: [], 
             equal_to: ['dc', 'host_id', 'rack', 'scope', []]
    property :routing, Array, default: []
    property :present, [true, false], default: true
    property :percentile, Array, default: [],
             equal_to: [[], '', '75thPercentile', '95thPercentile', '98thPercentile', 
                       '99thPercentile', '999thPercentile']
    property :consistency, Array, default: [],
             equal_to: [[], '', 'ALL', 'ANY', 'ONE', 'TWO', 'THREE', 'SERIAL', 
                       'QUORUM', 'EACH_QUORUM', 'LOCAL_ONE', 'LOCAL_QUORUM', 'LOCAL_SERIAL']
    property :keyspace, Array, default: []
    property :username, String, default: ''
    property :password, String, default: ''
    property :auth_token, String, default: ''
    property :base_url, String, default: 'https://dash.axonops.cloud'
    property :cluster_type, String, default: 'cassandra',
             equal_to: ['cassandra', 'kafka']

    # Add action definitions as needed
    default_action :create

    action :create do
      # Create AxonOps client instance
      client = AxonOps.new(
        org_name: new_resource.org,
        auth_token: new_resource.auth_token,
        username: new_resource.username,
        password: new_resource.password,
        base_url: new_resource.base_url,
        cluster_type: new_resource.cluster_type
      )
      
      # Get existing alert rules
      alerts_url = "/api/v1/alert-rules/#{new_resource.org}/#{new_resource.cluster_type}/#{new_resource.cluster}"
      current_rules, error = client.do_request(alerts_url, method: 'GET')
      
      if error
        Chef::Log.error("Failed to get alert rules: #{error}")
        raise error
      end
      
      Chef::Log::info(current_rules)
      dash_templates, error = client.do_request(
          "/api/v1/dashboardtemplate/#{new_resource.org}/#{new_resource.cluster_type}/#{new_resource.cluster}")
      if error
        error_message = "Error occurred fetching AxonOps dashboard template: "
                        + "/api/v1/dashboardtemplate/#{new_resource.org}/#{new_resource.cluster_type}/#{new_resource.cluster}"
                        + error
        Chef::Log.error(error_message)
        raise error_message
      end

      # Find the referenced dashboard by name
      new_dash = AxonOpsUtils.find_by_field(dash_templates['dashboards'], 'name', new_resource.dashboard)
      if !new_dash
        Chef::Log.error("Dashboard not found")
        return
      end
      # Find the referenced chart in the dashboard
      new_charts = AxonOpsUtils.find_by_field(new_dash['panels'], 'title', new_resource.chart)
      new_chart = nil
      if !new_charts
        Chef::Log.error("Could not find chart '#{new_resource.chart}' in AxonOps")
        return
      end
      if new_charts.is_a?(Array)
        new_charts.each do |chart|
          if chart['details']['queries']
            new_chart = chart
            break
          end
          if chart['type'] == 'events_timeline'
            new_chart = chart
            break
          end
        end
      end
      puts "Found chart: #{new_chart}"
    end

    action :delete do
      # Implementation logic here
    end
  end
end
