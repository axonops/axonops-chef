#
# Cookbook:: axonops
# Recipe:: example_alerts
#
# Example recipe demonstrating how to configure alert rules
#

# # Example 1: CPU usage alert
# axonops_alert_rule 'Check for High CPU' do
#   org ENV['AXONOPS_ORG'] || node['axonops']['api']['org']
#   cluster ENV['AXONOPS_CLUSTER'] || node['axonops']['api']['cluster']
#   username ENV['AXONOPS_USERNAME'] || node['axonops']['api']['username'] || ''
#   password ENV['AXONOPS_PASSWORD'] || node['axonops']['api']['password'] || ''
#   base_url ENV['AXONOPS_URL'] || node['axonops']['api']['base_url'] || ''
#   auth_token ENV['AXONOPS_TOKEN'] || node['axonops']['api']['auth_token'] || ''
#   dashboard 'System'
#   chart 'CPU usage per host'
#   metric 'host_CPU_Percent_Merge'
#   operator '>'
#   warning_value 80
#   critical_value 90
#   duration '15m'
#   description 'Alert when CPU usage is too high'
#   routing ['slack-alerts', 'pagerduty']  # Integration names
#   action :delete
# end

# # Example 2: Memory usage alert
# axonops_alert_rule 'high_memory_usage' do
#   org ENV['AXONOPS_ORG'] || node['axonops']['api']['org']
#   cluster ENV['AXONOPS_CLUSTER'] || node['axonops']['api']['cluster']
#   username ENV['AXONOPS_USERNAME'] || node['axonops']['api']['username'] || ''
#   password ENV['AXONOPS_PASSWORD'] || node['axonops']['api']['password'] || ''
#   base_url ENV['AXONOPS_URL'] || node['axonops']['api']['base_url'] || ''
#   auth_token ENV['AXONOPS_TOKEN'] || node['axonops']['api']['auth_token'] || ''
#   dashboard 'System'
#   chart 'Used memory'
#   metric 'host_Memory_Used'
#   operator '>'
#   warning_value 80
#   critical_value 90
#   duration '5m'
#   description 'Alert when memory usage is too high'
#   routing ['slack-alerts', 'pagerduty']  # Integration names
#   action :delete
# end

# # Example: TCP check for storage port
# axonops_tcp_check 'Storage Port Check' do
#   interval '1m'
#   timeout '1m'
#   tcp '{{.comp_listen_address}}:{{.comp_storage_port}}'
#   org ENV['AXONOPS_ORG'] || node['axonops']['api']['org']
#   cluster ENV['AXONOPS_CLUSTER'] || node['axonops']['api']['cluster']
#   username ENV['AXONOPS_USERNAME'] || node['axonops']['api']['username'] || ''
#   password ENV['AXONOPS_PASSWORD'] || node['axonops']['api']['password'] || ''
#   base_url ENV['AXONOPS_URL'] || node['axonops']['api']['base_url'] || ''
#   auth_token ENV['AXONOPS_TOKEN'] || node['axonops']['api']['auth_token'] || ''
#   action :delete
# end

# # Example: Shell check for node down detection
# axonops_shell_check 'NODE DOWN' do
#   interval '30s'
#   timeout '1m'
#   shell '/bin/bash'
#   script <<-SCRIPT
# EXIT_OK=0
# EXIT_WARNING=1
# EXIT_CRITICAL=2

# NODETOOL=/opt/cassandra/bin/nodetool # REPLACE PATH TO nodetool
# WARNING_DN_COUNT=1
# CRITICAL_DN_COUNT=2

# # Get the local Data Center from 'nodetool info'
# local_dc=$($NODETOOL info | awk -F: '/Data Center/{gsub(/^[ \\t]+/, "", $2); print $2}')
# if [ -z $local_dc ]; then
#     exit $EXIT_WARNING
# fi

# # Initialize counts
# local_dn_count=0
# remote_dn_count=0

# # Declare associative arrays
# declare -A dc_dn_counts  # Counts of DN per Data Center
# declare -A dcrack_dn_counts  # Counts of DN per Data Center and Rack

# # Initialize variables
# current_dc=""
# in_node_section=false

# # Process 'nodetool status' output without using a subshell
# while read -r line; do
#     # Check for Data Center line
#     if [[ "$line" =~ ^Datacenter:\\ (.*) ]]; then
#         current_dc="${BASH_REMATCH[1]}"
#         continue
#     fi

#     # Skip irrelevant lines
#     if [[ "$line" =~ ^\\s*$ ]] || [[ "$line" =~ ^==+ ]] || [[ "$line" =~ ^Status= ]]; then
#         continue
#     fi

#     # Trim leading spaces
#     line=$(echo "$line" | sed 's/^[ \\t]*//')

#     # Get the status code (first field)
#     status=$(echo "$line" | awk '{print $1}')

#     # Process nodes with status 'DN'
#     if [[ "$status" == "DN" ]]; then
#         # Extract the Rack (last field)
#         rack=$(echo "$line" | awk '{print $NF}')

#         # Update counts based on whether the node is in the local DC
#         if [[ "$current_dc" == "$local_dc" ]]; then
#             ((local_dn_count++))
#         else
#             ((remote_dn_count++))
#         fi

#         # Update per-DC counts
#         dc_dn_counts["$current_dc"]=$(( ${dc_dn_counts["$current_dc"]} + 1 ))

#         # Update per-DC:Rack counts
#         dcrack_key="${current_dc}:${rack}"
#         dcrack_dn_counts["$dcrack_key"]=$(( ${dcrack_dn_counts["$dcrack_key"]} + 1 ))
#     fi
# done < <($NODETOOL status)

# # Output the counts
# echo "DN in local DC ($local_dc): $local_dn_count"
# echo "DN in remote DC: $remote_dn_count"

# echo -e "\n\t\t\t 'DN' node counts per Data Center:"
# for dc in "${!dc_dn_counts[@]}"; do
#     echo "DC '$dc': ${dc_dn_counts[$dc]} DN nodes"
# done

# echo -e "\n\t\t\t 'DN' node counts per Data Center and Rack:"
# for dcrack in "${!dcrack_dn_counts[@]}"; do
#     echo "$dcrack: ${dcrack_dn_counts[$dcrack]} DN nodes"
# done

# for dc in "${!dc_dn_counts[@]}"; do
#     if [ ${dc_dn_counts[$dc]} -ge $CRITICAL_DN_COUNT ]; then
#         exit $EXIT_CRITICAL
#     elif [ ${dc_dn_counts[$dc]} -eq $WARNING_DN_COUNT ]; then
#         exit $EXIT_WARNING
#     fi
# done

# exit $EXIT_OK
# SCRIPT
#   org ENV['AXONOPS_ORG'] || node['axonops']['api']['org']
#   cluster ENV['AXONOPS_CLUSTER'] || node['axonops']['api']['cluster']
#   username ENV['AXONOPS_USERNAME'] || node['axonops']['api']['username'] || ''
#   password ENV['AXONOPS_PASSWORD'] || node['axonops']['api']['password'] || ''
#   base_url ENV['AXONOPS_URL'] || node['axonops']['api']['base_url'] || ''
#   auth_token ENV['AXONOPS_TOKEN'] || node['axonops']['api']['auth_token'] || ''
#   action :delete
# end

# # Example: HTTP check for health endpoint
# axonops_http_check 'AxonOps API Health Check' do
#   interval '1m'
#   timeout '30s'
#   url 'https://api.axonops.com/health'
#   http_method 'GET'
#   expected_status 200
#   headers({ 'Accept' => 'application/json' })
#   org ENV['AXONOPS_ORG'] || node['axonops']['api']['org']
#   cluster ENV['AXONOPS_CLUSTER'] || node['axonops']['api']['cluster']
#   username ENV['AXONOPS_USERNAME'] || node['axonops']['api']['username'] || ''
#   password ENV['AXONOPS_PASSWORD'] || node['axonops']['api']['password'] || ''
#   base_url ENV['AXONOPS_URL'] || node['axonops']['api']['base_url'] || ''
#   auth_token ENV['AXONOPS_TOKEN'] || node['axonops']['api']['auth_token'] || ''
#   action :delete
# end

# # Example: HTTP check with POST and body
# axonops_http_check 'Webhook Test' do
#   interval '5m'
#   timeout '1m'
#   url 'https://webhook.site/your-webhook-url'
#   http_method 'POST'
#   headers({
#     'Content-Type' => 'application/json',
#     'X-Custom-Header' => 'AxonOps'
#   })
#   body '{"status": "check", "service": "cassandra"}'
#   expected_status 201
#   org ENV['AXONOPS_ORG'] || node['axonops']['api']['org']
#   cluster ENV['AXONOPS_CLUSTER'] || node['axonops']['api']['cluster']
#   username ENV['AXONOPS_USERNAME'] || node['axonops']['api']['username'] || ''
#   password ENV['AXONOPS_PASSWORD'] || node['axonops']['api']['password'] || ''
#   base_url ENV['AXONOPS_URL'] || node['axonops']['api']['base_url'] || ''
#   auth_token ENV['AXONOPS_TOKEN'] || node['axonops']['api']['auth_token'] || ''
#   action :delete
# end

# # Example: Shell check for log file readability
# axonops_shell_check 'axon-agent.log check' do
#   interval '1m'
#   timeout '30s'
#   shell '/bin/bash'
#   script <<-SCRIPT
# if [ -r /var/log/axonops/axon-agent.log ] 
# then 
#   exit 0 
# else 
#   echo 'Unable to read /var/log/axonops/axon-agent.log' 
#   exit 2
# fi
# SCRIPT
#   org ENV['AXONOPS_ORG'] || node['axonops']['api']['org']
#   cluster ENV['AXONOPS_CLUSTER'] || node['axonops']['api']['cluster']
#   username ENV['AXONOPS_USERNAME'] || node['axonops']['api']['username'] || ''
#   password ENV['AXONOPS_PASSWORD'] || node['axonops']['api']['password'] || ''
#   base_url ENV['AXONOPS_URL'] || node['axonops']['api']['base_url'] || ''
#   auth_token ENV['AXONOPS_TOKEN'] || node['axonops']['api']['auth_token'] || ''
#   action :delete
# end

# Example: S3 backup configuration with explicit credentials
axonops_backup "Daily S3 Backup" do
  tag "daily-s3-backup"
  local_retention_duration "1d"
  remote_retention_duration "7d"
  remote true
  remote_type "s3"
  # S3 specific settings (these will auto-generate remote_config)
  s3_region "us-east-1"
  s3_access_key_id "YOUR_ACCESS_KEY_ID"
  s3_secret_access_key "YOUR_SECRET_ACCESS_KEY"
  s3_storage_class "STANDARD"
  s3_acl "private"
  s3_encryption "AES256"
  s3_no_check_bucket true
  s3_disable_checksum false
  remote_path "my-backup-bucket/cassandra-backups"
  schedule true
  schedule_expr "0 2 * * *"  # Daily at 2 AM
  keyspaces ["system_auth", "my_keyspace"]
  datacenters ["dc1"]
  all_nodes true
  all_tables false
  tables [{ "Name" => "important_table" }]
  bwlimit "50M"
  tpslimit 25
  org ENV["AXONOPS_ORG"] || node["axonops"]["api"]["org"]
  cluster ENV["AXONOPS_CLUSTER"] || node["axonops"]["api"]["cluster"]
  username ENV["AXONOPS_USERNAME"] || node["axonops"]["api"]["username"] || ""
  password ENV["AXONOPS_PASSWORD"] || node["axonops"]["api"]["password"] || ""
  base_url ENV["AXONOPS_URL"] || node["axonops"]["api"]["base_url"] || ""
  auth_token ENV["AXONOPS_TOKEN"] || node["axonops"]["api"]["auth_token"] || ""
  action :delete
end

# Example: SFTP backup configuration with explicit credentials
axonops_backup "SFTP Backup" do
  tag "s3-iam-backup"
  local_retention_duration "1d"
  remote_retention_duration "7d"
  remote true
  remote_type "sftp"
  remote_path "my-backup-bucket/cassandra-backups"
  sftp_host "example.com"
  sftp_user "sftp_user"
  sftp_pass "your_sftp_password"
  schedule true
  schedule_expr "0 2 * * *"
  keyspaces ["system_auth"]
  all_nodes true
  org ENV["AXONOPS_ORG"] || node["axonops"]["api"]["org"]
  cluster ENV["AXONOPS_CLUSTER"] || node["axonops"]["api"]["cluster"]
  username ENV["AXONOPS_USERNAME"] || node["axonops"]["api"]["username"] || ""
  password ENV["AXONOPS_PASSWORD"] || node["axonops"]["api"]["password"] || ""
  base_url ENV["AXONOPS_URL"] || node["axonops"]["api"]["base_url"] || ""
  auth_token ENV["AXONOPS_TOKEN"] || node["axonops"]["api"]["auth_token"] || ""
  action :delete
end


# Example: Slack integration
axonops_integration "slack-alerts" do
  integration_type "slack"
  slack_webhook_url "https://hooks.slack.com/services/XXX/XXX/XXXXXXX"
  slack_channel "#alerts"
  slack_axondash_url "https://axonops.internal.axonopsdev.com"
  org ENV["AXONOPS_ORG"] || node["axonops"]["api"]["org"]
  cluster ENV["AXONOPS_CLUSTER"] || node["axonops"]["api"]["cluster"]
  username ENV["AXONOPS_USERNAME"] || node["axonops"]["api"]["username"] || ""
  password ENV["AXONOPS_PASSWORD"] || node["axonops"]["api"]["password"] || ""
  base_url ENV["AXONOPS_URL"] || node["axonops"]["api"]["base_url"] || ""
  auth_token ENV["AXONOPS_TOKEN"] || node["axonops"]["api"]["auth_token"] || ""
  action :delete
end

# Example: PagerDuty integration
axonops_integration "pagerduty-critical" do
  integration_type "pagerduty"
  pagerduty_integration_key "YOUR_PAGERDUTY_INTEGRATION_KEY"
  org ENV["AXONOPS_ORG"] || node["axonops"]["api"]["org"]
  cluster ENV["AXONOPS_CLUSTER"] || node["axonops"]["api"]["cluster"]
  username ENV["AXONOPS_USERNAME"] || node["axonops"]["api"]["username"] || ""
  password ENV["AXONOPS_PASSWORD"] || node["axonops"]["api"]["password"] || ""
  base_url ENV["AXONOPS_URL"] || node["axonops"]["api"]["base_url"] || ""
  auth_token ENV["AXONOPS_TOKEN"] || node["axonops"]["api"]["auth_token"] || ""
  action :delete
end

# Example: Microsoft Teams integration
axonops_integration "teams-alerts" do
  integration_type "microsoft_teams"
  teams_webhook_url "https://outlook.office.com/webhook/YOUR_TEAMS_WEBHOOK"
  org ENV["AXONOPS_ORG"] || node["axonops"]["api"]["org"]
  cluster ENV["AXONOPS_CLUSTER"] || node["axonops"]["api"]["cluster"]
  username ENV["AXONOPS_USERNAME"] || node["axonops"]["api"]["username"] || ""
  password ENV["AXONOPS_PASSWORD"] || node["axonops"]["api"]["password"] || ""
  base_url ENV["AXONOPS_URL"] || node["axonops"]["api"]["base_url"] || ""
  auth_token ENV["AXONOPS_TOKEN"] || node["axonops"]["api"]["auth_token"] || ""
  action :delete
end

# Example: SMTP integration
axonops_integration "email-alerts" do
  integration_type "smtp"
  smtp_server "smtp.example.com"
  smtp_port "587"
  smtp_username "alerts@example.com"
  smtp_password "smtp_password"
  smtp_from "alerts@example.com"
  smtp_receivers "ops-team@example.com"
  smtp_subject "AxonOps Alert"
  smtp_start_tls true
  smtp_auth_login true
  smtp_skip_certificate_verify false
  org ENV["AXONOPS_ORG"] || node["axonops"]["api"]["org"]
  cluster ENV["AXONOPS_CLUSTER"] || node["axonops"]["api"]["cluster"]
  username ENV["AXONOPS_USERNAME"] || node["axonops"]["api"]["username"] || ""
  password ENV["AXONOPS_PASSWORD"] || node["axonops"]["api"]["password"] || ""
  base_url ENV["AXONOPS_URL"] || node["axonops"]["api"]["base_url"] || ""
  auth_token ENV["AXONOPS_TOKEN"] || node["axonops"]["api"]["auth_token"] || ""
  action :delete
end

# Example: ServiceNow integration
axonops_integration "servicenow-incidents" do
  integration_type "servicenow"
  servicenow_instance_url "https://mycompany.service-now.com"
  servicenow_username "api_user"
  servicenow_password "api_password"
  servicenow_client_id "optional_client_id"
  servicenow_client_secret "optional_client_secret"
  org ENV["AXONOPS_ORG"] || node["axonops"]["api"]["org"]
  cluster ENV["AXONOPS_CLUSTER"] || node["axonops"]["api"]["cluster"]
  username ENV["AXONOPS_USERNAME"] || node["axonops"]["api"]["username"] || ""
  password ENV["AXONOPS_PASSWORD"] || node["axonops"]["api"]["password"] || ""
  base_url ENV["AXONOPS_URL"] || node["axonops"]["api"]["base_url"] || ""
  auth_token ENV["AXONOPS_TOKEN"] || node["axonops"]["api"]["auth_token"] || ""
  action :delete
end

# Example: OpsGenie integration
axonops_integration "opsgenie-alerts" do
  integration_type "opsgenie"
  opsgenie_api_key "YOUR_OPSGENIE_API_KEY"
  opsgenie_api_url "https://api.opsgenie.com"
  org ENV["AXONOPS_ORG"] || node["axonops"]["api"]["org"]
  cluster ENV["AXONOPS_CLUSTER"] || node["axonops"]["api"]["cluster"]
  username ENV["AXONOPS_USERNAME"] || node["axonops"]["api"]["username"] || ""
  password ENV["AXONOPS_PASSWORD"] || node["axonops"]["api"]["password"] || ""
  base_url ENV["AXONOPS_URL"] || node["axonops"]["api"]["base_url"] || ""
  auth_token ENV["AXONOPS_TOKEN"] || node["axonops"]["api"]["auth_token"] || ""
  action :delete
end

# Example: General Webhook integration
axonops_integration "generic-webhook" do
  integration_type "general_webhook"
  webhook_url "http://some:8080"
  webhook_headers [
    { "header" => "Auth", "value" => "blab" },
    { "header" => "Other", "value" => "other" }
  ]
  org ENV["AXONOPS_ORG"] || node["axonops"]["api"]["org"]
  cluster ENV["AXONOPS_CLUSTER"] || node["axonops"]["api"]["cluster"]
  username ENV["AXONOPS_USERNAME"] || node["axonops"]["api"]["username"] || ""
  password ENV["AXONOPS_PASSWORD"] || node["axonops"]["api"]["password"] || ""
  base_url ENV["AXONOPS_URL"] || node["axonops"]["api"]["base_url"] || ""
  auth_token ENV["AXONOPS_TOKEN"] || node["axonops"]["api"]["auth_token"] || ""
  action :create
end
