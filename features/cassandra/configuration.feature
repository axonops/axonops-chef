Feature: Cassandra configuration
  Scenario: 3.11 cassandra.yaml uses legacy integer keys
    Given I have a Cassandra 3.11 node with read_request_timeout set to "5000ms"
    When I converge the axonops::cassandra recipe
    Then "cassandra.yaml" contains "read_request_timeout_in_ms: 5000"
    And "cassandra.yaml" does not contain "read_request_timeout: 5000ms"

  Scenario: 5.0 cassandra.yaml uses modern duration string keys
    Given I have a Cassandra 5.0 node with read_request_timeout set to "5000ms"
    When I converge the axonops::cassandra recipe
    Then "cassandra.yaml" contains "read_request_timeout: 5000ms"
    And "cassandra.yaml" does not contain "read_request_timeout_in_ms"

  Scenario: 3.11 cassandra.yaml includes Thrift RPC keys
    Given I have a Cassandra 3.11 node
    When I converge the axonops::cassandra recipe
    Then "cassandra.yaml" contains "start_rpc:"
    And "cassandra.yaml" contains "rpc_port:"
