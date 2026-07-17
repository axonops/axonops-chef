# BDD tracking spec for Amazon Linux install support (epic AD-29).
# metadata.rb already declared `supports 'amazon'`, but neither the online
# repo setup nor the offline install path handled it — this feature exists so
# that claim is backed by an executable spec, not just a metadata line.
#
# Verified by:
#   Integration | InSpec via Test Kitchen | test/integration/ | amazonlinux-2
#     and amazonlinux-2023 platforms added to kitchen.yml — the existing
#     cassandra-3-11/cassandra-default suites and controls run unchanged
#     against them (see features/README.md).
#
# All scenarios converge a node and assert on its resulting state; Test
# Kitchen destroys the container after each run, so no manual teardown is
# needed. Scenarios are independent and platform-parallel-safe.

Feature: Installing the AxonOps stack on Amazon Linux
  As an operator running Amazon Linux 2 or Amazon Linux 2023
  I want the axonops cookbook to configure the package repository and install packages
  So that I can run axonops::agent / axonops::cassandra on Amazon Linux like any other RHEL-family host

  Scenario Outline: The AxonOps yum repository is configured on Amazon Linux
    Given a node running "<platform>"
    When the axonops::repo recipe converges
    Then the "axonops" yum repository is created with baseurl "https://packages.axonops.com/yum/"

    Examples:
      | platform         |
      | amazonlinux-2     |
      | amazonlinux-2023   |

  Scenario: A fresh Apache Cassandra install converges on Amazon Linux
    Given a node converged with axonops::cassandra and version "5.0.5" on Amazon Linux
    Then Java 17 is installed and is the default java
    And the file "/opt/cassandra/conf/cassandra.yaml" exists and is valid YAML
    And the "cassandra" service is enabled and running

  Scenario: Offline agent install selects the rpm package path on Amazon Linux
    Given node['axonops']['offline_install'] is true
    And a node running "amazonlinux-2"
    When the agent recipe installs offline packages
    Then it installs axon-agent via rpm_package, not dpkg_package

  Scenario: An unsupported platform_family still logs a clear warning (edge case)
    Given a node running an unrecognised platform_family "suse"
    When the axonops::repo recipe converges
    Then no package repository is created
    And a warning is logged naming the unsupported platform_family
