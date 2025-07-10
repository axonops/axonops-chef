#
# Cookbook:: axonops
# Recipe:: cassandra_test
#
# Test recipe for Cassandra installation
#

# Include prerequisites
include_recipe 'axonops::default'

# Install minimal Cassandra for testing
include_recipe 'axonops::cassandra_minimal'

# Log completion
log 'cassandra-test-info' do
  message 'Cassandra test recipe completed'
  level :info
end