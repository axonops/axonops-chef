#
# Cookbook:: axonops
# Library:: agent_env
#
# Decides how the AxonOps java agent is wired into an existing
# cassandra-env.sh (or kafka-server-start.sh) that this cookbook does not
# render itself — see the 'configure-jvm-agent' ruby_block in recipes/agent.rb.
#
# Since agent 1.1.0 every Cassandra agent package (3.11, 4.0, 4.1, 5.0) ships
# /usr/share/axonops/axonops-jvm.options. Sourcing that file is the supported
# way to load the agent: its contents can change with the agent without the
# env file changing. Older agents only support the raw -javaagent flag.
#
# The env file is edited in place and survives across converges, so the rules
# here exist mainly to make sure an existing install never ends up with both
# the legacy -javaagent line and the options-file line, which would load the
# agent twice.
#
module AxonOpsAgentEnv
  OPTIONS_FILE = '/usr/share/axonops/axonops-jvm.options'.freeze
  # Existence-guarded, so an env file this cookbook edits in place never tries
  # to source a file an older (or not yet installed) agent package does not
  # ship — the cookbook's own cassandra-env.sh.erb carries the same guard.
  SOURCE_LINE = "[ -f #{OPTIONS_FILE} ] && . #{OPTIONS_FILE}".freeze
  DISABLED_LEGACY_LINE = "# AxonOps agent now loaded from #{OPTIONS_FILE}".freeze
  LEGACY_PATTERN = %r{^[^#\n]*-javaagent:/usr/share/axonops/[^\s"']+\.jar}.freeze

  # Matches any uncommented line that loads the options file, however it was
  # written: `. <file>`, `source <file>`, or the guarded form above.
  SOURCE_PATTERN = %r{^[^#\n]*/usr/share/axonops/axonops-jvm\.options}.freeze

  module_function

  # The legacy line that loads the agent jar directly.
  def legacy_line(package)
    "JVM_OPTS=\"$JVM_OPTS -javaagent:/usr/share/axonops/#{package}.jar=/etc/axonops/axon-agent.yml\""
  end

  # Matches any uncommented legacy -javaagent line pointing at an AxonOps
  # agent jar, whatever the package name — an install may have been set up by
  # an older cookbook release, or with a different agent build, and we still
  # must not add a second way of loading the agent next to it.
  def legacy_pattern
    LEGACY_PATTERN
  end

  # Matches a legacy -javaagent line for one specific package.
  def legacy_pattern_for(package)
    %r{^[^#\n]*-javaagent:/usr/share/axonops/#{Regexp.escape(package)}\.jar}
  end

  # Work out the single edit to apply to `content`.
  #
  # options_file_present – whether OPTIONS_FILE exists on the node.
  # package              – agent package name, for the legacy fallback line.
  # prefer_options_file  – false for DSE, whose agent packages do not ship
  #                        the options file at all.
  #
  # Returns one of:
  #   [:none]                    – already wired in, leave the file alone
  #   [:insert, line]            – append `line`
  #   [:replace, regex, line]    – rewrite the matching legacy line as `line`
  def edit_for(content, options_file_present:, package:, prefer_options_file: true)
    has_source = content.match?(SOURCE_PATTERN)
    has_legacy = content.match?(legacy_pattern)

    if prefer_options_file && options_file_present
      return [:none] if has_source && !has_legacy
      # Migrate the legacy line in place: replacing rather than appending is
      # what keeps both lines from coexisting.
      return [:replace, legacy_pattern, SOURCE_LINE] if has_legacy && !has_source
      # Both present (hand-edited file, or an interrupted earlier migration):
      # drop the legacy line, keep the source line.
      return [:replace, legacy_pattern, DISABLED_LEGACY_LINE] if has_legacy && has_source

      [:insert, SOURCE_LINE]
    else
      # No options file: the raw -javaagent line is the only way in. An agent
      # package upgrade renames the jar (axon-dse6.8-agent ->
      # axon-dse6.9-agent), and the old jar goes away with the old package, so
      # a stale line must be rewritten rather than left pointing at a jar that
      # no longer exists.
      return [:replace, legacy_pattern, legacy_line(package)] if has_legacy && !content.match?(legacy_pattern_for(package))
      return [:none] if has_legacy || has_source

      [:insert, legacy_line(package)]
    end
  end
end
