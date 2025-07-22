require_relative 'axonops'
require_relative 'axonops_utils'
require 'securerandom'

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
    property :warning_value, [Integer, Float], default: 80
    property :critical_value, [Integer, Float], default: 90
    property :duration, String
    property :url_filter, String, default: 'time=30'
    property :scope, Array, default: []
    property :dc, Array, default: []
    property :rack, Array, default: []
    property :host_id, Array, default: []
    property :group_by, Array, default: [], 
             equal_to: ['dc', 'host_id', 'rack', 'scope', []]
    property :routing, Array, default: []
    property :routing_severity, String, default: 'warning',
             equal_to: ['info', 'warning', 'error']
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
    property :api_token, String, default: ''
    property :base_url, String, default: 'https://dash.axonops.cloud'
    property :cluster_type, String, default: 'cassandra',
             equal_to: ['cassandra', 'kafka']
    property :override_saas, [true, false], default: false

    default_action :create

    action :create do
      # Validate required properties when present is true
      if new_resource.present
        if new_resource.operator.nil? || new_resource.warning_value.nil? || 
           new_resource.critical_value.nil? || new_resource.duration.nil?
          raise "operator, warning_value, critical_value, and duration are required when present is true"
        end
      end

      # Always converge to see what's happening
      converge_by("Creating/updating AxonOps alert rule #{new_resource.name}") do
        begin
          # Create AxonOps client instance
          Chef::Log.debug("Starting AxonOps alert rule processing for: #{new_resource.name}")
          client = AxonOps.new(
            org_name: new_resource.org,
            auth_token: new_resource.auth_token,
            api_token: new_resource.api_token,
            username: new_resource.username,
            password: new_resource.password,
            base_url: new_resource.base_url,
            cluster_type: new_resource.cluster_type,
            override_saas: new_resource.override_saas
          )

          # Get existing alert rules
          alerts_url = "/api/v1/alert-rules/#{new_resource.org}/#{client.get_cluster_type}/#{new_resource.cluster}"
          Chef::Log.debug("Fetching alerts from: #{alerts_url}")
          
          response = client.do_request(alerts_url, method: 'GET')
          if response.nil?
            raise "Failed to get alert rules: No response from API"
          end
          
          current_rules, error = response
          if error
            Chef::Log.error("Failed to get alert rules: #{error}")
            raise error
          end

          Chef::Log.debug("Current rules response: #{current_rules}")

          # Get dashboard templates
          dash_templates_url = "/api/v1/dashboardtemplate/#{new_resource.org}/#{client.get_cluster_type}/#{new_resource.cluster}"
          Chef::Log.debug("Fetching dashboard templates from: #{dash_templates_url}")
          
          response = client.do_request(dash_templates_url)
          if response.nil?
            raise "Failed to get dashboard templates: No response from API"
          end
          
          dash_templates, error = response
          if error
            error_message = "Error occurred fetching AxonOps dashboard template: #{dash_templates_url} - #{error}"
            Chef::Log.error(error_message)
            raise error_message
          end

          Chef::Log.debug("Dashboard templates response: #{dash_templates}")

          # Check if we have the expected data structure
          unless dash_templates && dash_templates['dashboards']
            raise "Invalid dashboard templates response: #{dash_templates}"
          end

          # Find the referenced dashboard by name
          new_dash = AxonOpsUtils.find_by_field(dash_templates['dashboards'], 'name', new_resource.dashboard)
          unless new_dash
            raise "Could not find dashboard '#{new_resource.dashboard}' in AxonOps"
          end

          # Find the referenced chart in the dashboard
          new_charts = AxonOpsUtils.find_by_field(new_dash['panels'], 'title', new_resource.chart)
          unless new_charts
            raise "Could not find chart '#{new_resource.chart}' in AxonOps"
          end

          # Select appropriate chart - inline logic
          new_chart = nil
          if new_charts.is_a?(Array)
            # Find chart with queries or events_timeline type
            new_charts.each do |chart|
              if chart.dig('details', 'queries')
                new_chart = chart
                break
              elsif chart['type'] == 'events_timeline'
                new_chart = chart
                break
              end
            end
            new_chart = new_charts.first unless new_chart
          else
            new_chart = new_charts
          end
          
          Chef::Log.debug("Selected chart: #{new_chart}")
          
          # Determine alert name (use resource name or chart title)
          alert_name = new_resource.name.empty? ? new_resource.chart : new_resource.name
          Chef::Log.debug("Alert name: #{alert_name}")

          # Find existing alert rule - with nil check
          current_metricrules = current_rules['metricrules'] if current_rules
          old_alert = nil
          if current_metricrules
            old_alert = AxonOpsUtils.find_by_field(current_metricrules, 'alert', alert_name)
          end
          Chef::Log.debug("Found existing alert: #{old_alert ? 'YES' : 'NO'}")
          Chef::Log.debug("Existing alert data: #{old_alert}") if old_alert

          # Exit early if alert doesn't exist and we don't want it to
          if !old_alert && !new_resource.present
            Chef::Log.info("Alert rule '#{alert_name}' doesn't exist and present is false - nothing to do")
            return
          end

          # Determine metric - inline logic
          metric = new_resource.metric
          if metric.empty?
            if new_chart['type'] == 'events_timeline'
              metric = ''
            else
              # Extract metric from chart query
              begin
                raw_query = new_chart.dig('details', 'queries', 0, 'query')
                raise 'No query found in chart' unless raw_query

                # Clean up query - remove template variables
                metric = raw_query.gsub(/(\w+)=~'(\$\w*)?',?/, '')
                              .gsub(/, *}/, '}')
                              .gsub(/ +/, ' ')
                              .gsub(/\(\$groupBy\)/, '(dc)')
              rescue => e
                raise "Failed getting the metric query from the specified chart: #{e.message}"
              end
            end
          end

          # Build routing data - inline logic with better nil checking
          routing_integrations = []
          if new_resource.routing && new_resource.routing.any?
            new_resource.routing.each do |integration_name|
              next if integration_name.nil? || integration_name.empty?
              
              begin
                Chef::Log.debug("Looking up integration: '#{integration_name}'")
                integration_id = client.find_integration_id_by_name(new_resource.cluster, integration_name)
                Chef::Log.debug("Integration lookup result: #{integration_id}")
                
                if integration_id && !integration_id.to_s.empty?
                  # Ensure integration_id is a string, not an array
                  id_string = integration_id.is_a?(Array) ? integration_id.first.to_s : integration_id.to_s
                  
                  # Double check we have a valid string
                  unless id_string.nil? || id_string.empty?
                    routing_integrations << {
                      'id' => id_string,  # lowercase 'id' and ensure it's a string
                      'severity' => new_resource.routing_severity || 'warning'
                    }
                    Chef::Log.debug("Added integration ID '#{id_string}' for '#{integration_name}' with severity '#{new_resource.routing_severity}'")
                  else
                    Chef::Log.warn("Integration ID for '#{integration_name}' is empty after conversion")
                  end
                else
                  Chef::Log.warn("Could not find integration ID for '#{integration_name}', skipping")
                end
              rescue => e
                Chef::Log.warn("Error finding integration ID for '#{integration_name}': #{e.message}")
                Chef::Log.warn("Backtrace: #{e.backtrace.join("\n")}")
              end
            end
          end

          routing_data = if routing_integrations.empty?
                          {}
                        else
                          {
                            'Routing' => routing_integrations,
                            'OverrideInfo' => true,
                            'OverrideWarning' => false,
                            'OverrideError' => false
                          }
                        end

          # Build alert expression - inline logic with nil checks
          expression = nil
          if new_chart.dig('details', 'queries')
            # Metric expression
            orig_query = new_chart.dig('details', 'queries', 0, 'query')
            if orig_query && new_resource.operator && new_resource.warning_value
              expression = "#{orig_query} #{new_resource.operator} #{new_resource.warning_value}"
            else
              raise "Missing required data for metric expression: query=#{orig_query}, operator=#{new_resource.operator}, warning_value=#{new_resource.warning_value}"
            end
          elsif new_chart['type'] == 'events_timeline'
            # Event expression
            filters = []
            if new_resource.host_id && new_resource.host_id.any?
              filters << "host_id='#{new_resource.host_id.join(',')}'"
            else
              filters << "host_id=''"
            end

            chart_filters = new_chart.dig('details', 'filters') || {}
            filters << "level='#{chart_filters['level']}'" if chart_filters['level']
            filters << "type='#{chart_filters['type']}'" if chart_filters['type']

            filter_expression = filters.join(',')
            if new_resource.operator && new_resource.warning_value
              expression = "events{#{filter_expression}} #{new_resource.operator} #{new_resource.warning_value}"
            else
              raise "Missing required data for event expression: operator=#{new_resource.operator}, warning_value=#{new_resource.warning_value}"
            end
          else
            raise "Unsupported chart type for alert expression: #{new_chart['type']}"
          end

          Chef::Log.debug("Generated expression: #{expression}")

          # Build filters array - inline logic
          filters = []
          filters << { 'Name' => 'dc', 'Value' => new_resource.dc }
          filters << { 'Name' => 'rack', 'Value' => new_resource.rack }
          filters << { 'Name' => 'host_id', 'Value' => new_resource.host_id }
          filters << { 'Name' => 'consistency', 'Value' => new_resource.consistency } unless new_resource.consistency.empty?
          filters << { 'Name' => 'percentile', 'Value' => new_resource.percentile } unless new_resource.percentile.empty?
          filters << { 'Name' => 'keyspace', 'Value' => new_resource.keyspace } unless new_resource.keyspace.empty?
          filters << { 'Name' => 'scope', 'Value' => new_resource.scope } unless new_resource.scope.empty?
          filters << { 'Name' => 'groupBy', 'Value' => new_resource.group_by } unless new_resource.group_by.empty?

          # Check if changes are needed - simplified logic
          changed = true  # For now, always assume changed to force execution
          if old_alert
            # Simple comparison - you can make this more sophisticated later
            if old_alert['operator'] == new_resource.operator.to_s &&
               old_alert['warningValue'] == new_resource.warning_value &&
               old_alert['criticalValue'] == new_resource.critical_value &&
               old_alert['for'] == new_resource.duration &&
               old_alert.dig('annotations', 'description') == new_resource.description
              changed = false
            end
          end

          Chef::Log.debug("Change detected: #{changed}")

          if changed || old_alert.nil?
            if new_resource.present
              # Create/Update alert with nil checks
              widget_url = "/#{new_resource.org}/#{new_resource.cluster_type}/#{new_resource.cluster}/dashboard/#{new_dash['uuid']}?#{new_resource.url_filter}"
              
              # Ensure all required fields are not nil
              alert_id = old_alert ? old_alert['id'] : SecureRandom.uuid
              correlation_id = new_chart['uuid']
              
              unless alert_id && correlation_id && expression
                raise "Missing required fields: alert_id=#{alert_id}, correlation_id=#{correlation_id}, expression=#{expression}"
              end
              
              payload = {
                'alert' => alert_name || new_resource.chart,
                'for' => new_resource.duration.to_s,
                'operator' => new_resource.operator.to_s,
                'warningValue' => new_resource.warning_value,
                'criticalValue' => new_resource.critical_value,
                'annotations' => {
                  'description' => new_resource.description.to_s,
                  'summary' => "#{alert_name} is #{new_resource.operator} than { limit } (current value: {{ $value }})",
                  'widget_url' => widget_url
                },
                'integrations' => routing_data,
                'expr' => expression,
                'widgetTitle' => new_resource.chart.to_s,
                'id' => alert_id,
                'clusterName' => new_resource.cluster.to_s,
                'correlationId' => correlation_id,
                'filters' => filters
              }

              Chef::Log.debug("Sending payload to AxonOps: #{payload}")
              
              response = client.do_request(alerts_url, method: 'POST', json_data: payload)
              if response.nil?
                raise "Failed to create/update alert rule: No response from API"
              end
              
              result, error = response
              if error
                raise "Failed to create/update alert rule: #{error}"
              end

              Chef::Log.info("Alert rule '#{alert_name}' #{old_alert ? 'updated' : 'created'}")
            else
              # Delete alert
              if old_alert
                response = client.do_request("#{alerts_url}/#{old_alert['id']}", method: 'DELETE')
                if response.nil?
                  raise "Failed to delete alert rule: No response from API"
                end
                
                result, error = response
                if error
                  raise "Failed to delete alert rule: #{error}"
                end
                Chef::Log.info("Alert rule '#{alert_name}' deleted")
              end
            end
          else
            Chef::Log.info("Alert rule '#{alert_name}' is already in desired state")
          end

        rescue => e
          Chef::Log.error("Error processing alert rule '#{new_resource.name}': #{e.message}")
          Chef::Log.error("Backtrace: #{e.backtrace.join("\n")}")
          raise e
        end
      end
    end

    action :delete do
      converge_by("Deleting AxonOps alert rule #{new_resource.name}") do
        begin
          client = AxonOps.new(
            org_name: new_resource.org,
            auth_token: new_resource.auth_token,
            api_token: new_resource.api_token,
            username: new_resource.username,
            password: new_resource.password,
            base_url: new_resource.base_url,
            cluster_type: new_resource.cluster_type,
            override_saas: new_resource.override_saas
          )
          
          alerts_url = "/api/v1/alert-rules/#{new_resource.org}/#{client.get_cluster_type}/#{new_resource.cluster}"
          
          response = client.do_request(alerts_url, method: 'GET')
          if response.nil?
            raise "Failed to get alert rules: No response from API"
          end
          
          current_rules, error = response
          if error
            Chef::Log.error("Failed to get alert rules: #{error}")
            raise error
          end

          alert_name = new_resource.name.empty? ? new_resource.chart : new_resource.name
          
          current_metricrules = current_rules['metricrules'] if current_rules
          old_alert = nil
          if current_metricrules
            old_alert = AxonOpsUtils.find_by_field(current_metricrules, 'alert', alert_name)
          end
          
          if old_alert
            response = client.do_request("#{alerts_url}/#{old_alert['id']}", method: 'DELETE')
            if response.nil?
              raise "Failed to delete alert rule: No response from API"
            end
            
            result, error = response
            if error
              raise "Failed to delete alert rule: #{error}"
            end
            Chef::Log.info("Alert rule '#{alert_name}' deleted")
          else
            Chef::Log.info("Alert rule '#{alert_name}' does not exist - nothing to delete")
          end

        rescue => e
          Chef::Log.error("Error deleting alert rule '#{new_resource.name}': #{e.message}")
          Chef::Log.error("Backtrace: #{e.backtrace.join("\n")}")
          raise e
        end
      end
    end
  end
end