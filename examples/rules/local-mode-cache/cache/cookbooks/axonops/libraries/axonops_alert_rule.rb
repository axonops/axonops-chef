require_relative 'axonops_api'
require_relative 'axonops_utils'

class Chef
  class Resource::AxonopsAlertRule < Chef::Resource
    resource_name :axonops_alert_rule
    provides :axonops_alert_rule

    property :name, String, name_property: true
    property :description, String, default: ''
    property :dashboard, String, required: true
    property :org, String, required: true
    property :cluster, String, required: true
    property :chart, String, required: true
    property :metric, String, default: ''
    property :operator, String, equal_to: ['=', '>=', '>', '<=', '<', '!=']
    property :warning_value, Number, default: 80
    property :critical_value, Number, default: 90
    property :duration, String
    property :url_filter, String, default: ''
    property :scope, Array, default: []
    property :dc, Array, default: []
    property :rack, Array, default: []
    property :host_id, Array, default: []
    property :group_by, Array, default: [], 
             equal_to: ['dc', 'host_id', 'rack', 'scope', []]
    property :routing, Hash, default: {}
    property :present, [true, false], default: true
    property :percentile, Array, default: [],
             equal_to: [[], '', '75thPercentile', '95thPercentile', '98thPercentile', 
                       '99thPercentile', '999thPercentile']
    property :consistency, Array, default: [],
             equal_to: [[], '', 'ALL', 'ANY', 'ONE', 'TWO', 'THREE', 'SERIAL', 
                       'QUORUM', 'EACH_QUORUM', 'LOCAL_ONE', 'LOCAL_QUORUM', 'LOCAL_SERIAL']
    property :keyspace, Array, default: []
    property :username, String, default: ''
    property :password, String, default: ''
    property :cluster_type, String, default: 'cassandra',
             equal_to: ['cassandra', 'kafka']

    # Add action definitions as needed
    default_action :create

    action :create do
      org = new_resource.org
      cluster = new_resource.cluster
      cluster_type = new_resource.cluster_type
      alerts_url = f"/api/v1/alert-rules/#{org}/#{cluster_type}/#{cluster}"
      current = AxonApi.do_request(alerts_url)
      puts current.inspect
    end

    action :delete do
      # Implementation logic here
    end
  end
end