# BDD tracking spec for DataStax Enterprise (DSE) 5.1 monitoring support
# (epic AD-29). This cookbook never installs or manages DSE — only Apache
# Cassandra — so every scenario here is about monitoring an already-running
# DSE install, never about converging one from scratch.
#
# Verified by ChefSpec (spec/unit/recipes/dse_detection_spec.rb) and the
# pure-Ruby version library spec (spec/unit/libraries/cassandra_version_spec.rb).
# No Kitchen/InSpec coverage: DataStax does not distribute a redistributable
# DSE Docker image suitable for public CI, so this feature is unit-tested only
# (see features/README.md).
#
# All scenarios are read-only (they assert on rendered config / resource
# selection) and persist no state, so no teardown is needed and they are
# parallel-safe.

Feature: DataStax Enterprise (DSE) 5.1 monitoring
  As an operator running DSE 5.1
  I want the AxonOps agent to auto-detect and monitor it
  So that I get DSE-specific metrics without the cookbook touching my DSE install

  Background:
    Given the axonops::agent recipe is in the run list

  Scenario: DSE is auto-detected from /opt/dse
    Given a DSE install exists at "/opt/dse"
    And node['axonops']['cassandra']['edition'] is not explicitly set
    When the agent recipe converges
    Then node['axonops']['cassandra']['edition'] resolves to "dse"

  Scenario: DSE is auto-detected from /etc/dse/cassandra/cassandra.yaml
    Given a DSE config file exists at "/etc/dse/cassandra/cassandra.yaml"
    And node['axonops']['cassandra']['edition'] is not explicitly set
    When the agent recipe converges
    Then node['axonops']['cassandra']['edition'] resolves to "dse"

  Scenario: A detected DSE install installs the DSE java agent package
    Given a DSE install is detected
    When the agent recipe selects the java agent package
    Then it installs "axon-dse-agent"
    And the rendered axon-agent.yml contains the "dse" metrics block
    And the rendered axon-agent.yml does not contain the "cassandra" metrics block

  Scenario: A plain Apache Cassandra install installs the Cassandra java agent package
    Given no DSE install is present
    And node['axonops']['cassandra']['edition'] is "apache"
    When the agent recipe selects the java agent package
    Then it installs the Apache Cassandra java agent package
    And the rendered axon-agent.yml contains the "cassandra" metrics block

  Scenario: axonops::cassandra never installs or reinstalls a detected DSE cluster
    Given a DSE install is detected
    When the axonops::cassandra recipe converges
    Then no Apache Cassandra tarball is downloaded or extracted
    And axonops::agent still runs to attach monitoring

  Scenario Outline: The Java major version required by each edition
    Given node['axonops']['cassandra']['version'] is "<version>"
    When the cookbook resolves the Cassandra series
    Then it requires Java major version <java>

    Examples:
      | version | java |
      | 5.0.5   | 17   |
      | 5.1.17  | 8    |

  Scenario: An unsupported version still fails fast (edge case, not confused with DSE)
    Given node['axonops']['cassandra']['version'] is "6.0.0"
    When the cookbook resolves the Cassandra series
    Then the chef run raises an ArgumentError
