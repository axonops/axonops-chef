#!/bin/bash
# Minimal verification script for AxonOps server test
set -e

echo "=== AxonOps Server Test Verification (Minimal) ==="

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

echo ""
echo "=== All minimal tests passed! ==="
echo "Note: This is a minimal test setup. Production would include:"
echo "  - Elasticsearch for data storage"
echo "  - Cassandra for metadata storage"
echo "  - Actual AxonOps server package"