# Alert Rules
if node['axonops'] && node['axonops']['alert_rules']
  node['axonops']['alert_rules'].each do |alert_rule|
    axonops_alert_rule alert_rule['name'] do
      org        ENV['AXONOPS_ORG']       || alert_rule['org']       || node['axonops']['api']['org']
      cluster    ENV['AXONOPS_CLUSTER']   || alert_rule['cluster']   || node['axonops']['api']['cluster']
      username   ENV['AXONOPS_USERNAME']  || alert_rule['username']  || node['axonops']['api']['username'] || ''
      password   ENV['AXONOPS_PASSWORD']  || alert_rule['password']  || node['axonops']['api']['password'] || ''
      base_url   ENV['AXONOPS_URL']       || alert_rule['base_url']  || node['axonops']['api']['base_url'] || ''
      auth_token ENV['AXONOPS_TOKEN']     || alert_rule['auth_token']|| node['axonops']['api']['auth_token'] || ''
      dashboard      alert_rule['dashboard']
      chart          alert_rule['chart']
      metric         alert_rule['metric']
      operator       alert_rule['operator']
      warning_value  alert_rule['warning_value']
      critical_value alert_rule['critical_value']
      duration       alert_rule['duration']
      description    alert_rule['description']
      # Handle routing as either Array or Hash
      routing_value = alert_rule['routing']
      if routing_value.is_a?(Hash)
        # If routing is a Hash with severity levels, flatten all values into a single array
        routing routing_value.values.flatten.compact.uniq
      elsif routing_value
        # If routing is already an Array or can be converted to one
        routing Array(routing_value).compact
      end
      routing_severity alert_rule['routing_severity'] if alert_rule['routing_severity']
      action         alert_rule['action'] ? alert_rule['action'].to_sym : :create
    end
  end
end

# TCP Checks
if node['axonops'] && node['axonops']['tcp_checks']
  node['axonops']['tcp_checks'].each do |tcp_check|
    axonops_tcp_check tcp_check['name'] do
      org        ENV['AXONOPS_ORG']       || tcp_check['org']       || node['axonops']['api']['org']
      cluster    ENV['AXONOPS_CLUSTER']   || tcp_check['cluster']   || node['axonops']['api']['cluster']
      username   ENV['AXONOPS_USERNAME']  || tcp_check['username']  || node['axonops']['api']['username'] || ''
      password   ENV['AXONOPS_PASSWORD']  || tcp_check['password']  || node['axonops']['api']['password'] || ''
      base_url   ENV['AXONOPS_URL']       || tcp_check['base_url']  || node['axonops']['api']['base_url'] || ''
      auth_token ENV['AXONOPS_TOKEN']     || tcp_check['auth_token']|| node['axonops']['api']['auth_token'] || ''
      interval   tcp_check['interval']    || '1m'
      timeout    tcp_check['timeout']     || '1m'
      tcp        tcp_check['tcp']
      action     tcp_check['action'] ? tcp_check['action'].to_sym : :create
    end
  end
end

# Shell Checks
if node['axonops'] && node['axonops']['shell_checks']
  node['axonops']['shell_checks'].each do |shell_check|
    axonops_shell_check shell_check['name'] do
      org        ENV['AXONOPS_ORG']       || shell_check['org']       || node['axonops']['api']['org']
      cluster    ENV['AXONOPS_CLUSTER']   || shell_check['cluster']   || node['axonops']['api']['cluster']
      username   ENV['AXONOPS_USERNAME']  || shell_check['username']  || node['axonops']['api']['username'] || ''
      password   ENV['AXONOPS_PASSWORD']  || shell_check['password']  || node['axonops']['api']['password'] || ''
      base_url   ENV['AXONOPS_URL']       || shell_check['base_url']  || node['axonops']['api']['base_url'] || ''
      auth_token ENV['AXONOPS_TOKEN']     || shell_check['auth_token']|| node['axonops']['api']['auth_token'] || ''
      interval   shell_check['interval']  || '1m'
      timeout    shell_check['timeout']   || '30s'
      shell      shell_check['shell']     || '/bin/bash'
      script     shell_check['script']
      action     shell_check['action'] ? shell_check['action'].to_sym : :create
    end
  end
end

# HTTP Checks
if node['axonops'] && node['axonops']['http_checks']
  node['axonops']['http_checks'].each do |http_check|
    axonops_http_check http_check['name'] do
      org             ENV['AXONOPS_ORG']       || http_check['org']       || node['axonops']['api']['org']
      cluster         ENV['AXONOPS_CLUSTER']   || http_check['cluster']   || node['axonops']['api']['cluster']
      username        ENV['AXONOPS_USERNAME']  || http_check['username']  || node['axonops']['api']['username'] || ''
      password        ENV['AXONOPS_PASSWORD']  || http_check['password']  || node['axonops']['api']['password'] || ''
      base_url        ENV['AXONOPS_URL']       || http_check['base_url']  || node['axonops']['api']['base_url'] || ''
      auth_token      ENV['AXONOPS_TOKEN']     || http_check['auth_token']|| node['axonops']['api']['auth_token'] || ''
      interval        http_check['interval']       || '1m'
      timeout         http_check['timeout']        || '30s'
      url             http_check['url']
      http_method     http_check['http_method']    || 'GET'
      expected_status http_check['expected_status'] || 200
      headers         http_check['headers']         || {}
      body            http_check['body']            if http_check['body']
      action          http_check['action'] ? http_check['action'].to_sym : :create
    end
  end
end

# Backups
if node['axonops'] && node['axonops']['backups']
  node['axonops']['backups'].each do |backup|
    axonops_backup backup['name'] do
      org                      ENV['AXONOPS_ORG']       || backup['org']       || node['axonops']['api']['org']
      cluster                  ENV['AXONOPS_CLUSTER']   || backup['cluster']   || node['axonops']['api']['cluster']
      username                 ENV['AXONOPS_USERNAME']  || backup['username']  || node['axonops']['api']['username'] || ''
      password                 ENV['AXONOPS_PASSWORD']  || backup['password']  || node['axonops']['api']['password'] || ''
      base_url                 ENV['AXONOPS_URL']       || backup['base_url']  || node['axonops']['api']['base_url'] || ''
      auth_token               ENV['AXONOPS_TOKEN']     || backup['auth_token']|| node['axonops']['api']['auth_token'] || ''
      tag                      backup['tag']
      local_retention_duration backup['local_retention_duration']  || '10d'
      remote_retention_duration backup['remote_retention_duration'] || '60d'
      delegate_remote_retention backup['delegate_remote_retention'] if backup.key?('delegate_remote_retention')
      remote_type              backup['remote_type']                || 's3'
      remote_config            backup['remote_config']              if backup['remote_config']
      remote_path              backup['remote_path']                || ''
      remote                   backup['remote']                     if backup.key?('remote')
      timeout                  backup['timeout']                    || '1h'
      transfers                backup['transfers']                  || 1
      tpslimit                 backup['tpslimit']                   || 50
      bwlimit                  backup['bwlimit']                    || '100M'
      full_backup              backup['full_backup']                if backup.key?('full_backup')
      dynamic_remote_fields    backup['dynamic_remote_fields']      || []
      datacenters              backup['datacenters']                || []
      racks                    backup['racks']                      || []
      nodes                    backup['nodes']                      || []
      tables                   backup['tables']                     || []
      all_tables               backup['all_tables']                 if backup.key?('all_tables')
      all_nodes                backup['all_nodes']                  if backup.key?('all_nodes')
      keyspaces                backup['keyspaces']                  || []
      simple_schedule          backup['simple_schedule']            if backup.key?('simple_schedule')
      schedule                 backup['schedule']                   if backup.key?('schedule')
      schedule_expr            backup['schedule_expr']              || '0 * * * *'
      # S3 specific settings
      s3_region                backup['s3_region']                  if backup['s3_region']
      s3_access_key_id         backup['s3_access_key_id']           if backup['s3_access_key_id']
      s3_secret_access_key     backup['s3_secret_access_key']       if backup['s3_secret_access_key']
      s3_storage_class         backup['s3_storage_class']           if backup['s3_storage_class']
      s3_acl                   backup['s3_acl']                     if backup['s3_acl']
      s3_encryption            backup['s3_encryption']              if backup['s3_encryption']
      s3_no_check_bucket       backup['s3_no_check_bucket']         if backup.key?('s3_no_check_bucket')
      s3_disable_checksum      backup['s3_disable_checksum']        if backup.key?('s3_disable_checksum')
      # SFTP specific settings
      sftp_host                backup['sftp_host']                  if backup['sftp_host']
      sftp_user                backup['sftp_user']                  if backup['sftp_user']
      sftp_pass                backup['sftp_pass']                  if backup['sftp_pass']
      sftp_port                backup['sftp_port']                  if backup['sftp_port']
      sftp_key_file            backup['sftp_key_file']              if backup['sftp_key_file']
      # Azure specific settings
      azure_account            backup['azure_account']              if backup['azure_account']
      azure_key                backup['azure_key']                  if backup['azure_key']
      azure_use_msi            backup['azure_use_msi']              if backup.key?('azure_use_msi')
      azure_msi_object_id      backup['azure_msi_object_id']        if backup['azure_msi_object_id']
      azure_msi_client_id      backup['azure_msi_client_id']        if backup['azure_msi_client_id']
      azure_msi_mi_res_id      backup['azure_msi_mi_res_id']        if backup['azure_msi_mi_res_id']
      action                   backup['action'] ? backup['action'].to_sym : :create
    end
  end
end

# Integrations
if node['axonops'] && node['axonops']['integrations']
  node['axonops']['integrations'].each do |integration|
    axonops_integration integration['name'] do
      org                       ENV['AXONOPS_ORG']       || integration['org']       || node['axonops']['api']['org']
      cluster                   ENV['AXONOPS_CLUSTER']   || integration['cluster']   || node['axonops']['api']['cluster']
      username                  ENV['AXONOPS_USERNAME']  || integration['username']  || node['axonops']['api']['username'] || ''
      password                  ENV['AXONOPS_PASSWORD']  || integration['password']  || node['axonops']['api']['password'] || ''
      base_url                  ENV['AXONOPS_URL']       || integration['base_url']  || node['axonops']['api']['base_url'] || ''
      auth_token                ENV['AXONOPS_TOKEN']     || integration['auth_token']|| node['axonops']['api']['auth_token'] || ''
      integration_type          integration['integration_type']
      # Slack specific properties
      slack_webhook_url         integration['slack_webhook_url']      if integration['slack_webhook_url']
      slack_channel             integration['slack_channel']          if integration['slack_channel']
      slack_axondash_url        integration['slack_axondash_url']     if integration['slack_axondash_url']
      # PagerDuty specific properties
      pagerduty_integration_key integration['pagerduty_integration_key'] if integration['pagerduty_integration_key']
      # Teams specific properties
      teams_webhook_url         integration['teams_webhook_url']      if integration['teams_webhook_url']
      # SMTP specific properties
      smtp_username             integration['smtp_username']          if integration['smtp_username']
      smtp_password             integration['smtp_password']          if integration['smtp_password']
      smtp_from                 integration['smtp_from']              if integration['smtp_from']
      smtp_receivers            integration['smtp_receivers']         if integration['smtp_receivers']
      smtp_subject              integration['smtp_subject']           if integration['smtp_subject']
      smtp_server               integration['smtp_server']            if integration['smtp_server']
      smtp_port                 integration['smtp_port']              if integration['smtp_port']
      smtp_skip_certificate_verify integration['smtp_skip_certificate_verify'] if integration.key?('smtp_skip_certificate_verify')
      smtp_start_tls            integration['smtp_start_tls']         if integration.key?('smtp_start_tls')
      smtp_auth_login           integration['smtp_auth_login']        if integration.key?('smtp_auth_login')
      # ServiceNow specific properties
      servicenow_instance_url   integration['servicenow_instance_url'] if integration['servicenow_instance_url']
      servicenow_username       integration['servicenow_username']    if integration['servicenow_username']
      servicenow_password       integration['servicenow_password']    if integration['servicenow_password']
      servicenow_client_id      integration['servicenow_client_id']   if integration['servicenow_client_id']
      servicenow_client_secret  integration['servicenow_client_secret'] if integration['servicenow_client_secret']
      # OpsGenie specific properties
      opsgenie_api_key          integration['opsgenie_api_key']       if integration['opsgenie_api_key']
      opsgenie_api_url          integration['opsgenie_api_url']       if integration['opsgenie_api_url']
      # General Webhook specific properties
      webhook_url               integration['webhook_url']            if integration['webhook_url']
      webhook_headers           integration['webhook_headers']        if integration['webhook_headers']
      action                    integration['action'] ? integration['action'].to_sym : :create
    end
  end
end
