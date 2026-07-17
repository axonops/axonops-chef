Feature: Cassandra installation
  Scenario: Tarball install of Cassandra 3.11 with Java 8
    Given I have a node with attribute cassandra.version set to "3.11.17"
    And the install_format is "tar"
    When I converge the axonops::cassandra recipe
    Then the Cassandra binary exists at "/opt/cassandra/bin/cassandra"
    And Java 8 is installed
    And the file "/opt/cassandra/conf/jvm.options" exists
    And the file "/opt/cassandra/conf/jvm-server.options" does not exist

  Scenario: Package install of Cassandra 5.0 on Debian
    Given I have a node with attribute cassandra.version set to "5.0.5"
    And the install_format is "pkg"
    When I converge the axonops::cassandra recipe
    Then the apt sources file "/etc/apt/sources.list.d/cassandra.list" exists
    And the cassandra package is installed and held
