# Chef configuration file
# Save this as /etc/chef/solo.rb

# Where to find cookbooks
cookbook_path "/etc/chef/cookbooks"

# Where to find configuration
json_attribs "/etc/chef/node.json"

# Logging
log_level :info
log_location STDOUT

# Where to store Chef state
file_cache_path "/var/chef/cache"
file_backup_path "/var/chef/backup"