require_relative 'axonops'
require_relative 'axonops_utils'
require 'json'

class Chef
  class Resource::AxonopsIntegration < Chef::Resource
    resource_name :axonops_integration
    provides :axonops_integration

    property :name, String, name_property: true
    property :integration_type, String, required: true,
             equal_to: ['slack', 'pagerduty', 'smtp', 'servicenow', 'microsoft_teams', 'opsgenie', 'general_webhook']

    # Common properties
    property :present, [true, false], default: true
    property :org, String, required: false
    property :cluster, String, required: false
    property :username, String, default: ''
    property :password, String, default: ''
    property :auth_token, String, default: ''
    property :api_token, String, default: ''
    property :base_url, String, default: 'https://dash.axonops.cloud'
    property :cluster_type, String, default: 'cassandra',
             equal_to: ['cassandra', 'kafka']
    property :override_saas, [true, false], default: false

    # Slack specific properties
    property :slack_webhook_url, String, default: ''
    property :slack_channel, String, default: ''
    property :slack_axondash_url, String, default: ''

    # PagerDuty specific properties
    property :pagerduty_integration_key, String, default: ''

    # Teams specific properties
    property :teams_webhook_url, String, default: ''

    # SMTP specific properties
    property :smtp_username, String, default: ''
    property :smtp_password, String, default: ''
    property :smtp_from, String, default: ''
    property :smtp_receivers, String, default: ''
    property :smtp_subject, String, default: ''
    property :smtp_server, String, default: ''
    property :smtp_port, String, default: '25'
    property :smtp_skip_certificate_verify, [true, false], default: false
    property :smtp_start_tls, [true, false], default: true
    property :smtp_auth_login, [true, false], default: true

    # ServiceNow specific properties
    property :servicenow_instance_url, String, default: ''
    property :servicenow_username, String, default: ''
    property :servicenow_password, String, default: ''
    property :servicenow_client_id, String, default: ''
    property :servicenow_client_secret, String, default: ''

    # OpsGenie specific properties
    property :opsgenie_api_key, String, default: ''
    property :opsgenie_api_url, String, default: 'https://api.opsgenie.com'

    # General Webhook specific properties
    property :webhook_url, String, default: ''
    property :webhook_headers, Array, default: []

    default_action :create

    action :create do
      converge_by("Creating/updating AxonOps #{new_resource.integration_type} integration #{new_resource.name}") do
        begin
          # Create AxonOps client instance
          Chef::Log.debug("Starting AxonOps integration processing for: #{new_resource.name} (#{new_resource.integration_type})")
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

          # Get existing integrations
          integrations_url = "/api/v1/integrations/#{new_resource.org}/#{client.get_cluster_type}/#{new_resource.cluster}"
          Chef::Log.debug("Fetching integrations from: #{integrations_url}")

          response = client.do_request(integrations_url, method: 'GET')
          if response.nil?
            raise "Failed to get integrations: No response from API"
          end

          current_integrations, error = response
          if error
            Chef::Log.error("Failed to get integrations: #{error}")
            raise error
          end

          Chef::Log.debug("Current integrations response: #{current_integrations}")
          Chef::Log.debug("Response type: #{current_integrations.class}")
          if current_integrations.is_a?(Hash)
            Chef::Log.debug("Response keys: #{current_integrations.keys}")
          end

          # Find existing integration by name and type
          old_integration = nil
          definitions = current_integrations && current_integrations['Definitions'] ? current_integrations['Definitions'] : []

          if definitions && definitions.is_a?(Array)
            Chef::Log.debug("Looking for integration with type '#{new_resource.integration_type}' and name '#{new_resource.name}'")
            definitions.each do |integration|
              Chef::Log.debug("Checking integration: type='#{integration['Type']}', name='#{integration.dig('Params', 'name')}', ID='#{integration['ID']}'")
            end
            old_integration = definitions.find do |integration|
              integration['Type'] == new_resource.integration_type &&
              integration.dig('Params', 'name') == new_resource.name
            end
          end

          Chef::Log.debug("Found existing integration: #{old_integration ? 'YES' : 'NO'}")
          Chef::Log.debug("Existing integration data: #{old_integration}") if old_integration

          # Exit early if integration doesn't exist and we don't want it to
          if !old_integration && !new_resource.present
            Chef::Log.info("Integration '#{new_resource.name}' doesn't exist and present is false - nothing to do")
            return
          end

          # Check if an integration with the same name already exists (but different type)
          if !old_integration && new_resource.present
            # Check for any integration with the same name
            existing_with_same_name = definitions.find do |integration|
              integration.dig('Params', 'name') == new_resource.name
            end

            if existing_with_same_name
              raise "Integration with name '#{new_resource.name}' already exists with type '#{existing_with_same_name['Type']}'. Integration names must be unique."
            end
          end

          # Build the integration payload based on type
          integration_payload = {
            'Type' => new_resource.integration_type,
            'Params' => {
              'name' => new_resource.name
            }
          }

          case new_resource.integration_type
          when 'slack'
            integration_payload['Params']['url'] = new_resource.slack_webhook_url
            integration_payload['Params']['channel'] = new_resource.slack_channel unless new_resource.slack_channel.empty?
            integration_payload['Params']['axondashUrl'] = new_resource.slack_axondash_url unless new_resource.slack_axondash_url.empty?

          when 'pagerduty'
            integration_payload['Params']['integration_key'] = new_resource.pagerduty_integration_key

          when 'microsoft_teams'
            integration_payload['Params']['webHookURL'] = new_resource.teams_webhook_url

          when 'smtp'
            integration_payload['Params']['username'] = new_resource.smtp_username
            integration_payload['Params']['password'] = new_resource.smtp_password
            integration_payload['Params']['from'] = new_resource.smtp_from
            integration_payload['Params']['receivers'] = new_resource.smtp_receivers
            integration_payload['Params']['subject'] = new_resource.smtp_subject
            integration_payload['Params']['server'] = new_resource.smtp_server
            integration_payload['Params']['port'] = new_resource.smtp_port
            integration_payload['Params']['skipCertificateVerify'] = new_resource.smtp_skip_certificate_verify
            integration_payload['Params']['startTLS'] = new_resource.smtp_start_tls
            integration_payload['Params']['authLogin'] = new_resource.smtp_auth_login

          when 'servicenow'
            integration_payload['Params']['instance_url'] = new_resource.servicenow_instance_url
            integration_payload['Params']['username'] = new_resource.servicenow_username
            integration_payload['Params']['password'] = new_resource.servicenow_password
            integration_payload['Params']['client_id'] = new_resource.servicenow_client_id unless new_resource.servicenow_client_id.empty?
            integration_payload['Params']['client_secret'] = new_resource.servicenow_client_secret unless new_resource.servicenow_client_secret.empty?

          when 'opsgenie'
            integration_payload['Params']['api_key'] = new_resource.opsgenie_api_key
            integration_payload['Params']['api_url'] = new_resource.opsgenie_api_url

          when 'general_webhook'
            integration_payload['Params']['url'] = new_resource.webhook_url
            integration_payload['Params']['headers'] = new_resource.webhook_headers
          end

          # Check if changes are needed
          changed = true
          if old_integration
            # Compare the params
            if old_integration['Params'] == integration_payload['Params']
              changed = false
            end
          end

          Chef::Log.debug("Change detected: #{changed}")

          if changed || old_integration.nil?
            if new_resource.present
              # Create/Update integration
              Chef::Log.debug("Sending integration payload to AxonOps: #{integration_payload}")

              response = client.do_request(integrations_url, method: 'POST', json_data: integration_payload)
              if response.nil?
                raise "Failed to create/update integration: No response from API"
              end

              result, error = response
              if error
                raise "Failed to create/update integration: #{error}"
              end

              Chef::Log.info("Integration '#{new_resource.name}' #{old_integration ? 'updated' : 'created'}")
            else
              # Delete integration
              if old_integration
                delete_url = "#{integrations_url}/#{old_integration['ID']}"
                response = client.do_request(delete_url, method: 'DELETE')
                if response.nil?
                  raise "Failed to delete integration: No response from API"
                end

                result, error = response
                if error
                  raise "Failed to delete integration: #{error}"
                end
                Chef::Log.info("Integration '#{new_resource.name}' deleted")
              end
            end
          else
            Chef::Log.info("Integration '#{new_resource.name}' is already in desired state")
          end

        rescue => e
          Chef::Log.error("Error processing integration '#{new_resource.name}': #{e.message}")
          Chef::Log.error("Backtrace: #{e.backtrace.join("\n")}")
          raise e
        end
      end
    end

    action :delete do
      converge_by("Deleting AxonOps integration #{new_resource.name}") do
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

          integrations_url = "/api/v1/integrations/#{new_resource.org}/#{client.get_cluster_type}/#{new_resource.cluster}"

          response = client.do_request(integrations_url, method: 'GET')
          if response.nil?
            raise "Failed to get integrations: No response from API"
          end

          current_integrations, error = response
          if error
            Chef::Log.error("Failed to get integrations: #{error}")
            raise error
          end

          Chef::Log.debug("Current integrations response: #{current_integrations}")

          # Find existing integration by name and type
          old_integration = nil
          definitions = current_integrations && current_integrations['Definitions'] ? current_integrations['Definitions'] : []

          if definitions && definitions.is_a?(Array)
            Chef::Log.debug("Looking for integration with type '#{new_resource.integration_type}' and name '#{new_resource.name}'")
            definitions.each do |integration|
              Chef::Log.debug("Checking integration: type='#{integration['Type']}', name='#{integration.dig('Params', 'name')}', ID='#{integration['ID']}'")
            end
            old_integration = definitions.find do |integration|
              integration['Type'] == new_resource.integration_type &&
              integration.dig('Params', 'name') == new_resource.name
            end
          end

          if old_integration
            delete_url = "#{integrations_url}/#{old_integration['ID']}"
            response = client.do_request(delete_url, method: 'DELETE')
            if response.nil?
              raise "Failed to delete integration: No response from API"
            end

            result, error = response
            if error
              raise "Failed to delete integration: #{error}"
            end
            Chef::Log.info("Integration '#{new_resource.name}' deleted")
          else
            Chef::Log.info("Integration '#{new_resource.name}' does not exist - nothing to delete")
          end

        rescue => e
          Chef::Log.error("Error deleting integration '#{new_resource.name}': #{e.message}")
          Chef::Log.error("Backtrace: #{e.backtrace.join("\n")}")
          raise e
        end
      end
    end
  end
end
