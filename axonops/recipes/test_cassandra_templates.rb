#
# Cookbook:: axonops
# Recipe:: test_cassandra_templates
#
# Test recipe to verify Cassandra 5.0.4 templates work correctly
#

# Install Java first
include_recipe 'axonops::java'

# Install Cassandra
include_recipe 'axonops::install_cassandra_tarball'

# Configure Cassandra using templates
include_recipe 'axonops::configure_cassandra'

# Start Cassandra (use cassandra_app recipe which handles service management)
include_recipe 'axonops::cassandra_app'

# Log completion
Chef::Log.info <<-EOH

Cassandra Template Test Complete
================================

Cassandra should be installed and configured using the new templates:
- cassandra.yaml from cassandra.yaml.erb
- cassandra-env.sh from cassandra-env.sh.erb  
- jvm-server.options from jvm-server.options.erb
- jvm17-server.options from jvm17-server.options.erb

Check configuration files in: #{node['axonops']['cassandra']['config_dir']}
Check logs in: #{node['axonops']['cassandra']['log_dir']}

EOH