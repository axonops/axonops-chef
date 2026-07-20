# Task: Convert from Ansible to Chef

The goal is to convert an Ansible library into Chef.

I have created already axonops_alert_rule.rb which uses axonops.rb and axonops_utils.rb

* axonops_alert_rule.rb is correct, no need to change anything here.
* avoid scoping (private method) as this does not work well with Chef
* Use the sample paylog when provided

## axonops_tcp_checks
Using this recipe as template and guide, convert the following:

From: https://raw.githubusercontent.com/axonops/axonops-ansible-collection/refs/heads/adds-alerts-module/plugins/modules/tcp_check.py
To: axonops_tcp_checks.rb
Sample Payload:

```json
    {
      "id": "dd1862d9-5917-48ab-aadb-7a72eca348d1",
      "name": "Storage Port Check",
      "interval": "1m",
      "timeout": "1m",
      "integrations": {
        "Type": "",
        "Routing": null,
        "OverrideInfo": false,
        "OverrideWarning": false,
        "OverrideError": false
      },
      "readonly": false,
      "tcp": "{{.comp_listen_address}}:{{.comp_storage_port}}",
      "serviceCheckType": "tcpchecks"
    }
```

## axonops_tcp_checks
Using this recipe as template and guide, convert the following:

From: https://raw.githubusercontent.com/axonops/axonops-ansible-collection/refs/heads/adds-alerts-module/plugins/modules/tcp_check.py
To: axonops_tcp_checks.rb
Sample Payload:

```json
{"httpchecks":[{"id":"e346d3dc-4863-45ea-9158-97ce8df0c35a","name":"AxonOps API Health Check","interval":"1m","timeout":"30s","integrations":{"Type":"","Routing":null,"OverrideInfo":false,"OverrideWarning":false,"OverrideError":false},"readonly":false,"http":"http://google.com","tls_skip_verify":false,"method":"GET","headers":{"Accept":["application/json"]},"serviceCheckType":"httpchecks","isNew":false},{"id":"7a1db809-7567-4f43-9eaf-63d34548249c","name":"Webhook Test","interval":"5m","timeout":"1m","integrations":{"Type":"","Routing":null,"OverrideInfo":false,"OverrideWarning":false,"OverrideError":false},"readonly":false,"http":"","tls_skip_verify":false,"method":"POST","headers":{"Content-Type":["application/json"],"X-Custom-Header":["AxonOps"]},"serviceCheckType":"httpchecks"}],"tcpchecks":[{"id":"dd1862d9-5917-48ab-aadb-7a72eca348d1","name":"Storage Port Check","interval":"1m","timeout":"1m","integrations":{"Type":"","Routing":null,"OverrideInfo":false,"OverrideWarning":false,"OverrideError":false},"readonly":false,"tcp":"{{.comp_listen_address}}:{{.comp_storage_port}}","serviceCheckType":"tcpchecks"},{"id":"fc1310bd-df99-4643-b560-12f51cc92359","name":"CQL Port Check","interval":"2m","timeout":"1m","integrations":{"Type":"","Routing":null,"OverrideInfo":false,"OverrideWarning":false,"OverrideError":false},"readonly":false,"tcp":"{{.comp_rpc_address}}:{{.comp_native_transport_port}}","serviceCheckType":"tcpchecks"}],"shellchecks":[{"id":"97f41739-07f8-462f-981b-91b314669f9a","name":"NODE DOWN","interval":"30s","timeout":"1m","integrations":{"Type":"","Routing":null,"OverrideInfo":false,"OverrideWarning":false,"OverrideError":false},"readonly":false,"shell":"/bin/bash","script":"EXIT_OK=0\nEXIT_WARNING=1\nEXIT_CRITICAL=2\n\nNODETOOL=/opt/cassandra/bin/nodetool # REPLACE PATH TO nodetool\nWARNING_DN_COUNT=1\nCRITICAL_DN_COUNT=2\n\n# Get the local Data Center from 'nodetool info'\nlocal_dc=$($NODETOOL info | awk -F: '/Data Center/{gsub(/^[ \\t]+/, \"\", $2); print $2}')\nif [ -z $local_dc ]; then\n    exit $EXIT_WARNING\nfi\n\n# Initialize counts\nlocal_dn_count=0\nremote_dn_count=0\n\n# Declare associative arrays\ndeclare -A dc_dn_counts  # Counts of DN per Data Center\ndeclare -A dcrack_dn_counts  # Counts of DN per Data Center and Rack\n\n# Initialize variables\ncurrent_dc=\"\"\nin_node_section=false\n\n# Process 'nodetool status' output without using a subshell\nwhile read -r line; do\n    # Check for Data Center line\n    if [[ \"$line\" =~ ^Datacenter:\\ (.*) ]]; then\n        current_dc=\"${BASH_REMATCH[1]}\"\n        continue\n    fi\n\n    # Skip irrelevant lines\n    if [[ \"$line\" =~ ^\\s*$ ]] || [[ \"$line\" =~ ^==+ ]] || [[ \"$line\" =~ ^Status= ]]; then\n        continue\n    fi\n\n    # Trim leading spaces\n    line=$(echo \"$line\" | sed 's/^[ \\t]*//')\n\n    # Get the status code (first field)\n    status=$(echo \"$line\" | awk '{print $1}')\n\n    # Process nodes with status 'DN'\n    if [[ \"$status\" == \"DN\" ]]; then\n        # Extract the Rack (last field)\n        rack=$(echo \"$line\" | awk '{print $NF}')\n\n        # Update counts based on whether the node is in the local DC\n        if [[ \"$current_dc\" == \"$local_dc\" ]]; then\n            ((local_dn_count++))\n        else\n            ((remote_dn_count++))\n        fi\n\n        # Update per-DC counts\n        dc_dn_counts[\"$current_dc\"]=$(( ${dc_dn_counts[\"$current_dc\"]} + 1 ))\n\n        # Update per-DC:Rack counts\n        dcrack_key=\"${current_dc}:${rack}\"\n        dcrack_dn_counts[\"$dcrack_key\"]=$(( ${dcrack_dn_counts[\"$dcrack_key\"]} + 1 ))\n    fi\ndone < <($NODETOOL status)\n\n# Output the counts\necho \"DN in local DC ($local_dc): $local_dn_count\"\necho \"DN in remote DC: $remote_dn_count\"\n\necho -e \"\n\t\t\t 'DN' node counts per Data Center:\"\nfor dc in \"${!dc_dn_counts[@]}\"; do\n    echo \"DC '$dc': ${dc_dn_counts[$dc]} DN nodes\"\ndone\n\necho -e \"\n\t\t\t 'DN' node counts per Data Center and Rack:\"\nfor dcrack in \"${!dcrack_dn_counts[@]}\"; do\n    echo \"$dcrack: ${dcrack_dn_counts[$dcrack]} DN nodes\"\ndone\n\nfor dc in \"${!dc_dn_counts[@]}\"; do\n    if [ ${dc_dn_counts[$dc]} -ge $CRITICAL_DN_COUNT ]; then\n        exit $EXIT_CRITICAL\n    elif [ ${dc_dn_counts[$dc]} -eq $WARNING_DN_COUNT ]; then\n        exit $EXIT_WARNING\n    fi\ndone\n\nexit $EXIT_OK\n","serviceCheckType":"shellchecks"},{"id":"e1e382d9-11c9-43ab-a9a4-6bbf6e0b37c1","name":"[dynamic] axon-agent.log","interval":"1m","timeout":"30s","integrations":{"Type":"","Routing":null,"OverrideInfo":false,"OverrideWarning":false,"OverrideError":false},"readonly":true,"shell":"/bin/bash","script":"if [ -r /var/log/axonops/axon-agent.log ] \nthen \n exit 0 \n else \n echo 'Unable to read /var/log/axonops/axon-agent.log' \n exit 2\n fi ","serviceCheckType":"shellchecks"},{"id":"d7821d05-2ea4-4368-86d6-e5e35f438de5","name":"[dynamic] {{.comp_log_file}}","interval":"1m","timeout":"30s","integrations":{"Type":"","Routing":null,"OverrideInfo":false,"OverrideWarning":false,"OverrideError":false},"readonly":true,"shell":"/bin/bash","script":"if [ -r {{.comp_log_file}} ] \nthen \n exit 0 \n else \n echo 'Unable to read {{.comp_log_file}}' \n exit 2\n fi ","serviceCheckType":"shellchecks"},{"id":"9ae5e427-f12a-4bdd-b488-8203f7f5bd8f","name":"axon-agent.log check","interval":"1m","timeout":"30s","integrations":{"Type":"","Routing":null,"OverrideInfo":false,"OverrideWarning":false,"OverrideError":false},"readonly":false,"shell":"/bin/bash","script":"if [ -r /var/log/axonops/axon-agent.log ] \nthen \n  exit 0 \nelse \n  echo 'Unable to read /var/log/axonops/axon-agent.log' \n  exit 2\nfi\n","serviceCheckType":"shellchecks"}]}
```

## axonops_shell_checks

Use axonops_tcp_checks.py as a template and create axonops_shell_checks.py

## axonops_http_checks

Use axonops_tcp_checks.py as a template and create axonops_shell_checks.py

## axonops_backups.py

Task: Convert the Ansible into Chef using the original Ansible code as baseline and following the same pattern as before when libraries/axonops_alert_rule.rb was created. Pay attention to
the json payload to know what attributes are required for the payload.

Source: https://raw.githubusercontent.com/axonops/axonops-ansible-collection/refs/heads/adds-alerts-module/plugins/modules/backup.py
Create: libraries/axonops_backups.rb
Template: libraries/axonops_alert_rule.rb

```json
{"LocalRetentionDuration":"1d","remoteConfig":"type = s3\nprovider = AWS\nstorage_class = STANDARD\nenv_auth = true\nno_check_bucket = true\nregion = us-east-1\nacl = private\nserver_side_encryption = AES256\ndisable_checksum = false","remotePath":"testbucket/somewhere","RemoteRetentionDuration":"1h","delegateRemoteRetention":false,"remoteType":"s3","timeout":"1h","transfers":1,"Remote":true,"tpslimit":50,"bwlimit":"100M","fullBackup":false,"dynamicRemoteFields":[],"tag":"","datacenters":["hel1"],"racks":["rack2"],"nodes":[],"tables":[{"Name":"network_permissions"}],"allTables":false,"allNodes":true,"keyspaces":["system_auth"],"simpleSchedule":false,"schedule":true,"scheduleExpr":"0 * * * *"}
```

## axonops_pagerduty.py

Task: Convert the Ansible into Chef using the original Ansible code as baseline and following the same pattern as before when libraries/axonops_alert_rule.rb was created. Pay attention to
the json payload to know what attributes are required for the payload.
Add an example to recipes/alert_rules.rb

This library combines all the integration types into one. You'll need to add a "type" which can be: slack, pagerduty, smtp, servicenow, temas, opsgenie

Sources:
    https://raw.githubusercontent.com/axonops/axonops-ansible-collection/refs/heads/adds-alerts-module/plugins/modules/pagerduty_integration.py
    https://raw.githubusercontent.com/axonops/axonops-ansible-collection/refs/heads/adds-alerts-module/plugins/modules/opsgenie_integration.py
    https://raw.githubusercontent.com/axonops/axonops-ansible-collection/refs/heads/adds-alerts-module/plugins/modules/servicenow_integration.py
    https://raw.githubusercontent.com/axonops/axonops-ansible-collection/refs/heads/adds-alerts-module/plugins/modules/teams_integration.py
Create: libraries/axonops_integrations.rb
Template: libraries/axonops_alert_rule.rb


* Slack
```json
{"type":"slack","params":{"name":"TEST","channel":"optinal_channel_name","url":"https://hooks.slack.com/services/XXX/XXX/XXXXXXX","axondashUrl":"https://axonops.internal.axonopsdev.com"}}
```

* Teams
```json
{"type":"microsoft_teams","params":{"name":"something","webHookURL":"http://slack_url"}}
```

* SMTP
```json
{"type":"smtp","params":{"name":"smtp","username":"johhn","password":"aaaa","from":"me@me.com","receivers":"you@you.com","subject":"Hello World","server":"192.168.1.1","port":"22","skipCertificateVerify":true,"startTLS":true,"authLogin":true}}
```

* PagerDuty

```json
{"type":"pagerduty","params":{"name":"aaa","integration_key":"aaa"}}
```

* OpsGenie

```json
{"type":"opsgenie","params":{"name":"aaa","opsgenie_key":"aaaa"}}
```

* Generic

```json
{"type":"general_webhook","params":{"name":"generic","url":"http://some:8080","headers":[{"header":"Auth","value":"blab"},{"header":"Ofher","value":"other"}]}}
```

