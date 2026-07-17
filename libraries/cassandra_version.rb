#
# Cookbook:: axonops
# Library:: cassandra_version
#
# Version-aware helpers for the Cassandra recipes. Maps a Cassandra version to
# its supported Java major, configuration-template subdirectory, and provides
# the unit-conversion helpers required to render the legacy Cassandra 3.11
# `cassandra.yaml` schema from the modern (string-unit) attribute values used
# by the 4.1/5.0 templates.
#
# Mirrors the behaviour of the AxonOps Ansible role
# (roles/cassandra/vars/cassandra-3.11.yml) so a single set of attributes can
# drive every supported version.
#

# Top-level module (the cookbook already defines `class AxonOps` in
# libraries/axonops.rb, so this uses the AxonOpsUtils/AxonOpsMixin convention to
# avoid a class/module collision at load time).
module AxonOpsCassandra
  # Supported Cassandra release series, in match order. The series string is
  # also the name of the template subdirectory under templates/default/.
  # '5.1' is DataStax Enterprise (DSE) 5.1, monitored (not installed) by this
  # cookbook — see recipes/agent.rb and docs/DSE.md.
  SUPPORTED_SERIES = %w(3.11 4.1 5.0 5.1).freeze

  # Java major version required by each Cassandra series.
  JAVA_MAJOR = {
    '3.11' => 8,
    '4.1' => 11,
    '5.0' => 17,
    '5.1' => 8, # DSE 5.1 runs on Java 8, same as Apache Cassandra 3.11.
  }.freeze

  # AxonOps Cassandra java-agent RPM/deb package name for each series. DSE
  # 5.1 isn't listed — recipes/agent.rb selects node['axonops']['java_agent']
  # ['dse'] for that edition instead of calling java_agent_package.
  JAVA_AGENT_PACKAGE = {
    '3.11' => 'axon-cassandra3.11-agent',
    '4.1' => 'axon-cassandra4.1-agent',
    '5.0' => 'axon-cassandra5.0-agent-jdk17',
  }.freeze

  # Duration unit -> milliseconds.
  MS_PER_UNIT = {
    'ms' => 1,
    's' => 1_000,
    'm' => 60_000,
    'h' => 3_600_000,
    'd' => 86_400_000,
  }.freeze

  # Duration unit -> seconds.
  SECS_PER_UNIT = {
    'ms' => 0.001,
    's' => 1,
    'm' => 60,
    'h' => 3_600,
    'd' => 86_400,
  }.freeze

  module_function

  # Normalise a full version (e.g. "3.11.17", "4.1.5", "5.0.5") to its
  # supported series ("3.11", "4.1", "5.0"). Raises on unsupported versions.
  def series(version)
    v = version.to_s
    return '3.11' if v.start_with?('3.11')
    return '4.1'  if v.start_with?('4.1')
    # DSE 5.1 must be checked before the '5.' (Apache Cassandra 5.0) match
    # below, otherwise a DSE version string like '5.1.17' is misclassified as
    # Apache Cassandra 5.0.
    return '5.1'  if v.start_with?('5.1')
    return '5.0'  if v.start_with?('5.')

    raise Chef::Exceptions::UnsupportedAction,
          "cassandra: unsupported version '#{version}' — supported prefixes: #{SUPPORTED_SERIES.join(', ')}."
  end

  # True when the version uses the legacy 3.11 cassandra.yaml schema
  # (integer *_in_ms / *_in_mb / *_in_kb keys, Thrift/RPC keys, megabit
  # streaming throughput).
  def legacy_schema?(version)
    series(version) == '3.11'
  end

  # Java major version (8, 11 or 17) required by the given Cassandra version.
  def java_major(version)
    JAVA_MAJOR.fetch(series(version))
  end

  # Template subdirectory (relative to templates/default/) holding the
  # version-specific ERB files for this version.
  def template_dir(version)
    series(version)
  end

  # AxonOps java-agent package name matching the given Cassandra version.
  def java_agent_package(version)
    JAVA_AGENT_PACKAGE.fetch(series(version))
  end

  # Parse a "<number><unit>" duration string ("2000ms", "3h", "30m") into an
  # integer number of milliseconds. Bare numbers are treated as milliseconds.
  def to_ms(value)
    num, unit = split_unit(value)
    (num * MS_PER_UNIT.fetch(unit.empty? ? 'ms' : unit)).round
  end

  # Parse a duration string into an integer number of seconds ("14400s",
  # "4h", "0s"). Bare numbers are treated as seconds.
  def to_secs(value)
    num, unit = split_unit(value)
    (num * SECS_PER_UNIT.fetch(unit.empty? ? 's' : unit)).round
  end

  # Parse a size string ("1024KiB", "640KiB", "64KiB") into an integer number
  # of kibibytes. Accepts KiB/MiB/GiB (and the SI-style KB/MB/GB aliases).
  def to_kib(value)
    bytes(value) / 1024
  end

  # Parse a size string ("128MiB", "32MiB", "512MiB") into an integer number
  # of mebibytes.
  def to_mib(value)
    bytes(value) / (1024 * 1024)
  end

  # Convert a "<n>MiB/s" throughput string to megabits per second, matching
  # the Ansible role's 8x factor (e.g. "24MiB/s" -> 192).
  def mib_per_s_to_megabits(value)
    num, = split_unit(value.to_s.sub(%r{/s\z}, ''))
    (num * 8).round
  end

  # True when a DataStax Enterprise (DSE) install is present on this node.
  # Used by recipes/agent.rb and recipes/cassandra.rb to auto-detect DSE 5.1
  # so the cookbook monitors it (via the agent) instead of trying to install
  # or manage it as Apache Cassandra.
  def dse_installed?
    ::File.exist?('/etc/dse/cassandra/cassandra.yaml') || ::Dir.glob('/opt/dse').any?
  end

  # --- internal helpers -------------------------------------------------

  # Returns [Float number, String unit]. Unit is downcased; "MiB"/"KiB" are
  # normalised to "mib"/"kib" so callers can match case-insensitively.
  def split_unit(value)
    s = value.to_s.strip
    m = s.match(%r{\A(-?\d+(?:\.\d+)?)\s*([A-Za-z/]*)\z})
    raise ArgumentError, "Cannot parse unit value '#{value}'" unless m

    [m[1].to_f, m[2].to_s.downcase]
  end

  # Parse a binary/decimal size string into bytes.
  def bytes(value)
    num, unit = split_unit(value)
    factor = case unit
             when '', 'b'                 then 1
             when 'kib', 'kb', 'k'        then 1024
             when 'mib', 'mb', 'm'        then 1024 * 1024
             when 'gib', 'gb', 'g'        then 1024 * 1024 * 1024
             else
               raise ArgumentError, "Unknown size unit in '#{value}'"
             end
    (num * factor).round
  end
end
