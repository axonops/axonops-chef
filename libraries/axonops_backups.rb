require_relative 'axonops'
require_relative 'axonops_utils'
require 'securerandom'
require 'json'

class Chef
  class Resource::AxonopsBackup < Chef::Resource
    resource_name :axonops_backup
    provides :axonops_backup

    property :name, String, name_property: true
    property :tag, String, required: true
    property :local_retention_duration, String, default: '10d'
    property :remote_retention_duration, String, default: '60d'
    property :delegate_remote_retention, [true, false], default: false
    property :remote_type, String, default: 's3',
             equal_to: ['local', 's3', 'sftp', 'azure']
    property :remote_config, String, default: ''
    property :remote_path, String, default: ''
    property :remote, [true, false], default: false
    property :timeout, String, default: '1h'
    property :transfers, Integer, default: 1
    property :tpslimit, Integer, default: 50
    property :bwlimit, String, default: '100M'
    property :full_backup, [true, false], default: false
    property :dynamic_remote_fields, Array, default: []
    property :datacenters, Array, default: []
    property :racks, Array, default: []
    property :nodes, Array, default: []
    property :tables, Array, default: []
    property :all_tables, [true, false], default: false
    property :all_nodes, [true, false], default: true
    property :keyspaces, Array, default: []
    property :simple_schedule, [true, false], default: false
    property :schedule, [true, false], default: true
    property :schedule_expr, String, default: '0 * * * *'
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
      converge_by("Creating/updating AxonOps backup #{new_resource.name}") do
        begin
          # Create AxonOps client instance
          Chef::Log.info("Starting AxonOps backup processing for: #{new_resource.name}")
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

          # Get existing backups
          backups_url = "/api/v1/cassandraScheduleSnapshot/#{new_resource.org}/#{client.get_cluster_type}/#{new_resource.cluster}"
          Chef::Log.info("Fetching backups from: #{backups_url}")
          
          response = client.do_request(backups_url, method: 'GET')
          if response.nil?
            raise "Failed to get backups: No response from API"
          end
          
          current_backups, error = response
          if error
            Chef::Log.error("Failed to get backups: #{error}")
            raise error
          end

          Chef::Log.info("Current backups response: #{current_backups}")
          Chef::Log.info("Response class: #{current_backups.class}")
          Chef::Log.info("Response keys: #{current_backups.keys if current_backups.respond_to?(:keys)}")

          # Find existing backup by tag
          old_backup = nil
          old_backup_details = nil
          if current_backups && current_backups['ScheduledSnapshots']
            Chef::Log.info("Found #{current_backups['ScheduledSnapshots'].length} scheduled snapshots")
            current_backups['ScheduledSnapshots'].each_with_index do |backup, index|
              Chef::Log.info("Backup #{index}: #{backup.inspect}")
              Chef::Log.info("Backup #{index} keys: #{backup.keys}")
              Chef::Log.info("Backup #{index} ID: #{backup['ID']} (class: #{backup['ID'].class})")
              if backup['Params']
                Chef::Log.info("Backup #{index} has #{backup['Params'].length} params")
                backup['Params'].each do |param|
                  if param['BackupDetails']
                    begin
                      backup_details = JSON.parse(param['BackupDetails'])
                      if backup_details['tag'] == new_resource.tag
                        old_backup = backup
                        old_backup_details = backup_details
                        break
                      end
                    rescue JSON::ParserError => e
                      Chef::Log.warn("Failed to parse BackupDetails: #{e.message}")
                    end
                  end
                end
              end
              break if old_backup
            end
          end
          
          Chef::Log.info("Found existing backup: #{old_backup ? 'YES' : 'NO'}")
          Chef::Log.info("Existing backup data: #{old_backup}") if old_backup

          # Exit early if backup doesn't exist and we don't want it to
          if !old_backup && !new_resource.present
            Chef::Log.info("Backup '#{new_resource.tag}' doesn't exist and present is false - nothing to do")
            return
          end

          # Transform tables array to match API format
          tables_data = new_resource.tables.map do |table|
            if table.is_a?(Hash)
              table
            else
              { 'Name' => table.to_s }
            end
          end

          # Check if changes are needed
          changed = true
          if old_backup_details
            if old_backup_details['LocalRetentionDuration'] == new_resource.local_retention_duration &&
               old_backup_details['RemoteRetentionDuration'] == new_resource.remote_retention_duration &&
               old_backup_details['Remote'] == new_resource.remote &&
               old_backup_details['remoteType'] == new_resource.remote_type &&
               old_backup_details['scheduleExpr'] == new_resource.schedule_expr &&
               old_backup_details['keyspaces'] == new_resource.keyspaces &&
               old_backup_details['datacenters'] == new_resource.datacenters
              changed = false
            end
          end

          Chef::Log.info("Change detected: #{changed}")

          if changed || old_backup.nil?
            if new_resource.present
              # If updating, delete the old backup first
              if old_backup
                Chef::Log.info("Deleting existing backup before update")
                delete_payload = [old_backup['ID']]
                response = client.do_request(backups_url, method: 'DELETE', json_data: delete_payload)
                if response.nil?
                  raise "Failed to delete existing backup: No response from API"
                end
                
                result, error = response
                if error
                  raise "Failed to delete existing backup: #{error}"
                end
              end
              
              # Create/Update backup
              backup_payload = {
                'LocalRetentionDuration' => new_resource.local_retention_duration,
                'remoteConfig' => new_resource.remote_config,
                'remotePath' => new_resource.remote_path,
                'RemoteRetentionDuration' => new_resource.remote_retention_duration,
                'delegateRemoteRetention' => new_resource.delegate_remote_retention,
                'remoteType' => new_resource.remote_type,
                'timeout' => new_resource.timeout,
                'transfers' => new_resource.transfers,
                'Remote' => new_resource.remote,
                'tpslimit' => new_resource.tpslimit,
                'bwlimit' => new_resource.bwlimit,
                'fullBackup' => new_resource.full_backup,
                'dynamicRemoteFields' => new_resource.dynamic_remote_fields,
                'tag' => new_resource.tag,
                'datacenters' => new_resource.datacenters,
                'racks' => new_resource.racks,
                'nodes' => new_resource.nodes,
                'tables' => tables_data,
                'allTables' => new_resource.all_tables,
                'allNodes' => new_resource.all_nodes,
                'keyspaces' => new_resource.keyspaces,
                'simpleSchedule' => new_resource.simple_schedule,
                'schedule' => new_resource.schedule,
                'scheduleExpr' => new_resource.schedule_expr
              }

              Chef::Log.info("Sending backup payload to AxonOps: #{backup_payload}")
              
              # Use POST for create/update with different endpoint
              create_url = "/api/v1/cassandraSnapshot/#{new_resource.org}/#{client.get_cluster_type}/#{new_resource.cluster}"
              response = client.do_request(create_url, method: 'POST', json_data: backup_payload)
              if response.nil?
                raise "Failed to create/update backup: No response from API"
              end
              
              result, error = response
              if error
                raise "Failed to create/update backup: #{error}"
              end

              Chef::Log.info("Backup '#{new_resource.tag}' #{old_backup ? 'updated' : 'created'}")
            else
              # Delete backup
              if old_backup
                # Delete the backup using the schedule snapshot endpoint
                Chef::Log.info("Deleting backup - old_backup structure: #{old_backup.inspect}")
                Chef::Log.info("Deleting backup - old_backup ID: #{old_backup['ID']}")
                
                # Check if ID exists
                if old_backup['ID'].nil? || old_backup['ID'].to_s.empty?
                  raise "Backup ID not found in backup structure"
                end
                
                delete_payload = [old_backup['ID']]
                Chef::Log.info("Delete payload (Ruby): #{delete_payload.inspect}")
                Chef::Log.info("Delete payload (JSON): #{delete_payload.to_json}")
                Chef::Log.info("Making DELETE request to: #{backups_url}")
                response = client.do_request(backups_url, method: 'DELETE', json_data: delete_payload)
                if response.nil?
                  raise "Failed to delete backup: No response from API"
                end
                
                result, error = response
                if error
                  raise "Failed to delete backup: #{error}"
                end
                Chef::Log.info("Backup '#{new_resource.tag}' deleted")
              end
            end
          else
            Chef::Log.info("Backup '#{new_resource.tag}' is already in desired state")
          end

        rescue => e
          Chef::Log.error("Error processing backup '#{new_resource.name}': #{e.message}")
          Chef::Log.error("Backtrace: #{e.backtrace.join("\n")}")
          raise e
        end
      end
    end

    action :delete do
      converge_by("Deleting AxonOps backup #{new_resource.name}") do
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
          
          backups_url = "/api/v1/cassandraScheduleSnapshot/#{new_resource.org}/#{client.get_cluster_type}/#{new_resource.cluster}"
          
          response = client.do_request(backups_url, method: 'GET')
          if response.nil?
            raise "Failed to get backups: No response from API"
          end
          
          current_backups, error = response
          if error
            Chef::Log.error("Failed to get backups: #{error}")
            raise error
          end
          
          # Find existing backup by tag
          old_backup = nil
          if current_backups && current_backups['ScheduledSnapshots']
            current_backups['ScheduledSnapshots'].each do |backup|
              if backup['Params']
                backup['Params'].each do |param|
                  if param['BackupDetails']
                    begin
                      backup_details = JSON.parse(param['BackupDetails'])
                      if backup_details['tag'] == new_resource.tag
                        old_backup = backup
                        break
                      end
                    rescue JSON::ParserError => e
                      Chef::Log.warn("Failed to parse BackupDetails: #{e.message}")
                    end
                  end
                end
              end
              break if old_backup
            end
          end
          
          if old_backup
            # Delete the backup using the schedule snapshot endpoint
            Chef::Log.info("Old backup structure: #{old_backup.inspect}")
            Chef::Log.info("Old backup ID: #{old_backup['ID']}")
            
            # Check if ID exists
            if old_backup['ID'].nil? || old_backup['ID'].to_s.empty?
              raise "Backup ID not found in backup structure"
            end
            
            delete_payload = [old_backup['ID']]
            Chef::Log.info("Delete payload (Ruby): #{delete_payload.inspect}")
            Chef::Log.info("Delete payload (JSON): #{delete_payload.to_json}")
            Chef::Log.info("Making DELETE request to: #{backups_url}")
            response = client.do_request(backups_url, method: 'DELETE', json_data: delete_payload)
            if response.nil?
              raise "Failed to delete backup: No response from API"
            end
            
            result, error = response
            if error
              raise "Failed to delete backup: #{error}"
            end
            Chef::Log.info("Backup '#{new_resource.tag}' deleted")
          else
            Chef::Log.info("Backup '#{new_resource.tag}' does not exist - nothing to delete")
          end

        rescue => e
          Chef::Log.error("Error deleting backup '#{new_resource.name}': #{e.message}")
          Chef::Log.error("Backtrace: #{e.backtrace.join("\n")}")
          raise e
        end
      end
    end
  end
end