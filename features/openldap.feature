# BDD tracking spec for axonops::openldap, the local OpenLDAP directory for
# axon-server LDAP authentication. Verified by the unit specs and Kitchen
# suites listed in features/README.md.

Feature: Local OpenLDAP directory for AxonOps Server
  As an operator testing AxonOps LDAP login and RBAC
  I want a local directory seeded with users and groups mapped to AxonOps roles
  So that I do not need a corporate directory

  Background:
    Given the admin password is set in node.run_state['axonops_openldap_admin_password']

  Scenario: A fresh host gets a seeded directory
    Given a clean Ubuntu 22.04 or Rocky Linux 9 host
    When axonops::openldap converges with user "alice" in group "axonops_admin"
    Then slapd is enabled and running on port 389
    And "alice" binds with the configured password
    And "alice" has memberOf "cn=axonops_admin,ou=Groups,dc=axonops,dc=local"
    And an empty group holds the admin DN
    And the bootstrap LDIF is removed

  Scenario: A second converge changes nothing
    Given axonops::openldap has converged once
    When it converges again with the same attributes
    Then no resource is updated

  Scenario: Anonymous clients cannot read the directory
    Then an anonymous search under ou=People returns no entries
    And an anonymous read of the root DSE returns the naming context

  Scenario: A wrong admin password is rejected
    Then a bind as the admin DN with a wrong password fails with "Invalid credentials" (49)

  Scenario: Self-signed TLS with LDAPS
    Given tls_mode is "generate" and listen_ldaps is true
    Then slapd serves LDAPS on 636 and StartTLS on 389
    And server.key is mode 0640
    And the published axon-server setting uses port 636 with useSSL true and insecureSkipVerify true

  Scenario Outline: Invalid settings fail before any change
    Given <setting>
    Then the Chef run fails at compile time with "<message>"
    And the message contains no password

    Examples:
      | setting                                   | message                                  |
      | no admin password                         | admin password is not set                |
      | base_dn "o=axonops"                       | must start with a dc= component          |
      | tls_mode "custom" without tls_cert        | custom needs tls_cert and tls_key        |
      | listen_ldaps true with tls_mode disabled  | listen_ldaps needs tls_mode              |
      | a group with axon_role "godRole"          | axon_role 'godRole'                      |
      | two users with the same uid               | uids must be unique                      |
      | a user in an undeclared group             | not listed in groups                     |

  Scenario: The directory already holds someone else's data
    Given data.mdb exists with entries and no role-managed {1}mdb config
    Then the Chef run fails without changing the directory

  Scenario: axon-server is wired to the directory in the same run
    Given configure_server is true
    When axonops::openldap and axonops::server converge
    Then axon-server.yml has auth.enabled true, type LDAP and a rolesMapping per axon_role group
    And bindPassword comes from node.run_state, not a node attribute
