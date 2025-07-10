#
# Cookbook:: axonops
# Recipe:: server_test
#
# Test recipe for AxonOps server with Elasticsearch and Cassandra
#

# Include prerequisites
include_recipe 'axonops::default'

# For testing, use minimal server recipe
include_recipe 'axonops::server_minimal'

# Log completion
log 'axonops-server-test-info' do
  message 'AxonOps server test recipe completed'
  level :info
end