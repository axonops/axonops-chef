#!/bin/bash
# Verification script for AxonOps server test
set -e

echo "=== AxonOps Server Test Verification ==="

# Check user and group
echo -n "Checking axonops user... "
if id axonops >/dev/null 2>&1; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check server directories
for dir in /etc/axonops /var/log/axonops /var/lib/axonops /usr/share/axonops /opt/axonops; do
  echo -n "Checking directory $dir... "
  if [ -d "$dir" ]; then
    echo "✓"
  else
    echo "✗ FAILED"
    exit 1
  fi
done

# Check server binary
echo -n "Checking server binary... "
if [ -x /usr/bin/axon-server ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check server config
echo -n "Checking server config file... "
if [ -f /etc/axonops/axon-server.yml ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check server service file
echo -n "Checking server service file... "
if [ -f /etc/systemd/system/axon-server.service ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check Elasticsearch (should be installed for self-hosted)
echo -n "Checking Elasticsearch directory... "
if [ -d /opt/elasticsearch ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

echo -n "Checking Elasticsearch service... "
if [ -f /etc/systemd/system/axonops-search.service ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check Cassandra for AxonOps storage
echo -n "Checking Cassandra directory... "
if [ -d /opt/cassandra ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

echo -n "Checking Cassandra service... "
if [ -f /etc/systemd/system/axonops-cassandra.service ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check ports (if services are running)
echo ""
echo "Port checks (may fail if services not started):"
echo -n "  Server port 8080... "
if nc -z localhost 8080 2>/dev/null; then
  echo "✓ listening"
else
  echo "- not listening (OK if service not started)"
fi

echo -n "  Elasticsearch port 9200... "
if nc -z localhost 9200 2>/dev/null; then
  echo "✓ listening"
else
  echo "- not listening (OK if service not started)"
fi

echo -n "  Cassandra port 9042... "
if nc -z localhost 9042 2>/dev/null; then
  echo "✓ listening"
else
  echo "- not listening (OK if service not started)"
fi

echo ""
echo "=== All required files/directories verified! ==="