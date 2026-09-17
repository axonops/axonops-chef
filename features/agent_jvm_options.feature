# BDD tracking spec for how the AxonOps java agent is loaded (ASB-4712).
#
# Verified by the pure-Ruby unit specs listed in features/README.md. There is
# no Kitchen coverage: the agent packages need an AxonOps API key, so no
# integration suite installs them.

Feature: Loading the AxonOps java agent from axonops-jvm.options
  As an operator
  I want Cassandra to load the agent through /usr/share/axonops/axonops-jvm.options
  So that AxonOps can change how the agent is loaded without a cookbook change

  Scenario Outline: A cookbook-managed node sources the options file
    Given a node converged with axonops::cassandra and version "<version>"
    And the AxonOps agent is enabled
    Then cassandra-env.sh sources "/usr/share/axonops/axonops-jvm.options" when that file exists
    And cassandra-env.sh adds "-javaagent:/usr/share/axonops/<jar>.jar" only when that file is absent
    And cassandra-env.sh never applies both

    Examples:
      | version | jar                          |
      | 3.11.17 | axon-cassandra3.11-agent     |
      | 4.0.13  | axon-cassandra4.0-agent      |
      | 4.1.5   | axon-cassandra4.1-agent      |
      | 5.0.9   | axon-cassandra5.0-agent-jdk17 |

  Scenario: A cookbook-managed node is wired in by the template only
    Given a node converged with axonops::cassandra
    Then axonops::agent does not edit cassandra-env.sh in place
    And no repeated converge notifies an extra Cassandra restart

  Scenario: A cookbook-external Cassandra gets the options file line added
    Given an existing cassandra-env.sh this cookbook does not render
    And the agent package ships /usr/share/axonops/axonops-jvm.options
    When axonops::agent converges
    Then "[ -f /usr/share/axonops/axonops-jvm.options ] && . /usr/share/axonops/axonops-jvm.options" is appended to cassandra-env.sh
    And a second converge appends nothing further

  Scenario: An existing install using the old -javaagent line is migrated
    Given an existing cassandra-env.sh carrying a "-javaagent:/usr/share/axonops/...jar" line
    And the agent package ships /usr/share/axonops/axonops-jvm.options
    When axonops::agent converges
    Then the old -javaagent line is replaced by the guarded options-file line
    And cassandra-env.sh carries exactly one way of loading the agent

  Scenario: An agent older than 1.1.0 keeps the old method
    Given an existing cassandra-env.sh this cookbook does not render
    And /usr/share/axonops/axonops-jvm.options does not exist
    When axonops::agent converges
    Then the "-javaagent" line is appended to cassandra-env.sh
    And a second converge adds no further line

  Scenario: An agent upgrade renames the jar and no options file is shipped
    Given an existing cassandra-env.sh carrying a "-javaagent" line for an older agent package
    And /usr/share/axonops/axonops-jvm.options does not exist
    When axonops::agent converges with a newer agent package
    Then the line is rewritten to name the newly installed jar
    And cassandra-env.sh carries exactly one -javaagent line

  Scenario: DSE keeps the -javaagent line
    Given node['axonops']['cassandra']['edition'] is "dse"
    When axonops::agent converges
    Then the DSE cassandra-env.sh gets a "-javaagent:/usr/share/axonops/axon-dse<version>-agent.jar" line
    And no axonops-jvm.options line is added
    And a DSE agent upgrade rewrites that line to the new jar rather than adding a second one
