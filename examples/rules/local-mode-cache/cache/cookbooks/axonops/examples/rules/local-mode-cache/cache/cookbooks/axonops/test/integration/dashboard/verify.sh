#!/bin/bash
# Verification script for AxonOps dashboard test
set -e

echo "=== AxonOps Dashboard Test Verification ==="

# Check user and group
echo -n "Checking axonops user... "
if id axonops >/dev/null 2>&1; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check dashboard directories
for dir in /etc/axonops /var/log/axonops /opt/axonops/dashboard; do
  echo -n "Checking directory $dir... "
  if [ -d "$dir" ]; then
    echo "✓"
  else
    echo "✗ FAILED"
    exit 1
  fi
done

# Check dashboard binary/files
echo -n "Checking dashboard installation... "
if [ -x /usr/bin/axon-dash ] || [ -d /opt/axonops/dashboard/dist ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check dashboard config
echo -n "Checking dashboard config file... "
if [ -f /etc/axonops/axon-dash.yml ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check dashboard service file
echo -n "Checking dashboard service file... "
if [ -f /etc/systemd/system/axon-dash.service ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check nginx configuration (if used)
echo -n "Checking nginx config (optional)... "
if [ -f /etc/nginx/sites-available/axonops-dashboard ]; then
  echo "✓ found"
else
  echo "- not configured (OK if not using nginx)"
fi

# Check ports
echo ""
echo "Port checks (may fail if services not started):"
echo -n "  Dashboard port 3000... "
if nc -z localhost 3000 2>/dev/null; then
  echo "✓ listening"
else
  echo "- not listening (OK if service not started)"
fi

echo ""
echo "=== All required files/directories verified! ==="