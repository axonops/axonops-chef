Feature: OpenSearch snapshot repositories on S3 and GCS
  # axonops::opensearch can back up the AxonOps OpenSearch to an S3 bucket
  # (AWS or any S3-compatible store) or a GCS bucket. Credentials only ever
  # go into opensearch.keystore; the client settings go into opensearch.yml.

  Scenario: snapshots are off by default
    Given the default axonops::opensearch attributes
    When I converge the axonops::opensearch recipe
    Then no repository plugin is installed
    And opensearch.yml has no "s3.client." or "gcs.client." settings

  Scenario: S3 with static credentials
    Given snapshots are enabled with type "s3", a bucket and an access key pair
    When I converge the axonops::opensearch recipe
    Then the "repository-s3" plugin is installed
    And the keystore holds "s3.client.default.access_key" and "s3.client.default.secret_key"
    And opensearch.yml holds the region, endpoint, protocol and path_style_access settings
    And neither key appears in opensearch.yml

  Scenario: GCS with a service-account JSON
    Given snapshots are enabled with type "gcs", a bucket and a credentials JSON
    When I converge the axonops::opensearch recipe
    Then the "repository-gcs" plugin is installed
    And the keystore holds "gcs.client.default.credentials_file"
    And no temporary credentials file is left in /etc/opensearch

  Scenario: no static credentials uses the instance identity
    Given snapshots are enabled with no access key pair
    When I converge the axonops::opensearch recipe
    Then the keystore holds no snapshot client credentials
    And credentials stored by an earlier run for the client are removed

  Scenario: a second converge changes nothing
    Given a node converged with S3 snapshots enabled
    When I converge the axonops::opensearch recipe again
    Then the keystore is not rewritten
    And OpenSearch is not restarted

  Scenario Outline: invalid settings fail before anything is changed
    Given snapshots are enabled with <setting>
    When I converge the axonops::opensearch recipe
    Then the run fails with "Invalid OpenSearch snapshot settings"

    Examples:
      | setting                                   |
      | type "azure"                              |
      | an empty bucket                           |
      | an access key without a secret key        |
      | a session token without an access key     |
      | protocol "ftp"                            |
      | a credential key in s3.extra_settings     |
      | a policy without a name                   |

  Scenario: the repository and policy are registered once
    Given snapshots are enabled with a policy named "daily"
    When I converge the axonops::opensearch recipe
    Then the repository "s3-snapshots" is registered
    And the policy "daily" uses the repository "s3-snapshots"
    When I converge the axonops::opensearch recipe again
    Then neither the repository nor the policy is updated
