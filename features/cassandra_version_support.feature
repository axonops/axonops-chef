# BDD tracking spec for multi-version Cassandra support.
#
# These scenarios are the living specification for GitHub epic #19
# (Cassandra parity with the Ansible role + 3.11 support). Each scenario maps
# to executable checks; see features/README.md for the mapping to ChefSpec
# unit specs and InSpec integration controls run under Test Kitchen.

Feature: Version-aware Apache Cassandra installation
  As an operator using the axonops cookbook
  I want the cookbook to install the correct Java and configuration schema
  for the Cassandra version I select
  So that 3.11, 4.1 and 5.0 clusters all converge correctly

  Background:
    Given the axonops::cassandra recipe is in the run list

  Scenario Outline: The Java major version follows the Cassandra version
    Given node['axonops']['cassandra']['version'] is "<version>"
    When the java recipe resolves the Java version
    Then it installs Java major version <java>

    Examples:
      | version | java |
      | 3.11.17 | 8    |
      | 4.1.5   | 11   |
      | 5.0.5   | 17   |

  Scenario Outline: The cassandra.yaml schema follows the Cassandra version
    Given node['axonops']['cassandra']['version'] is "<version>"
    When configure_cassandra renders cassandra.yaml
    Then it uses the "<schema>" template

    Examples:
      | version | schema           |
      | 3.11.17 | 3.11 legacy      |
      | 4.1.5   | modern           |
      | 5.0.5   | modern           |

  Scenario: Cassandra 3.11 renders the legacy integer-unit schema
    Given node['axonops']['cassandra']['version'] is "3.11.17"
    When configure_cassandra renders cassandra.yaml
    Then the file contains "read_request_timeout_in_ms: 5000"
    And the file contains "commitlog_segment_size_in_mb: 32"
    And the file contains "start_rpc: false"
    And the file does not contain "selected_format"
    And the file does not contain "allocate_tokens_for_local_replication_factor"

  Scenario: Cassandra 4.1 renders the per-version JVM option files
    Given node['axonops']['cassandra']['version'] is "4.1.5"
    When configure_cassandra renders the JVM options
    Then the file "jvm-server.options" exists
    And the file "jvm11-server.options" exists

  Scenario: Cassandra 5.0 renders the Java 17 JVM option files
    Given node['axonops']['cassandra']['version'] is "5.0.5"
    When configure_cassandra renders the JVM options
    Then the file "jvm-server.options" exists
    And the file "jvm17-server.options" exists

  Scenario: An unsupported version fails fast
    Given node['axonops']['cassandra']['version'] is "2.2.0"
    When the cookbook resolves the Cassandra series
    Then the chef run raises an ArgumentError
