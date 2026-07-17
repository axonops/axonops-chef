Feature: Cassandra TLS encryption
  Scenario: JKS-based internode encryption (default)
    Given I have a Cassandra 5.0 node with JKS TLS configured
    When I converge the axonops::cassandra recipe
    Then "cassandra.yaml" server_encryption_options contains "keystore:"
    And "cassandra.yaml" does not contain "PEMBasedSslContextFactory"

  Scenario: PEM-based internode encryption on 4.1
    Given I have a Cassandra 4.1 node with PEM TLS configured
    When I converge the axonops::cassandra recipe
    Then "cassandra.yaml" contains "PEMBasedSslContextFactory"
    And "cassandra.yaml" server_encryption_options does not contain "keystore:"

  Scenario: PEM TLS rejected for Cassandra 3.11
    Given I have a Cassandra 3.11 node with PEM TLS configured
    When I converge the axonops::cassandra recipe
    Then the Chef run fails with "PEM-based TLS requires Cassandra 4.1 or later"
