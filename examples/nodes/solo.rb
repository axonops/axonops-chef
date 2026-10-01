# chef-solo configuration for the example node files in this directory.
#
# chef-solo needs the axonops cookbook and its dependencies (apt, yum) in one
# directory. Build it with `berks vendor` (see docs/CHEF_SOLO_QUICKSTART.md):
#
#   berks vendor /opt/chef/cookbooks
#   sudo chef-solo -c examples/nodes/solo.rb -j examples/nodes/axon-server-ldap-node.json
#
# Set AXONOPS_COOKBOOK_PATH to use a different cookbook directory.

file_cache_path '/var/chef/cache'
cookbook_path   [ENV.fetch('AXONOPS_COOKBOOK_PATH', '/opt/chef/cookbooks')]
# Ohai's Passwd plugin is slow on hosts with large directories (LDAP/SSSD)
# and none of the recipes need it.
ohai.disabled_plugins = [:Passwd]
