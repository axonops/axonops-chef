require_relative 'axonops'
require_relative 'axonops_utils'
require 'securerandom'

class Chef
  class Resource::AxonopsShellCheck < Chef::Resource
    resource_name :axonops_shell_check
    provides :axonops_shell_check

    property :name, String, name_property: true
    property :interval, String, required: true
    property :timeout, String, required: true
    property :shell, String, required: true
    property :script, String, required: true
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

    default_action :create

    action :create do
      converge_by("Creating/updating AxonOps shell check #{new_resource.name}") do
        begin
          # Create AxonOps client instance
          Chef::Log.debug("Starting AxonOps shell check processing for: #{new_resource.name}")
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

          # Get existing health checks (includes httpchecks, tcpchecks, shellchecks)
          health_checks_url = "/api/v1/healthchecks/#{new_resource.org}/#{client.get_cluster_type}/#{new_resource.cluster}"
          Chef::Log.debug("Fetching health checks from: #{health_checks_url}")

          response = client.do_request(health_checks_url, method: 'GET')
          if response.nil?
            raise "Failed to get health checks: No response from API"
          end

          current_health_checks, error = response
          if error
            Chef::Log.error("Failed to get health checks: #{error}")
            raise error
          end

          Chef::Log.debug("Current health checks response: #{current_health_checks}")

          # Ensure we have the proper structure
          current_health_checks ||= {}
          current_health_checks['httpchecks'] ||= []
          current_health_checks['tcpchecks'] ||= []
          current_health_checks['shellchecks'] ||= []

          # Extract shell checks array
          current_shell_checks = current_health_checks['shellchecks']

          # Find existing shell check by name
          old_check = nil
          if current_shell_checks && current_shell_checks.is_a?(Array)
            old_check = current_shell_checks.find { |check| check['name'] == new_resource.name }
          end

          Chef::Log.debug("Found existing shell check: #{old_check ? 'YES' : 'NO'}")
          Chef::Log.debug("Existing shell check data: #{old_check}") if old_check

          # Exit early if check doesn't exist and we don't want it to
          if !old_check && !new_resource.present
            Chef::Log.info("Shell check '#{new_resource.name}' doesn't exist and present is false - nothing to do")
            return
          end

          # Check if changes are needed
          changed = true
          if old_check
            if old_check['interval'] == new_resource.interval &&
               old_check['timeout'] == new_resource.timeout &&
               old_check['shell'] == new_resource.shell &&
               old_check['script'] == new_resource.script
              changed = false
            end
          end

          Chef::Log.debug("Change detected: #{changed}")

          if changed || old_check.nil?
            if new_resource.present
              # Create/Update shell check
              check_id = old_check ? old_check['id'] : SecureRandom.uuid

              shell_check_payload = {
                'id' => check_id,
                'name' => new_resource.name,
                'interval' => new_resource.interval,
                'timeout' => new_resource.timeout,
                'integrations' => {
                  'Type' => '',
                  'Routing' => nil,
                  'OverrideInfo' => false,
                  'OverrideWarning' => false,
                  'OverrideError' => false
                },
                'readonly' => false,
                'shell' => new_resource.shell,
                'script' => new_resource.script,
                'serviceCheckType' => 'shellchecks'
              }

              Chef::Log.debug("Shell check payload: #{shell_check_payload}")

              # Build the updated shell checks array
              updated_shell_checks = current_shell_checks.dup

              if old_check
                # Update existing check
                updated_shell_checks = updated_shell_checks.map do |check|
                  check['id'] == check_id ? shell_check_payload : check
                end
              else
                # Add new check
                updated_shell_checks << shell_check_payload
              end

              # Build complete payload with all check types
              complete_payload = {
                'httpchecks' => current_health_checks['httpchecks'],
                'tcpchecks' => current_health_checks['tcpchecks'],
                'shellchecks' => updated_shell_checks
              }

              Chef::Log.debug("Sending complete payload to AxonOps")

              # Send PUT request with the complete health checks payload
              response = client.do_request(health_checks_url, method: 'PUT', json_data: complete_payload)
              if response.nil?
                raise "Failed to create/update shell check: No response from API"
              end

              result, error = response
              if error
                raise "Failed to create/update shell check: #{error}"
              end

              Chef::Log.info("Shell check '#{new_resource.name}' #{old_check ? 'updated' : 'created'}")
            else
              # Delete shell check
              if old_check
                # Remove the check from the shell checks array
                updated_shell_checks = current_shell_checks.select { |check| check['id'] != old_check['id'] }

                # Build complete payload with all check types
                complete_payload = {
                  'httpchecks' => current_health_checks['httpchecks'],
                  'tcpchecks' => current_health_checks['tcpchecks'],
                  'shellchecks' => updated_shell_checks
                }

                response = client.do_request(health_checks_url, method: 'PUT', json_data: complete_payload)
                if response.nil?
                  raise "Failed to delete shell check: No response from API"
                end

                result, error = response
                if error
                  raise "Failed to delete shell check: #{error}"
                end
                Chef::Log.info("Shell check '#{new_resource.name}' deleted")
              end
            end
          else
            Chef::Log.info("Shell check '#{new_resource.name}' is already in desired state")
          end

        rescue => e
          Chef::Log.error("Error processing shell check '#{new_resource.name}': #{e.message}")
          Chef::Log.error("Backtrace: #{e.backtrace.join("\n")}")
          raise e
        end
      end
    end

    action :delete do
      converge_by("Deleting AxonOps shell check #{new_resource.name}") do
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

          # Get existing health checks
          health_checks_url = "/api/v1/healthchecks/#{new_resource.org}/#{client.get_cluster_type}/#{new_resource.cluster}"

          response = client.do_request(health_checks_url, method: 'GET')
          if response.nil?
            raise "Failed to get health checks: No response from API"
          end

          current_health_checks, error = response
          if error
            Chef::Log.error("Failed to get health checks: #{error}")
            raise error
          end

          # Ensure we have the proper structure
          current_health_checks ||= {}
          current_health_checks['httpchecks'] ||= []
          current_health_checks['tcpchecks'] ||= []
          current_health_checks['shellchecks'] ||= []

          # Extract shell checks array
          current_shell_checks = current_health_checks['shellchecks']

          # Find existing shell check by name
          old_check = nil
          if current_shell_checks && current_shell_checks.is_a?(Array)
            old_check = current_shell_checks.find { |check| check['name'] == new_resource.name }
          end

          if old_check
            # Remove the check from the shell checks array
            updated_shell_checks = current_shell_checks.select { |check| check['id'] != old_check['id'] }

            # Build complete payload with all check types
            complete_payload = {
              'httpchecks' => current_health_checks['httpchecks'],
              'tcpchecks' => current_health_checks['tcpchecks'],
              'shellchecks' => updated_shell_checks
            }

            response = client.do_request(health_checks_url, method: 'PUT', json_data: complete_payload)
            if response.nil?
              raise "Failed to delete shell check: No response from API"
            end

            result, error = response
            if error
              raise "Failed to delete shell check: #{error}"
            end
            Chef::Log.info("Shell check '#{new_resource.name}' deleted")
          else
            Chef::Log.info("Shell check '#{new_resource.name}' does not exist - nothing to delete")
          end

        rescue => e
          Chef::Log.error("Error deleting shell check '#{new_resource.name}': #{e.message}")
          Chef::Log.error("Backtrace: #{e.backtrace.join("\n")}")
          raise e
        end
      end
    end
  end
end
