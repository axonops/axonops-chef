Feature: Cassandra system tuning
  Scenario: sysctl settings applied on non-container host
    Given I have a non-container node
    When I converge the axonops::cassandra recipe
    Then "/etc/sysctl.d/99-cassandra.conf" contains "vm.overcommit_memory=1"
    And "/etc/sysctl.d/99-cassandra.conf" does not contain "vm.swappiness"
    And "/etc/security/limits.d/cassandra.conf" contains "nofile" with value >= 1000000

  Scenario: transparent huge pages disabled on non-container host
    Given I have a non-container node
    When I converge the axonops::cassandra recipe
    Then "/sys/kernel/mm/transparent_hugepage/enabled" reports "[never]"
    And "/sys/kernel/mm/transparent_hugepage/defrag" reports "[never]"
    And the "disable-transparent-hugepages" systemd unit is enabled

  Scenario: swap disabled on non-container host
    Given I have a non-container node
    When I converge the axonops::cassandra recipe
    Then "swapon --show" reports no active swap devices
    And "/etc/fstab" has no active swap entry

  Scenario: second converge changes nothing
    Given I have a non-container node with THP already "never" and swap already off
    When I converge the axonops::cassandra recipe
    Then no transparent huge pages resource is applied
    And no swap resource is applied

  Scenario: operator keeps swap
    Given I have a non-container node with "disable_swap" set to false
    When I converge the axonops::cassandra recipe
    Then "/etc/sysctl.d/99-cassandra.conf" contains "vm.swappiness=1"
    And no swap resource is applied

  Scenario: Shenandoah JVM options carry no huge-page or fixed young-gen flags
    Given I have a node with "gc_type" set to "Shenandoah"
    When I render the Cassandra JVM server options for Java 11 and Java 17
    Then the rendered options contain "-XX:ShenandoahGCHeuristics=adaptive"
    And the rendered options do not contain "-XX:+UseTransparentHugePages"
    And the rendered options do not contain "-Xmn"

  Scenario: sysctl, THP and swap all skipped in Docker container
    Given I have a node with "/.dockerenv" present
    When I converge the axonops::cassandra recipe
    Then no sysctl resource is applied
    And no transparent huge pages resource is applied
    And no swap resource is applied
