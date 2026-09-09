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

  Scenario: Temporary directories stay on /tmp by default
    Given I have a Cassandra 5.0 node with default attributes
    When I converge the axonops::cassandra recipe
    Then "cassandra-env.sh" does not contain "java.io.tmpdir"
    And "cassandra-env.sh" does not contain "jna.tmpdir"
    And "cassandra-env.sh" does not contain "TMPDIR"

  Scenario: Temporary directories moved off a noexec /tmp
    Given I have a Cassandra 5.0 node with java_tmp_dir and jna_tmp_dir set to "/var/lib/cassandra/tmp"
    When I converge the axonops::cassandra recipe
    Then "cassandra-env.sh" contains "export TMPDIR=\"/var/lib/cassandra/tmp\""
    And "cassandra-env.sh" contains "-Djava.io.tmpdir=/var/lib/cassandra/tmp"
    And "cassandra-env.sh" contains "-Djna.tmpdir=/var/lib/cassandra/tmp"
    And "cassandra-env.sh" contains "-Dio.netty.native.workdir=/var/lib/cassandra/tmp"
    And directory "/var/lib/cassandra/tmp" is owned by "cassandra" with mode "1777"
