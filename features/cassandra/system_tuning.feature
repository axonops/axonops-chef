Feature: Cassandra system tuning
  Scenario: sysctl settings applied on non-container host
    Given I have a non-container node
    When I converge the axonops::cassandra recipe
    Then "/etc/sysctl.d/99-cassandra.conf" contains "vm.swappiness = 1"
    And "/etc/security/limits.d/cassandra.conf" contains "nofile" with value >= 1000000

  Scenario: sysctl skipped in Docker container
    Given I have a node with "/.dockerenv" present
    When I converge the axonops::cassandra recipe
    Then no sysctl resource is applied
