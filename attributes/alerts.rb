# AxonOps Alert Rules Configuration
# Based on axonops-ansible-collection alert rules

default['axonops']['alert_rules'] = [
  # Overview Alerts
  {
    'name' => 'DOWN count per node',
    'dashboard' => 'Overview',
    'chart' => 'Number of Endpoints Down Per Node Point Of View',
    'operator' => '>=',
    'critical_value' => 2,
    'warning_value' => 1,
    'duration' => '15m',
    'description' => 'Detected DOWN nodes',
    'action' => 'create'
  },

  # System Alerts
  {
    'name' => 'CPU usage per host',
    'dashboard' => 'System',
    'chart' => 'CPU usage per host',
    'operator' => '>=',
    'critical_value' => 99,
    'warning_value' => 90,
    'duration' => '1h',
    'description' => 'Detected High CPU usage',
    'action' => 'create'
  },
  {
    'name' => 'CPU is Underutilized',
    'dashboard' => 'System',
    'chart' => 'CPU usage per host',
    'operator' => '<=',
    'critical_value' => 1,
    'warning_value' => 5,
    'duration' => '1w',
    'description' => 'CPU load has been very low for 1 week',
    'action' => 'create'
  },
  {
    'name' => 'Disk % Usage $mountpoint',
    'dashboard' => 'System',
    'chart' => 'Disk % Usage $mountpoint',
    'operator' => '>=',
    'critical_value' => 90,
    'warning_value' => 75,
    'duration' => '12h',
    'description' => 'Detected High disk utilization',
    'action' => 'create'
  },
  {
    'name' => 'Avg IO wait CPU per Host',
    'dashboard' => 'System',
    'chart' => 'Avg IO wait CPU per Host',
    'operator' => '>=',
    'critical_value' => 50,
    'warning_value' => 20,
    'duration' => '2h',
    'description' => 'Detected high Average IOWait',
    'action' => 'create'
  },
  {
    'name' => 'GC duration',
    'dashboard' => 'System',
    'chart' => 'GC duration',
    'operator' => '>=',
    'critical_value' => 10000,
    'warning_value' => 5000,
    'duration' => '2m',
    'description' => 'Detected high Garbage Collection cycle time - this is not necessarily the Stop-the-World pause time',
    'action' => 'create'
  },
  {
    'name' => 'Used Memory Percentage',
    'dashboard' => 'System',
    'chart' => 'Used Memory Percentage',
    'operator' => '>=',
    'critical_value' => 85,
    'warning_value' => 95,
    'duration' => '1h',
    'description' => 'High memory utilization detected',
    'action' => 'create'
  },
  {
    'name' => 'Memory is Underutilized',
    'dashboard' => 'System',
    'chart' => 'Used Memory Percentage',
    'operator' => '<=',
    'critical_value' => 10,
    'warning_value' => 20,
    'duration' => '1w',
    'description' => 'Node memory has been very low for 1 week. Consider reducing memory space',
    'action' => 'create'
  },
  {
    'name' => 'NTP offset (milliseconds)',
    'dashboard' => 'System',
    'chart' => 'NTP offset (milliseconds)',
    'operator' => '>=',
    'critical_value' => 10,
    'warning_value' => 5,
    'duration' => '15m',
    'description' => 'High NTP time offset detected',
    'action' => 'create'
  },

  # Coordinator Alerts with special fields
  {
    'name' => 'Coordinator Read Latency - LOCAL_QUORUM 99thPercentile',
    'dashboard' => 'Coordinator',
    'chart' => 'Coordinator Read $consistency Latency - $percentile',
    'metric' => {
      'consistency' => ['LOCAL_QUORUM'],
      'percentile' => ['99thPercentile']
    },
    'operator' => '>=',
    'critical_value' => 2000000,
    'warning_value' => 1000000,
    'duration' => '15m',
    'description' => 'Detected high LOCAL_QUORUM Coordinator Read 99thPercentile latency',
    'routing' => {
      'error' => ['example_pagerduty_integration_developer'],
      'warning' => ['example_pagerduty_integration_developer', 'example_pagerduty_integration_ops']
    },
    'action' => 'create'
  },
  {
    'name' => 'Coordinator Read Latency - LOCAL_ONE 99thPercentile',
    'dashboard' => 'Coordinator',
    'chart' => 'Coordinator Read $consistency Latency - $percentile',
    'metric' => {
      'consistency' => ['LOCAL_ONE'],
      'percentile' => ['99thPercentile']
    },
    'operator' => '>=',
    'critical_value' => 2000000,
    'warning_value' => 1000000,
    'duration' => '15m',
    'description' => 'Detected high LOCAL_ONE Coordinator Read 99thPercentile latency',
    'routing' => {
      'error' => ['example_pagerduty_integration_developer'],
      'warning' => ['example_pagerduty_integration_developer', 'example_pagerduty_integration_ops']
    },
    'action' => 'create'
  },
  {
    'name' => 'Coordinator Range Read Latency - 99thPercentile',
    'dashboard' => 'Coordinator',
    'chart' => 'Coordinator Range Read Request Latency - $percentile',
    'metric' => {
      'percentile' => ['99thPercentile']
    },
    'operator' => '>=',
    'critical_value' => 2500000,
    'warning_value' => 1500000,
    'duration' => '15m',
    'description' => 'Detected high Coordinator Read 99thPercentile latency',
    'routing' => {
      'error' => ['example_pagerduty_integration_developer'],
      'warning' => ['example_pagerduty_integration_developer', 'example_pagerduty_integration_ops']
    },
    'action' => 'create'
  },
  {
    'name' => 'Coordinator Write Latency - LOCAL_QUORUM 99thPercentile',
    'dashboard' => 'Coordinator',
    'chart' => 'Coordinator Write $consistency Latency - $percentile',
    'metric' => {
      'consistency' => ['LOCAL_QUORUM'],
      'percentile' => ['99thPercentile']
    },
    'operator' => '>=',
    'critical_value' => 1500000,
    'warning_value' => 1000000,
    'duration' => '15m',
    'description' => 'Detected high LOCAL_QUORUM Coordinator Write 99thPercentile latency',
    'action' => 'create'
  },
  {
    'name' => 'Coordinator Write Latency - LOCAL_ONE 99thPercentile',
    'dashboard' => 'Coordinator',
    'chart' => 'Coordinator Write $consistency Latency - $percentile',
    'metric' => {
      'consistency' => ['LOCAL_ONE'],
      'percentile' => ['99thPercentile']
    },
    'operator' => '>=',
    'critical_value' => 1500000,
    'warning_value' => 1000000,
    'duration' => '15m',
    'description' => 'Detected high LOCAL_ONE Coordinator Write 99thPercentile latency',
    'action' => 'create'
  },
  {
    'name' => 'Coordinator Read Timeouts Per Second',
    'dashboard' => 'Coordinator',
    'chart' => 'Coordinator Read Timeouts Per Second',
    'operator' => '>=',
    'critical_value' => 1,
    'warning_value' => 0.1,
    'duration' => '5m',
    'description' => 'Detected Coordinator Read Timeouts',
    'action' => 'create'
  },
  {
    'name' => 'Coordinator Write Timeouts Per Second',
    'dashboard' => 'Coordinator',
    'chart' => 'Coordinator Write Timeouts Per Second',
    'operator' => '>=',
    'critical_value' => 1,
    'warning_value' => 0.1,
    'duration' => '5m',
    'description' => 'Detected Coordinator Write Timeouts',
    'action' => 'create'
  },
  {
    'name' => 'Coordinator Read Unavailability Requests Per Second',
    'dashboard' => 'Coordinator',
    'chart' => 'Coordinator Read Unavailability Requests Per Second',
    'operator' => '>=',
    'critical_value' => 1,
    'warning_value' => 0.1,
    'duration' => '5m',
    'description' => 'Detected Coordinator Read Unavailability Requests',
    'action' => 'create'
  },
  {
    'name' => 'Coordinator Write Unavailability Requests Per Second',
    'dashboard' => 'Coordinator',
    'chart' => 'Coordinator Write Unavailability Requests Per Second',
    'operator' => '>=',
    'critical_value' => 1,
    'warning_value' => 0.1,
    'duration' => '5m',
    'description' => 'Detected Coordinator Write Unavailability Requests',
    'action' => 'create'
  },

  # Dropped Messages Alerts
  {
    'name' => 'Mutation Dropped Messages',
    'dashboard' => 'Dropped Messages',
    'chart' => 'Mutation Dropped Messages',
    'operator' => '>=',
    'critical_value' => 10,
    'warning_value' => 5,
    'duration' => '5m',
    'description' => 'Detected Mutation Dropped messages',
    'action' => 'create'
  },
  {
    'name' => 'Read Dropped Messages',
    'dashboard' => 'Dropped Messages',
    'chart' => 'Read Dropped Messages',
    'operator' => '>=',
    'critical_value' => 5,
    'warning_value' => 1,
    'duration' => '5m',
    'description' => 'Detected Read Dropped messages',
    'action' => 'create'
  },
  {
    'name' => 'Read Repair Dropped Messages',
    'dashboard' => 'Dropped Messages',
    'chart' => 'Read Repair Dropped Messages',
    'operator' => '>=',
    'critical_value' => 5,
    'warning_value' => 1,
    'duration' => '5m',
    'description' => 'Detected Read Repair Dropped messages',
    'action' => 'create'
  },
  {
    'name' => 'Hint Dropped Messages',
    'dashboard' => 'Dropped Messages',
    'chart' => 'Hint Dropped Messages',
    'operator' => '>=',
    'critical_value' => 10,
    'warning_value' => 5,
    'duration' => '5m',
    'description' => 'Detected Hint Dropped messages',
    'action' => 'create'
  },

  # Threadpool Issues Alerts
  {
    'name' => 'ThreadPools - Gossip stage pending tasks',
    'dashboard' => 'Threadpool Issues',
    'chart' => 'Gossip stage pending tasks',
    'operator' => '>=',
    'critical_value' => 15,
    'warning_value' => 5,
    'duration' => '5m',
    'description' => 'Detected high Gossip stage pending tasks',
    'action' => 'create'
  },
  {
    'name' => 'ThreadPools - Total blocked tasks',
    'dashboard' => 'Threadpool Issues',
    'chart' => 'Total blocked tasks',
    'operator' => '>=',
    'critical_value' => 15,
    'warning_value' => 5,
    'duration' => '10m',
    'description' => 'Detected high Total blocked tasks',
    'action' => 'create'
  },

  # Entropy Alerts
  {
    'name' => 'Entropy Starved',
    'dashboard' => 'Entropy',
    'chart' => 'Available entropy (bits)',
    'operator' => '<=',
    'critical_value' => 20,
    'warning_value' => 50,
    'duration' => '15m',
    'description' => 'Entropy starvation detected',
    'action' => 'create'
  },

  # Cache Alerts
  {
    'name' => 'Key cache hit rate',
    'dashboard' => 'Cache',
    'chart' => 'Key cache hit rate',
    'operator' => '<=',
    'critical_value' => 50,
    'warning_value' => 75,
    'duration' => '15m',
    'description' => 'Key cache hit rate is low',
    'action' => 'create'
  },

  # Security Alerts
  {
    'name' => 'Authentication failures',
    'dashboard' => 'Security',
    'chart' => 'Authentication failures',
    'operator' => '>=',
    'critical_value' => 20,
    'warning_value' => 10,
    'duration' => '5m',
    'description' => 'High number of authentication failures detected',
    'action' => 'create'
  },
  {
    'name' => 'Connected clients to JMX',
    'dashboard' => 'Security',
    'chart' => 'Connected clients to JMX',
    'operator' => '>=',
    'critical_value' => 5,
    'warning_value' => 3,
    'duration' => '5m',
    'description' => 'High number of JMX connections detected',
    'action' => 'create'
  },
  {
    'name' => 'Connected native clients',
    'dashboard' => 'Security',
    'chart' => 'Connected native clients',
    'operator' => '>=',
    'critical_value' => 5000,
    'warning_value' => 3000,
    'duration' => '15m',
    'description' => 'High number of native client connections detected',
    'action' => 'create'
  },
  {
    'name' => 'Authorization failures',
    'dashboard' => 'Security',
    'chart' => 'Authorization failures',
    'operator' => '>=',
    'critical_value' => 20,
    'warning_value' => 10,
    'duration' => '5m',
    'description' => 'High number of authorization failures detected',
    'action' => 'create'
  },
  {
    'name' => 'DDL statements per second',
    'dashboard' => 'Security',
    'chart' => 'DDL statements per second',
    'operator' => '>=',
    'critical_value' => 3,
    'warning_value' => 1,
    'duration' => '5m',
    'description' => 'High number of DDL statements detected',
    'action' => 'create'
  },
  {
    'name' => 'DCL statements per second',
    'dashboard' => 'Security',
    'chart' => 'DCL statements per second',
    'operator' => '>=',
    'critical_value' => 3,
    'warning_value' => 1,
    'duration' => '5m',
    'description' => 'High number of DCL statements detected',
    'action' => 'create'
  },
  {
    'name' => 'DML statements per second',
    'dashboard' => 'Security',
    'chart' => 'DML statements per second',
    'operator' => '>=',
    'critical_value' => 10000,
    'warning_value' => 5000,
    'duration' => '15m',
    'description' => 'High number of DML statements detected',
    'action' => 'create'
  }
]

# Log Alert Rules
# Based on axonops-ansible-collection log alert rules
default['axonops']['log_alert_rules'] = [
  {
    'name' => 'Node Down',
    'warning_value' => 1,
    'critical_value' => 5,
    'duration' => '5m',
    'content' => '"is now DOWN"',
    'description' => 'Detected node down',
    'source' => '/var/log/cassandra/system.log',
    'present' => true,
    'action' => 'create'
  },
  {
    'name' => 'Unsupported Protocol',
    'warning_value' => 1,
    'critical_value' => 30,
    'duration' => '5m',
    'content' => '"Invalid or unsupported protocol version"',
    'source' => '/var/log/cassandra/system.log',
    'description' => 'Detected clients connecting with invalid or unsupported protocol version',
    'present' => true,
    'action' => 'create'
  },
  {
    'name' => 'Repair are not in progress',
    'warning_value' => 1,
    'critical_value' => 1,
    'operator' => '<',
    'duration' => '24h',
    'content' => 'repair',
    'source' => '/var/log/cassandra/system.log',
    'description' => 'Detected no repair has been seen in the last 24h',
    'present' => true,
    'action' => 'create'
  },
  {
    'name' => 'TLS failed to handshake with peer',
    'warning_value' => 50,
    'critical_value' => 100,
    'duration' => '5m',
    'content' => '"Failed to handshake with peer"',
    'source' => '/var/log/cassandra/system.log',
    'description' => 'Detected TLS handshake error with peer',
    'present' => true,
    'action' => 'create'
  },
  {
    'name' => 'Dropping gossip message',
    'warning_value' => 1,
    'critical_value' => 1,
    'duration' => '1m',
    'content' => '"dropping message of type GOSSIP"',
    'source' => '/var/log/cassandra/system.log',
    'description' => 'Detected Gossip messages are being dropped',
    'present' => true,
    'action' => 'create'
  },
  {
    'name' => 'Stream Session failed',
    'warning_value' => 1,
    'critical_value' => 1,
    'duration' => '1m',
    'content' => '"Stream failed"',
    'source' => '/var/log/cassandra/system.log',
    'description' => 'Detected Stream session has failed',
    'present' => true,
    'action' => 'create'
  },
  {
    'name' => 'SSTable corrupted',
    'warning_value' => 1,
    'critical_value' => 1,
    'duration' => '1m',
    'content' => '"Corrupt sstable"',
    'source' => '/var/log/cassandra/system.log',
    'description' => 'SSTable(s) have been corrupted',
    'present' => true,
    'action' => 'create'
  },
  {
    'name' => 'Anticompaction',
    'warning_value' => 1,
    'critical_value' => 1,
    'duration' => '1m',
    'content' => '"Performing anticompaction"',
    'source' => '/var/log/cassandra/system.log',
    'description' => 'An incremental repair session is running',
    'present' => true,
    'action' => 'create'
  },
  {
    'name' => 'JNA not found',
    'warning_value' => 1,
    'critical_value' => 1,
    'duration' => '1m',
    'content' => '"JNA not found"',
    'source' => '/var/log/cassandra/system.log',
    'description' => 'JNA library is required for production systems',
    'present' => true,
    'action' => 'create'
  },
  {
    'name' => 'Not enough space for compaction',
    'warning_value' => 1,
    'critical_value' => 1,
    'duration' => '1m',
    'content' => '"Not enough space for compaction"',
    'source' => '/var/log/cassandra/system.log',
    'description' => 'Compaction requires additional free disk space',
    'present' => true,
    'action' => 'create'
  },
  {
    'name' => 'Unable to allocate memory',
    'warning_value' => 1,
    'critical_value' => 1,
    'duration' => '1m',
    'content' => '"Unable to allocate"',
    'source' => '/var/log/cassandra/system.log',
    'description' => 'Cassandra could not allocate the required memory',
    'present' => true,
    'action' => 'create'
  },
  {
    'name' => 'Cassandra server running in degraded mode',
    'warning_value' => 1,
    'critical_value' => 1,
    'duration' => '1m',
    'content' => '"Cassandra server running in degraded mode"',
    'source' => '/var/log/cassandra/system.log',
    'description' => 'The Operating System settings do not meet requirements',
    'present' => true,
    'action' => 'create'
  },
  {
    'name' => 'Writing large partition',
    'warning_value' => 1,
    'critical_value' => 1,
    'duration' => '1m',
    'content' => '"Writing large partition"',
    'source' => '/var/log/cassandra/system.log',
    'description' => 'There are partitions larger than the configured compaction_large_partition_warning_threshold_mb (default 100MB)',
    'present' => true,
    'action' => 'create'
  },
  {
    'name' => 'Dropping messages during repair',
    'warning_value' => 1,
    'critical_value' => 1,
    'duration' => '1m',
    'content' => '"dropping message of type SYNC"',
    'source' => '/var/log/cassandra/system.log',
    'description' => 'Repair sync response has been dropped',
    'present' => true,
    'action' => 'create'
  },
  {
    'name' => 'Prepared statements discarded',
    'warning_value' => 1,
    'critical_value' => 1,
    'duration' => '1m',
    'content' => '"prepared statements discarded"',
    'source' => '/var/log/cassandra/system.log',
    'description' => 'Prepared statements cache limit reached - increase with the prepared_statements_cache_size_mb setting',
    'present' => true,
    'action' => 'create'
  }
]

# Shell Checks
# Based on axonops-ansible-collection service checks
default['axonops']['shell_checks'] = [
  {
    'name' => 'Check for schema disagreement',
    'interval' => '15m',
    'timeout' => '2m',
    'shell' => '/bin/bash',
    'present' => true,
    'action' => 'create',
    'script' => <<-'SCRIPT'
EXIT_OK=0
EXIT_WARNING=1
EXIT_CRITICAL=2

if type nodetool >/dev/null; then
    NODETOOL=nodetool
elif [ -x /opt/cassandra/bin/nodetool ]; then
    NODETOOL=/opt/cassandra/bin/nodetool
elif [ -x /usr/local/cassandra/bin/nodetool ]; then
    NODETOOL=/usr/local/cassandra/bin/nodetool
else
    echo "nodetool not found"
    exit $EXIT_CRITICAL
fi

# Sleep up to 60 seconds to avoid simultaneous checks
sleep $(( $RANDOM % 60 ))

schema_variations=$($NODETOOL gossipinfo | grep SCHEMA | grep -vi UNREACHABLE | sed -e 's/SCHEMA:[0-9]*://g' | sort | uniq | wc -l)
if [ $? -gt 0 ]; then
    exit $EXIT_CRITICAL=2
fi

if [ $schema_variations -gt 1 ]; then
  exit $EXIT_CRITICAL
else
  exit $EXIT_OK
fi
SCRIPT
  },
  {
    'name' => 'Check for node DOWN',
    'interval' => '15m',
    'timeout' => '2m',
    'shell' => '/bin/bash',
    'present' => true,
    'action' => 'create',
    'script' => <<-'SCRIPT'
EXIT_OK=0
EXIT_WARNING=1
EXIT_CRITICAL=2

WARNING_DN_COUNT=1
CRITICAL_DN_COUNT=2

if type nodetool >/dev/null; then
    NODETOOL=nodetool
elif [ -x /opt/cassandra/bin/nodetool ]; then
    NODETOOL=/opt/cassandra/bin/nodetool
elif [ -x /usr/local/cassandra/bin/nodetool ]; then
    NODETOOL=/usr/local/cassandra/bin/nodetool
else
    echo "nodetool not found"
    exit $EXIT_CRITICAL
fi

# Sleep up to 60 seconds to avoid simultaneous checks
sleep $(( $RANDOM % 60 ))

# Get the local Data Center from 'nodetool info'
local_dc=$($NODETOOL info | awk -F: '/Data Center/{gsub(/^[ \t]+/, "", $2); print $2}')
if [ -z $local_dc ]; then
    exit $EXIT_WARN
fi

# Initialize counts
local_dn_count=0
remote_dn_count=0

# Declare associative arrays
declare -A dc_dn_counts  # Counts of DN per Data Center
declare -A dcrack_dn_counts  # Counts of DN per Data Center and Rack

# Initialize variables
current_dc=""
in_node_section=false

# Process 'nodetool status' output without using a subshell
while read -r line; do
    # Check for Data Center line
    if [[ "$line" =~ ^Datacenter:\ (.*) ]]; then
        current_dc="${BASH_REMATCH[1]}"
        continue
    fi

    # Skip irrelevant lines
    if [[ "$line" =~ ^\s*$ ]] || [[ "$line" =~ ^==+ ]] || [[ "$line" =~ ^Status= ]]; then
        continue
    fi

    # Check for Address line
    if [[ "$line" =~ ^Address ]]; then
        in_node_section=true
        continue
    fi

    # Process node lines
    if $in_node_section && [[ "$line" =~ ^DN ]]; then
        # Extract fields
        fields=($line)
        address="${fields[1]}"
        rack="${fields[7]}"

        # Skip nodes without valid address or rack
        if [[ -z "$address" ]] || [[ -z "$rack" ]]; then
            continue
        fi

        # Aggregate DN counts
        if [[ "$current_dc" == "$local_dc" ]]; then
            ((local_dn_count++))
        else
            ((remote_dn_count++))
        fi

        # Store DN counts per Data Center
        ((dc_dn_counts["$current_dc"]++))

        # Store DN counts per Data Center and Rack
        dcrack_key="${current_dc}_${rack}"
        ((dcrack_dn_counts["$dcrack_key"]++))
    fi
done < <($NODETOOL status)

# Output: dc_name:dc_dn_count,dcrack_name:dcrack_dn_count,local_dn_count,remote_dn_count
output=""
for dc in "${!dc_dn_counts[@]}"; do
    output="${output}${dc}:${dc_dn_counts[$dc]},"
done
for dcrack in "${!dcrack_dn_counts[@]}"; do
    output="${output}${dcrack}:${dcrack_dn_counts[$dcrack]},"
done
output="${output}local_dn_count:${local_dn_count},remote_dn_count:${remote_dn_count}"

# Determine exit status
if [ $local_dn_count -ge $CRITICAL_DN_COUNT ]; then
    echo "$output"
    exit $EXIT_CRITICAL
elif [ $local_dn_count -ge $WARNING_DN_COUNT ]; then
    echo "$output"
    exit $EXIT_WARNING
else
    echo "$output"
    exit $EXIT_OK
fi
SCRIPT
  },
  {
    'name' => 'SSL certificate check',
    'interval' => '12h',
    'timeout' => '1m',
    'shell' => '/bin/bash',
    'present' => true,
    'action' => 'create',
    'script' => <<-'SCRIPT'
#!/bin/bash
EXIT_OK=0
EXIT_WARNING=1
EXIT_CRITICAL=2

# This example is to test SSL on a local cassandra cluster.
# Please customize it based on your requirements.

# Temp file creation
tmpfile=$(mktemp /tmp/ssl_check.XXXXXX)
trap "rm -f $tmpfile" EXIT

# Run openssl command and redirect output to the temp file
openssl s_client -servername localhost -connect localhost:9142 \
    -showcerts </dev/null 2>&1 | openssl x509 -text > $tmpfile 2>&1

# Check if openssl command succeeded
if [ ${PIPESTATUS[0]} -ne 0 ] || [ ${PIPESTATUS[1]} -ne 0 ]; then
    echo "Error running openssl commands"
    exit $EXIT_CRITICAL
fi

# Check certificate validity
not_before=$(grep "Not Before" $tmpfile | sed 's/Not Before: //')
not_after=$(grep "Not After" $tmpfile | sed 's/Not After : //')

# Convert dates to epoch time for comparison
current_epoch=$(date +%s)
not_before_epoch=$(date -d "$not_before" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$not_before" +%s 2>/dev/null)
not_after_epoch=$(date -d "$not_after" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$not_after" +%s 2>/dev/null)

# Check if date conversions succeeded
if [ -z "$not_before_epoch" ] || [ -z "$not_after_epoch" ]; then
    echo "Error parsing certificate dates"
    exit $EXIT_CRITICAL
fi

# Check if certificate is not yet valid
if [ $current_epoch -lt $not_before_epoch ]; then
    echo "Certificate is not yet valid (starts: $not_before)"
    exit $EXIT_CRITICAL
fi

# Check if certificate has expired
if [ $current_epoch -gt $not_after_epoch ]; then
    echo "Certificate has expired (ended: $not_after)"
    exit $EXIT_CRITICAL
fi

# Calculate days until expiration
days_until_expiry=$(( ($not_after_epoch - $current_epoch) / 86400 ))

# Check OCSP stapling
ocsp_status=$(grep -A1 "OCSP response:" $tmpfile | grep -v "OCSP response:" | xargs)

# Determine exit status based on days until expiry
if [ $days_until_expiry -le 7 ]; then
    echo "Certificate expires in $days_until_expiry days (Critical) | OCSP: $ocsp_status"
    exit $EXIT_CRITICAL
elif [ $days_until_expiry -le 30 ]; then
    echo "Certificate expires in $days_until_expiry days (Warning) | OCSP: $ocsp_status"
    exit $EXIT_WARNING
else
    echo "Certificate valid for $days_until_expiry more days | OCSP: $ocsp_status"
    exit $EXIT_OK
fi
SCRIPT
  },
  {
    'name' => 'Debian / Ubuntu - Check host needs reboot',
    'interval' => '12h',
    'timeout' => '1m',
    'shell' => '/bin/bash',
    'present' => true,
    'action' => 'create',
    'script' => <<-'SCRIPT'
#!/bin/bash
EXIT_OK=0
EXIT_WARNING=1
EXIT_CRITICAL=2

if [ -f /var/run/reboot-required ]; then
    echo "Host needs reboot"
    exit $EXIT_WARNING
else
    echo "No reboot required"
    exit $EXIT_OK
fi
SCRIPT
  },
  {
    'name' => 'Check AWS events',
    'interval' => '12h',
    'timeout' => '1m',
    'shell' => '/bin/bash',
    'present' => true,
    'action' => 'create',
    'script' => <<-'SCRIPT'
#!/bin/bash
EXIT_OK=0
EXIT_WARNING=1
EXIT_CRITICAL=2

# This script checks for any AWS events for this instance
# It requires the AWS CLI to be installed and configured with proper credentials

# Check if we're running on EC2
if ! command -v aws &> /dev/null; then
    echo "AWS CLI not found, skipping check"
    exit $EXIT_OK
fi

# Get instance ID from metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)
if [ -z "$INSTANCE_ID" ]; then
    echo "Not running on EC2, skipping check"
    exit $EXIT_OK
fi

# Get region from metadata
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null)
if [ -z "$REGION" ]; then
    echo "Could not determine region"
    exit $EXIT_WARNING
fi

# Check for events
EVENTS=$(aws ec2 describe-instance-status \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'InstanceStatuses[0].Events[?Status!=`Completed`]' \
    --output json 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Failed to query AWS events"
    exit $EXIT_WARNING
fi

if [ "$EVENTS" != "null" ] && [ "$EVENTS" != "[]" ]; then
    echo "AWS events pending: $EVENTS"
    exit $EXIT_WARNING
else
    echo "No AWS events"
    exit $EXIT_OK
fi
SCRIPT
  },
  {
    'name' => 'Check for commitlog archives',
    'interval' => '12h',
    'timeout' => '1m',
    'shell' => '/bin/bash',
    'present' => true,
    'action' => 'create',
    'script' => <<-'SCRIPT'
#!/bin/bash
EXIT_OK=0
EXIT_WARNING=1
EXIT_CRITICAL=2

# Default commitlog archive directory
ARCHIVE_DIR="/var/lib/cassandra/commitlog_archive"

# Check if directory exists
if [ ! -d "$ARCHIVE_DIR" ]; then
    echo "Commitlog archive directory not found: $ARCHIVE_DIR"
    exit $EXIT_OK
fi

# Count files in archive directory
FILE_COUNT=$(find "$ARCHIVE_DIR" -type f -name "*.log" 2>/dev/null | wc -l)

# Check thresholds
if [ $FILE_COUNT -gt 1000 ]; then
    echo "Critical: $FILE_COUNT commitlog archive files found"
    exit $EXIT_CRITICAL
elif [ $FILE_COUNT -gt 500 ]; then
    echo "Warning: $FILE_COUNT commitlog archive files found"
    exit $EXIT_WARNING
else
    echo "OK: $FILE_COUNT commitlog archive files"
    exit $EXIT_OK
fi
SCRIPT
  },
  {
    'name' => 'Cassandra CQL Consistency Level Test Script',
    'interval' => '12h',
    'timeout' => '1m',
    'shell' => '/bin/bash',
    'present' => true,
    'action' => 'create',
    'script' => <<-'SCRIPT'
#!/bin/bash

# Exit codes
EXIT_OK=0
EXIT_WARNING=1
EXIT_CRITICAL=2

# Configuration
KEYSPACE="system"
TABLE="local"
CONSISTENCY_LEVELS=("ONE" "QUORUM" "LOCAL_QUORUM" "ALL")
CQL_HOST="localhost"
CQL_PORT="9042"

# Check if cqlsh is available
if ! command -v cqlsh &> /dev/null; then
    echo "cqlsh command not found"
    exit $EXIT_CRITICAL
fi

# Test each consistency level
failed_levels=""
for cl in "${CONSISTENCY_LEVELS[@]}"; do
    # Create a temporary file for the CQL commands
    tmpfile=$(mktemp)
    cat > "$tmpfile" << EOF
CONSISTENCY $cl;
SELECT * FROM $KEYSPACE.$TABLE LIMIT 1;
EOF

    # Execute the query
    if ! cqlsh "$CQL_HOST" "$CQL_PORT" -f "$tmpfile" > /dev/null 2>&1; then
        failed_levels="$failed_levels $cl"
    fi

    # Clean up
    rm -f "$tmpfile"
done

# Determine exit status
if [ -n "$failed_levels" ]; then
    echo "Failed consistency levels:$failed_levels"
    exit $EXIT_WARNING
else
    echo "All consistency levels working"
    exit $EXIT_OK
fi
SCRIPT
  }
]