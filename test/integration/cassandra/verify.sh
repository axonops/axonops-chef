#!/bin/bash
# Verification script for Cassandra installation test
set -e

echo "=== Cassandra Installation Test Verification ==="

# Check cassandra user
echo -n "Checking cassandra user... "
if id cassandra >/dev/null 2>&1; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check Cassandra directories
for dir in /etc/cassandra /var/lib/cassandra /var/log/cassandra /data/cassandra/data /data/cassandra/commitlog /data/cassandra/saved_caches /data/cassandra/hints; do
  echo -n "Checking directory $dir... "
  if [ -d "$dir" ]; then
    echo "✓"
    # Check ownership
    owner=$(stat -c %U "$dir" 2>/dev/null || stat -f %Su "$dir" 2>/dev/null)
    if [ "$owner" = "cassandra" ]; then
      echo "  └─ ownership: ✓"
    else
      echo "  └─ ownership: ✗ (owned by $owner, expected cassandra)"
    fi
  else
    echo "✗ FAILED"
    exit 1
  fi
done

# Check Cassandra installation
echo -n "Checking Cassandra binary... "
if [ -x /usr/bin/cassandra ] || [ -x /opt/cassandra/bin/cassandra ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check Cassandra configuration
echo -n "Checking cassandra.yaml... "
if [ -f /etc/cassandra/cassandra.yaml ]; then
  echo "✓"
  # Check cluster name
  cluster_name=$(grep "^cluster_name:" /etc/cassandra/cassandra.yaml | awk '{print $2}' | tr -d "'\"")
  echo "  └─ cluster name: $cluster_name"
else
  echo "✗ FAILED"
  exit 1
fi

echo -n "Checking cassandra-env.sh... "
if [ -f /etc/cassandra/cassandra-env.sh ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check JVM options
echo -n "Checking jvm.options... "
if [ -f /etc/cassandra/jvm.options ] || [ -f /etc/cassandra/jvm11-server.options ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check systemd service
echo -n "Checking Cassandra service file... "
if [ -f /etc/systemd/system/cassandra.service ] || [ -f /usr/lib/systemd/system/cassandra.service ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check sysctl settings
echo ""
echo "System settings:"
echo -n "  vm.max_map_count... "
max_map_count=$(sysctl -n vm.max_map_count 2>/dev/null || echo "unknown")
if [ "$max_map_count" -ge 1048575 ] 2>/dev/null; then
  echo "✓ ($max_map_count)"
else
  echo "- current: $max_map_count (recommended: >= 1048575)"
fi

# Check ports
echo ""
echo "Port checks (may fail if service not started):"
echo -n "  CQL native port 9042... "
if nc -z localhost 9042 2>/dev/null; then
  echo "✓ listening"
else
  echo "- not listening (OK if service not started)"
fi

echo -n "  Storage port 7000... "
if nc -z localhost 7000 2>/dev/null; then
  echo "✓ listening"
else
  echo "- not listening (OK if service not started)"
fi

echo -n "  JMX port 7199... "
if nc -z localhost 7199 2>/dev/null; then
  echo "✓ listening"
else
  echo "- not listening (OK if service not started)"
fi

# Check if nodetool works (only if Cassandra is running)
echo ""
echo -n "Checking nodetool (if Cassandra running)... "
if command -v nodetool >/dev/null 2>&1; then
  if nodetool version 2>/dev/null; then
    echo "✓ working"
  else
    echo "- not accessible (OK if service not started)"
  fi
else
  echo "- nodetool not found in PATH"
fi

echo ""
echo "=== All required files/directories verified! ==="