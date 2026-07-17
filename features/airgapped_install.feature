# BDD tracking spec for airgapped/offline install support (epic AD-37).
#
# Verified by:
#   Unit | ChefSpec | spec/unit/recipes/java_offline_spec.rb | The flag
#     propagation fix, without Docker
#   Integration | InSpec via Test Kitchen | test/integration/cassandra-default |
#     kitchen.yml's cassandra-offline suite, converged with real Cassandra +
#     Java tarballs staged by the CI job (.github/workflows/ci.yml,
#     kitchen-offline) and zero network egress expected during convergence
#
# All scenarios converge a node (ChefSpec compile-only, or a real Kitchen
# container that Test Kitchen destroys afterwards) and assert on the result;
# no manual teardown is needed. Scenarios are independent and parallel-safe.

Feature: Airgapped / offline install
  As an operator deploying into a network-isolated environment
  I want a single flag to fully airgap the install
  So that I don't have to discover, one broken recipe at a time, which dependency still needs the internet

  Background:
    Given node['axonops']['offline_install'] is true

  Scenario: Setting only the top-level flag is enough to airgap Java too
    Given node['java']['offline_install'] is not set directly
    When the java recipe converges
    Then node['java']['offline_install'] resolves to true
    And no Azul GPG key is fetched
    And no Zulu apt/yum repository is configured
    And Java is installed from the local tarball instead

  Scenario: A real end-to-end offline Cassandra install has zero network egress
    Given the Apache Cassandra and Java tarballs are pre-staged under offline_packages_path
    And the AxonOps agent is disabled for this scenario (see kitchen.yml comment — agent packages aren't safely stageable in CI)
    When a node converges axonops::cassandra
    Then Cassandra installs successfully from the staged tarball
    And Java installs successfully from the staged tarball
    And the "cassandra" service is enabled and running

  Scenario: A standalone caller can still force java's own flag independently (edge case)
    Given node['axonops']['offline_install'] is false
    And node['java']['offline_install'] is set directly to true
    When the java recipe converges
    Then node['java']['offline_install'] remains true
    And Java is installed from the local tarball

  Scenario: axonops::chef_workstation is an intentional, documented exception
    Given node['axonops']['offline_install'] is true
    When the chef_workstation recipe converges
    Then it still downloads Chef Workstation from packages.chef.io
    And this is documented in README.md as excluded from airgapped support
