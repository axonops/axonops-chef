#
# Cookbook:: axonops
# Recipe:: example_alerts
#
# Example recipe demonstrating how to configure alert rules
#

# Example 1: CPU usage alert
axonops_alert_rule 'Check for High CPU' do
  org ENV['AXONOPS_ORG'] || node['axonops']['api']['org']
  cluster ENV['AXONOPS_CLUSTER'] || node['axonops']['api']['cluster']
  username ENV['AXONOPS_USERNAME'] || node['axonops']['api']['username'] || ''
  password ENV['AXONOPS_PASSWORD'] || node['axonops']['api']['password'] || ''
  base_url ENV['AXONOPS_URL'] || node['axonops']['api']['base_url'] || ''
  auth_token ENV['AXONOPS_TOKEN'] || node['axonops']['api']['auth_token'] || ''
  dashboard 'System'
  chart 'CPU usage per host'
  metric 'host_CPU_Percent_Merge'
  operator '>'
  warning_value 80
  critical_value 90
  duration '15m'
  description 'Alert when CPU usage is too high'
  routing ['slack-alerts', 'pagerduty']  # Integration names
  action :create
end

# Example 2: Memory usage alert
axonops_alert_rule 'high_memory_usage' do
  org ENV['AXONOPS_ORG'] || node['axonops']['api']['org']
  cluster ENV['AXONOPS_CLUSTER'] || node['axonops']['api']['cluster']
  username ENV['AXONOPS_USERNAME'] || node['axonops']['api']['username'] || ''
  password ENV['AXONOPS_PASSWORD'] || node['axonops']['api']['password'] || ''
  base_url ENV['AXONOPS_URL'] || node['axonops']['api']['base_url'] || ''
  auth_token ENV['AXONOPS_TOKEN'] || node['axonops']['api']['auth_token'] || ''
  dashboard 'System'
  chart 'Used memory'
  metric 'host_Memory_Used'
  operator '>'
  warning_value 80
  critical_value 90
  duration '5m'
  description 'Alert when memory usage is too high'
  routing ['slack-alerts', 'pagerduty']  # Integration names
  action :create
end

# Example: TCP check for storage port
axonops_tcp_check 'Storage Port Check' do
  interval '1m'
  timeout '1m'
  tcp '{{.comp_listen_address}}:{{.comp_storage_port}}'
  org ENV['AXONOPS_ORG'] || node['axonops']['api']['org']
  cluster ENV['AXONOPS_CLUSTER'] || node['axonops']['api']['cluster']
  username ENV['AXONOPS_USERNAME'] || node['axonops']['api']['username'] || ''
  password ENV['AXONOPS_PASSWORD'] || node['axonops']['api']['password'] || ''
  base_url ENV['AXONOPS_URL'] || node['axonops']['api']['base_url'] || ''
  auth_token ENV['AXONOPS_TOKEN'] || node['axonops']['api']['auth_token'] || ''
  action :create
end

# Example: Shell check for node down detection
axonops_shell_check 'NODE DOWN' do
  interval '30s'
  timeout '1m'
  shell '/bin/bash'
  script <<-SCRIPT
EXIT_OK=0
EXIT_WARNING=1
EXIT_CRITICAL=2

NODETOOL=/opt/cassandra/bin/nodetool # REPLACE PATH TO nodetool
WARNING_DN_COUNT=1
CRITICAL_DN_COUNT=2

# Get the local Data Center from 'nodetool info'
local_dc=$($NODETOOL info | awk -F: '/Data Center/{gsub(/^[ \\t]+/, "", $2); print $2}')
if [ -z $local_dc ]; then
    exit $EXIT_WARNING
fi

# Initialize counts
local_dn_count=0
remote_dn_count=0

# Declare associative arrays
declare -A dc_dn_counts  # Counts of DN per Data Center
declare -A dcrack_dn_counts  # Counts of DN per Data Center and Rack

# Initialize variables
current_dc=""
in_node_section=false

# Process 'nodetool status' output without using a subshell
while read -r line; do
    # Check for Data Center line
    if [[ "$line" =~ ^Datacenter:\\ (.*) ]]; then
        current_dc="${BASH_REMATCH[1]}"
        continue
    fi

    # Skip irrelevant lines
    if [[ "$line" =~ ^\\s*$ ]] || [[ "$line" =~ ^==+ ]] || [[ "$line" =~ ^Status= ]]; then
        continue
    fi

    # Trim leading spaces
    line=$(echo "$line" | sed 's/^[ \\t]*//')

    # Get the status code (first field)
    status=$(echo "$line" | awk '{print $1}')

    # Process nodes with status 'DN'
    if [[ "$status" == "DN" ]]; then
        # Extract the Rack (last field)
        rack=$(echo "$line" | awk '{print $NF}')

        # Update counts based on whether the node is in the local DC
        if [[ "$current_dc" == "$local_dc" ]]; then
            ((local_dn_count++))
        else
            ((remote_dn_count++))
        fi

        # Update per-DC counts
        dc_dn_counts["$current_dc"]=$(( ${dc_dn_counts["$current_dc"]} + 1 ))

        # Update per-DC:Rack counts
        dcrack_key="${current_dc}:${rack}"
        dcrack_dn_counts["$dcrack_key"]=$(( ${dcrack_dn_counts["$dcrack_key"]} + 1 ))
    fi
done < <($NODETOOL status)

# Output the counts
echo "DN in local DC ($local_dc): $local_dn_count"
echo "DN in remote DC: $remote_dn_count"

echo -e "\n\t\t\t 'DN' node counts per Data Center:"
for dc in "${!dc_dn_counts[@]}"; do
    echo "DC '$dc': ${dc_dn_counts[$dc]} DN nodes"
done

echo -e "\n\t\t\t 'DN' node counts per Data Center and Rack:"
for dcrack in "${!dcrack_dn_counts[@]}"; do
    echo "$dcrack: ${dcrack_dn_counts[$dcrack]} DN nodes"
done

for dc in "${!dc_dn_counts[@]}"; do
    if [ ${dc_dn_counts[$dc]} -ge $CRITICAL_DN_COUNT ]; then
        exit $EXIT_CRITICAL
    elif [ ${dc_dn_counts[$dc]} -eq $WARNING_DN_COUNT ]; then
        exit $EXIT_WARNING
    fi
done

exit $EXIT_OK
SCRIPT
  org ENV['AXONOPS_ORG'] || node['axonops']['api']['org']
  cluster ENV['AXONOPS_CLUSTER'] || node['axonops']['api']['cluster']
  username ENV['AXONOPS_USERNAME'] || node['axonops']['api']['username'] || ''
  password ENV['AXONOPS_PASSWORD'] || node['axonops']['api']['password'] || ''
  base_url ENV['AXONOPS_URL'] || node['axonops']['api']['base_url'] || ''
  auth_token ENV['AXONOPS_TOKEN'] || node['axonops']['api']['auth_token'] || ''
  action :create
end

# Example: HTTP check for health endpoint
axonops_http_check 'AxonOps API Health Check' do
  interval '1m'
  timeout '30s'
  url 'https://api.axonops.com/health'
  http_method 'GET'
  expected_status 200
  headers({ 'Accept' => 'application/json' })
  org ENV['AXONOPS_ORG'] || node['axonops']['api']['org']
  cluster ENV['AXONOPS_CLUSTER'] || node['axonops']['api']['cluster']
  username ENV['AXONOPS_USERNAME'] || node['axonops']['api']['username'] || ''
  password ENV['AXONOPS_PASSWORD'] || node['axonops']['api']['password'] || ''
  base_url ENV['AXONOPS_URL'] || node['axonops']['api']['base_url'] || ''
  auth_token ENV['AXONOPS_TOKEN'] || node['axonops']['api']['auth_token'] || ''
  action :create
end

# Example: HTTP check with POST and body
axonops_http_check 'Webhook Test' do
  interval '5m'
  timeout '1m'
  url 'https://webhook.site/your-webhook-url'
  http_method 'POST'
  headers({
    'Content-Type' => 'application/json',
    'X-Custom-Header' => 'AxonOps'
  })
  body '{"status": "check", "service": "cassandra"}'
  expected_status 201
  org ENV['AXONOPS_ORG'] || node['axonops']['api']['org']
  cluster ENV['AXONOPS_CLUSTER'] || node['axonops']['api']['cluster']
  username ENV['AXONOPS_USERNAME'] || node['axonops']['api']['username'] || ''
  password ENV['AXONOPS_PASSWORD'] || node['axonops']['api']['password'] || ''
  base_url ENV['AXONOPS_URL'] || node['axonops']['api']['base_url'] || ''
  auth_token ENV['AXONOPS_TOKEN'] || node['axonops']['api']['auth_token'] || ''
  action :create
end

# Example: Shell check for log file readability
axonops_shell_check 'axon-agent.log check' do
  interval '1m'
  timeout '30s'
  shell '/bin/bash'
  script <<-SCRIPT
if [ -r /var/log/axonops/axon-agent.log ] 
then 
  exit 0 
else 
  echo 'Unable to read /var/log/axonops/axon-agent.log' 
  exit 2
fi
SCRIPT
  org ENV['AXONOPS_ORG'] || node['axonops']['api']['org']
  cluster ENV['AXONOPS_CLUSTER'] || node['axonops']['api']['cluster']
  username ENV['AXONOPS_USERNAME'] || node['axonops']['api']['username'] || ''
  password ENV['AXONOPS_PASSWORD'] || node['axonops']['api']['password'] || ''
  base_url ENV['AXONOPS_URL'] || node['axonops']['api']['base_url'] || ''
  auth_token ENV['AXONOPS_TOKEN'] || node['axonops']['api']['auth_token'] || ''
  action :create
end