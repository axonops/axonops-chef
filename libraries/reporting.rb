#
# Cookbook:: axonops
# Library:: reporting
#
# Reports v2 helpers (ASB-4652). Reports v2 replaces axon-dash-pdf /
# axon-dash-pdf2 with the axon-reporting package, which runs next to
# axon-dash. axon-server reaches it through axon_reporting_url, a key that
# only axon-server 2.0.39 and newer understand.
#
# Pure Ruby (no Chef dependency) so it can be unit tested with plain rspec.
#
module AxonOpsReporting
  # First axon-server release that reads axon_reporting_url.
  MIN_SERVER_VERSION = '2.0.39'.freeze

  # True when axon-server at +version+ takes axon_reporting_url. 'latest', nil
  # and '' are treated as the newest release, matching how recipes/server.rb
  # handles the search_db format switch. A Debian-style "2.0.39-1" revision is
  # ignored. An unparseable version returns false so nothing unknown is
  # written to axon-server.yml.
  def self.server_supports_reporting_url?(version)
    value = version.to_s.strip
    return true if value.empty? || value == 'latest'

    Gem::Version.new(value.split('-').first) >= Gem::Version.new(MIN_SERVER_VERSION)
  rescue ArgumentError
    false
  end

  # Version string for the package resource, or nil to install the newest
  # available package.
  def self.package_version(version)
    value = version.to_s.strip
    value.empty? || value == 'latest' ? nil : value
  end
end
