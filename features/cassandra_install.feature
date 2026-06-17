# BDD tracking spec for a converged Cassandra node.
#
# Verified by the InSpec controls under test/integration/ run via Test Kitchen
# (see features/README.md). Scenarios tagged @wip track work that is specified
# but not yet implemented (package-repo install, PEM TLS) — see epic #19.

Feature: A converged Apache Cassandra node
  As an operator
  I want a Cassandra node that the axonops cookbook installed
  To be correctly laid out, owned and running
  So that the AxonOps agent can monitor it

  Scenario: Cassandra 3.11 tarball install on a fresh node
    Given a node converged with axonops::cassandra and version "3.11.17"
    Then Java 8 is installed and is the default java
    And the directory "/opt/cassandra" is a symlink to the versioned install
    And the file "/opt/cassandra/conf/cassandra.yaml" exists and is valid YAML
    And the file "/opt/cassandra/conf/jvm.options" exists
    And the "cassandra" user and group exist
    And the cassandra data directories are owned by "cassandra:cassandra"
    And the "cassandra" service is enabled and running

  Scenario: Cassandra 5.0 tarball install on a fresh node
    Given a node converged with axonops::cassandra and version "5.0.5"
    Then Java 17 is installed and is the default java
    And the file "/opt/cassandra/conf/cassandra.yaml" exists and is valid YAML
    And the file "/opt/cassandra/conf/jvm-server.options" exists
    And the file "/opt/cassandra/conf/jvm17-server.options" exists
    And the "cassandra" service is enabled and running

  @wip
  Scenario: Package-repo install from the Apache Cassandra apt/yum repos
    Given node['axonops']['cassandra']['install_format'] is "pkg"
    And node['axonops']['cassandra']['version'] is "4.1.5"
    When the node converges
    Then the Apache Cassandra apt or yum repository is configured
    And the cassandra package is installed and held at the pinned version

  @wip
  Scenario: PEM-based internode TLS on Cassandra 4.1+
    Given node['axonops']['cassandra']['version'] is "5.0.5"
    And PEM internode encryption is configured
    When the node converges
    Then cassandra.yaml configures the PEMBasedSslContextFactory
