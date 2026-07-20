#
# Cookbook:: axonops
# Recipe:: elastic
#
# Backwards-compatible wrapper — kept so existing run_lists referencing
# recipe[axonops::elastic] keep working after the switch from Elasticsearch
# to OpenSearch. See recipes/opensearch.rb / docs/OPENSEARCH.md.
#

include_recipe 'axonops::opensearch'
