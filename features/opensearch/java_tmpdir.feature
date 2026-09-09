Feature: OpenSearch java.io.tmpdir on a noexec /tmp
  # Issue #46. On a CIS-hardened host (Amazon Linux 2023 and others) /tmp is
  # mounted noexec, so the JVM cannot execute the native libraries it unpacks
  # into java.io.tmpdir and OpenSearch never starts. The cookbook points
  # java.io.tmpdir (and OPENSEARCH_TMPDIR) at a directory it owns off /tmp.

  Scenario: default configures an executable temporary directory
    Given the default axonops::opensearch attributes
    Then "java_tmp_dir" defaults to "/var/lib/opensearch/tmp"

  Scenario: a jvm.options.d drop-in pins java.io.tmpdir
    Given "java_tmp_dir" is set to "/var/lib/opensearch/tmp"
    When I converge the axonops::opensearch recipe
    Then "/etc/opensearch/jvm.options.d/tmpdir.options" contains "-Djava.io.tmpdir=/var/lib/opensearch/tmp"
    And the temporary directory exists, owned by "opensearch:opensearch", mode "0750"
    And a systemd drop-in sets "Environment=OPENSEARCH_TMPDIR=/var/lib/opensearch/tmp"

  Scenario: setting the attribute to /tmp restores the previous behaviour
    Given "java_tmp_dir" is set to "/tmp"
    When I converge the axonops::opensearch recipe
    Then no temporary directory is created
    And "/etc/opensearch/jvm.options.d/tmpdir.options" does not exist

  Scenario: setting the attribute empty restores the previous behaviour
    Given "java_tmp_dir" is set to ""
    When I converge the axonops::opensearch recipe
    Then no temporary directory is created
    And "/etc/opensearch/jvm.options.d/tmpdir.options" does not exist

  Scenario: changing the attribute restarts OpenSearch
    Given OpenSearch is running with the drop-in already rendered
    When "java_tmp_dir" changes and I converge the axonops::opensearch recipe
    Then the tmpdir.options drop-in notifies "service[opensearch]" to restart
