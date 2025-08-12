require_relative 'axonops'
require_relative 'axonops_utils'
require 'securerandom'

class Chef
  class Resource::AxonopsLogAlertRule < Chef::Resource
    resource_name :axonops_log_alert_rule
    provides :axonops_log_alert_rule

    property :name, String, name_property: true
    property :description, String, default: ''
    property :org, String, required: false
    property :cluster, String, required: false
    property :operator, String, default: '>=',
             equal_to: ['=', '>=', '>', '<=', '<', '!=']
    property :warning_value, Integer, required: true
    property :critical_value, Integer, required: true
    property :duration, String, required: true
    property :content, String, default: ''
    property :level, Array, default: [],
             equal_to: [[], 'debug', 'error', 'warning', 'info']
    property :type, Array, default: []
    property :source, Array, default: []
    property :dc, Array, default: []
    property :rack, Array, default: []
    property :host_id, Array, default: []
    property :routing, Array, default: []
    property :routing_severity, String, default: 'warning',
             equal_to: ['info', 'warning', 'error']
    property :present, [true, false], default: true
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
      converge_by("Creating/updating AxonOps log alert rule #{new_resource.name}") do
        begin
          # Create AxonOps client instance
          Chef::Log.debug("Starting AxonOps log alert rule processing for: #{new_resource.name}")
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

          # Find existing log alert rule
          current_metricrules = current_rules['metricrules'] if current_rules
          old_alert = nil
          if current_metricrules
            old_alert = AxonOpsUtils.find_by_field(current_metricrules, 'alert', new_resource.name)
          end
          Chef::Log.debug("Found existing alert: #{old_alert ? 'YES' : 'NO'}")
          Chef::Log.debug("Existing alert data: #{old_alert}") if old_alert

          # Exit early if alert doesn't exist and we don't want it to
          if !old_alert && !new_resource.present
            Chef::Log.info("Log alert rule '#{new_resource.name}' doesn't exist and present is false - nothing to do")
            return
          end

          # Build filters for the expression
          filters = []
          
          # Add content filter if provided
          if new_resource.content && !new_resource.content.empty?
            filters << "message=\"\\\"#{new_resource.content}\\\"\""
          end
          
          # Add level filter if provided
          if new_resource.level && new_resource.level.any?
            level_values = new_resource.level.is_a?(Array) ? new_resource.level.join(',') : new_resource.level
            filters << "level=\"#{level_values}\""
          end
          
          # Add type filter if provided
          if new_resource.type && new_resource.type.any?
            type_values = new_resource.type.is_a?(Array) ? new_resource.type.join(',') : new_resource.type
            filters << "type=\"#{type_values}\""
          end
          
          # Add source filter if provided
          if new_resource.source && new_resource.source.any?
            source_values = new_resource.source.is_a?(Array) ? new_resource.source.join(',') : new_resource.source
            filters << "source=\"#{source_values}\""
          end
                    
          # Build the expression
          filter_expression = filters.join(',')
          expression = "events{#{filter_expression}} #{new_resource.operator} #{new_resource.warning_value}"
          
          Chef::Log.debug("Generated expression: #{expression}")

          # Build routing data
          routing_integrations = []
          if new_resource.routing && new_resource.routing.any?
            new_resource.routing.each do |integration_name|
              next if integration_name.nil? || integration_name.empty?

              begin
                Chef::Log.debug("Looking up integration: '#{integration_name}'")
                integration_id = client.find_integration_id_by_name(new_resource.cluster, integration_name)
                Chef::Log.debug("Integration lookup result: #{integration_id}")

                if integration_id && !integration_id.to_s.empty?
                  id_string = integration_id.is_a?(Array) ? integration_id.first.to_s : integration_id.to_s

                  unless id_string.nil? || id_string.empty?
                    routing_integrations << {
                      'id' => id_string,
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

          # Build location filters array
          location_filters = []
          location_filters << { 'Name' => 'dc', 'Value' => new_resource.dc } unless new_resource.dc.empty?
          location_filters << { 'Name' => 'rack', 'Value' => new_resource.rack } unless new_resource.rack.empty?
          location_filters << { 'Name' => 'host_id', 'Value' => new_resource.host_id } unless new_resource.host_id.empty?

          # Check if changes are needed
          changed = true
          if old_alert
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
              # Create/Update log alert
              alert_id = old_alert ? old_alert['id'] : SecureRandom.uuid
              
              # Build summary with log content info
              summary_parts = ["Log alert '#{new_resource.name}' triggered"]
              summary_parts << "with content '#{new_resource.content}'" if new_resource.content && !new_resource.content.empty?
              summary_parts << "from source '#{new_resource.source.join(', ')}'" if new_resource.source && new_resource.source.any?
              summary = summary_parts.join(' ')

              payload = {
                'alert' => new_resource.name,
                'for' => new_resource.duration.to_s,
                'operator' => new_resource.operator.to_s,
                'warningValue' => new_resource.warning_value,
                'criticalValue' => new_resource.critical_value,
                'annotations' => {
                  'description' => new_resource.description.to_s,
                  'summary' => summary
                },
                'integrations' => routing_data,
                'expr' => expression,
                'id' => alert_id,
                'clusterName' => new_resource.cluster.to_s,
                'filters' => location_filters,
              }

              Chef::Log.debug("Sending payload to AxonOps: #{payload}")

              response = client.do_request(alerts_url, method: 'POST', json_data: payload)
              if response.nil?
                raise "Failed to create/update log alert rule: No response from API"
              end

              result, error = response
              if error
                raise "Failed to create/update log alert rule: #{error}"
              end

              Chef::Log.info("Log alert rule '#{new_resource.name}' #{old_alert ? 'updated' : 'created'}")
            else
              # Delete alert
              if old_alert
                response = client.do_request("#{alerts_url}/#{old_alert['id']}", method: 'DELETE')
                if response.nil?
                  raise "Failed to delete log alert rule: No response from API"
                end

                result, error = response
                if error
                  raise "Failed to delete log alert rule: #{error}"
                end
                Chef::Log.info("Log alert rule '#{new_resource.name}' deleted")
              end
            end
          else
            Chef::Log.info("Log alert rule '#{new_resource.name}' is already in desired state")
          end

        rescue => e
          Chef::Log.error("Error processing log alert rule '#{new_resource.name}': #{e.message}")
          Chef::Log.error("Backtrace: #{e.backtrace.join("\n")}")
          raise e
        end
      end
    end

    action :delete do
      converge_by("Deleting AxonOps log alert rule #{new_resource.name}") do
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

          current_metricrules = current_rules['metricrules'] if current_rules
          old_alert = nil
          if current_metricrules
            old_alert = AxonOpsUtils.find_by_field(current_metricrules, 'alert', new_resource.name)
          end

          if old_alert
            response = client.do_request("#{alerts_url}/#{old_alert['id']}", method: 'DELETE')
            if response.nil?
              raise "Failed to delete log alert rule: No response from API"
            end

            result, error = response
            if error
              raise "Failed to delete log alert rule: #{error}"
            end
            Chef::Log.info("Log alert rule '#{new_resource.name}' deleted")
          else
            Chef::Log.info("Log alert rule '#{new_resource.name}' does not exist - nothing to delete")
          end

        rescue => e
          Chef::Log.error("Error deleting log alert rule '#{new_resource.name}': #{e.message}")
          Chef::Log.error("Backtrace: #{e.backtrace.join("\n")}")
          raise e
        end
      end
    end
  end
end