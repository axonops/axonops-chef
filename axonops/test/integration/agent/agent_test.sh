#!/bin/bash
# Test script for AxonOps agent installation

set -e

echo "Running agent verification tests..."

# Check if user was created
if ! getent passwd axonops > /dev/null 2>&1; then
  echo "FAIL: axonops user not found"
  exit 1
fi
echo "✓ axonops user exists"

# Check if directories were created
for dir in /etc/axonops /var/log/axonops /var/lib/axonops /usr/share/axonops; do
  if [ ! -d "$dir" ]; then
    echo "FAIL: Directory $dir does not exist"
    exit 1
  fi
  echo "✓ Directory $dir exists"
done

# Check if config file was created
if [ ! -f /etc/axonops/axon-agent.yml ]; then
  echo "FAIL: Config file /etc/axonops/axon-agent.yml not found"
  exit 1
fi
echo "✓ Config file exists"

# Check if test binary was created
if [ ! -x /usr/bin/axon-agent ]; then
  echo "FAIL: Binary /usr/bin/axon-agent not found or not executable"
  exit 1
fi
echo "✓ Test binary exists and is executable"

# Check if service file was created
if [ ! -f /etc/systemd/system/axon-agent.service ]; then
  echo "FAIL: Service file not found"
  exit 1
fi
echo "✓ Service file exists"

# Check config file content
if ! grep -q "test-agent-key" /etc/axonops/axon-agent.yml; then
  echo "FAIL: Config file missing expected content"
  exit 1
fi
echo "✓ Config file has expected content"

# Check file permissions
if [ "$(stat -c %a /etc/axonops/axon-agent.yml)" != "600" ]; then
  echo "FAIL: Config file has incorrect permissions"
  exit 1
fi
echo "✓ Config file has correct permissions (600)"

# Check file ownership
if [ "$(stat -c %U:%G /etc/axonops/axon-agent.yml)" != "axonops:axonops" ]; then
  echo "FAIL: Config file has incorrect ownership"
  exit 1
fi
echo "✓ Config file has correct ownership (axonops:axonops)"

echo ""
echo "All agent tests passed!"