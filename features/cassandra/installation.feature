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

  Scenario: cqlsh works on hosts with Python 3.12 or newer
    Given I have a node with attribute cassandra.version set to "5.0.5"
    And the install_format is "tar"
    When I converge the axonops::cassandra recipe
    Then the cqlsh virtualenv binary exists at "/opt/cassandra-cqlsh-venv/bin/cqlsh"
    And the file "/usr/local/bin/cqlsh" is an executable wrapper
    And "command -v cqlsh" resolves to "/usr/local/bin/cqlsh"
    And "cqlsh --version" exits without an ImportError

  Scenario: cqlsh virtualenv can be disabled
    Given I have a node with attribute cassandra.cqlsh_venv.enabled set to "false"
    When I converge the axonops::cassandra recipe
    Then the recipe "axonops::cqlsh_venv" is not included

  Scenario: cqlsh virtualenv is skipped on airgapped hosts
    Given I have a node with attribute offline_install set to "true"
    When I converge the axonops::cqlsh_venv recipe
    Then a warning is logged that cqlsh_venv was skipped
    And the cqlsh virtualenv is not created
