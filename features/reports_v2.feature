# BDD tracking spec for Reports v2 (ASB-4652): axon-reporting replaces
# axon-dash-pdf / axon-dash-pdf2 and runs next to axon-dash.
#
# Verified by the pure-Ruby unit specs listed in features/README.md. There is
# no Kitchen coverage yet: the axon-reporting package is not published to the
# public repositories.

Feature: Reports v2 reporting service
  As an operator running a self-hosted AxonOps stack
  I want axon-reporting installed and wired to axon-dash and axon-server
  So that report generation works after the move away from axon-dash-pdf

  Scenario: The dashboard host runs axon-reporting by default
    Given a node converged with axonops::dashboard
    When node['axonops']['dashboard']['reporting']['enabled'] is true
    Then the axon-reporting package is installed
    And the axon-reporting service is enabled and started

  Scenario: axon-dash is told where the reporting service is
    Given node['axonops']['dashboard']['reporting']['url'] is "http://127.0.0.1:8081"
    Then axon-dash.yml has axon-dash.reporting_url "http://127.0.0.1:8081"

  Scenario: The reporting URL is independent of the local install
    Given node['axonops']['dashboard']['reporting']['enabled'] is false
    And node['axonops']['dashboard']['reporting']['url'] is "http://reports.internal:8081"
    Then axon-reporting is not installed
    And axon-dash.yml still has axon-dash.reporting_url "http://reports.internal:8081"

  Scenario: An empty reporting URL is left out
    Given node['axonops']['dashboard']['reporting']['url'] is ""
    Then axon-dash.yml has no reporting_url

  Scenario Outline: axon-server gets axon_reporting_url only when it understands it
    Given node['axonops']['server']['version'] is "<version>"
    Then axon-server.yml <result> axon_reporting_url
    And axon-server.yml never has the legacy axon_dash_url

    Examples:
      | version | result          |
      | latest  | has             |
      | 2.0.39  | has             |
      | 2.0.39-1 | has            |
      | 2.0.38  | does not have   |
      | 2.0.4   | does not have   |
      | garbage | does not have   |

  Scenario: An offline install without a staged package skips reporting
    Given node['axonops']['offline_install'] is true
    And node['axonops']['offline_packages']['reporting'] is nil
    Then axon-reporting is not installed
    And the run logs a warning that reports will not work
