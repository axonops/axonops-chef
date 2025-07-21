#!/bin/bash
# Verification script for AxonOps agent test
set -e

echo "=== AxonOps Agent Test Verification ==="

# Check user and group
echo -n "Checking axonops user... "
if id axonops >/dev/null 2>&1; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check directories
for dir in /etc/axonops /var/log/axonops /var/lib/axonops /usr/share/axonops; do
  echo -n "Checking directory $dir... "
  if [ -d "$dir" ]; then
    echo "✓"
  else
    echo "✗ FAILED"
    exit 1
  fi
done

# Check files
echo -n "Checking agent binary... "
if [ -x /usr/bin/axon-agent ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

echo -n "Checking config file... "
if [ -f /etc/axonops/axon-agent.yml ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

echo -n "Checking service file... "
if [ -f /etc/systemd/system/axon-agent.service ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

echo ""
echo "=== All tests passed! ==="