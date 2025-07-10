#!/bin/bash
# Verification script for AxonOps configuration management test
set -e

echo "=== AxonOps Configuration Management Test Verification ==="
echo ""

# Check basic server setup (configure requires server)
echo "==== Server Components ===="
echo -n "Checking server installation... "
if [ -x /usr/bin/axon-server ]; then
  echo "✓"
else
  echo "✗ FAILED - server must be installed for configuration"
  exit 1
fi

# Check API configuration directory
echo ""
echo "==== API Configuration ===="
echo -n "Checking API config directory... "
if [ -d /etc/axonops/config.d ]; then
  echo "✓"
  echo "  Contents:"
  ls -la /etc/axonops/config.d/ 2>/dev/null | grep -E "\.(yml|yaml|json)" | awk '{print "    - " $9}'
else
  echo "- not found (may not be created yet)"
fi

# Check for alert configurations
echo ""
echo "==== Alert Configuration ===="
echo -n "Checking alerts config... "
if [ -f /etc/axonops/config.d/alerts.yml ] || [ -f /etc/axonops/alerts.yml ]; then
  echo "✓ found"
  # Check for test slack endpoint
  if grep -q "test_slack" /etc/axonops/config.d/alerts.yml 2>/dev/null || \
     grep -q "test_slack" /etc/axonops/alerts.yml 2>/dev/null; then
    echo "  └─ Test Slack endpoint: ✓"
  fi
  # Check for high CPU alert rule
  if grep -q "high_cpu" /etc/axonops/config.d/alerts.yml 2>/dev/null || \
     grep -q "high_cpu" /etc/axonops/alerts.yml 2>/dev/null; then
    echo "  └─ High CPU alert rule: ✓"
  fi
else
  echo "- not configured"
fi

# Check for service checks configuration
echo ""
echo "==== Service Checks Configuration ===="
echo -n "Checking service checks config... "
if [ -f /etc/axonops/config.d/service_checks.yml ] || [ -f /etc/axonops/service_checks.yml ]; then
  echo "✓ found"
  if grep -q "cassandra_health" /etc/axonops/config.d/service_checks.yml 2>/dev/null || \
     grep -q "cassandra_health" /etc/axonops/service_checks.yml 2>/dev/null; then
    echo "  └─ Cassandra health check: ✓"
  fi
else
  echo "- not configured"
fi

# Check for backup configuration
echo ""
echo "==== Backup Configuration ===="
echo -n "Checking backup config... "
if [ -f /etc/axonops/config.d/backups.yml ] || [ -f /etc/axonops/backups.yml ]; then
  echo "✓ found"
  if grep -q "daily" /etc/axonops/config.d/backups.yml 2>/dev/null || \
     grep -q "daily" /etc/axonops/backups.yml 2>/dev/null; then
    echo "  └─ Daily backup schedule: ✓"
  fi
  echo -n "  └─ Backup destination: "
  backup_dest=$(grep -A2 "destination:" /etc/axonops/config.d/backups.yml 2>/dev/null | tail -1 | xargs || echo "not found")
  echo "$backup_dest"
else
  echo "- not configured"
fi

echo -n "Checking backup directory... "
if [ -d /backup/cassandra ]; then
  echo "✓ exists"
else
  echo "- not created"
fi

# Check API key configuration
echo ""
echo "==== API Integration ===="
echo -n "Checking API credentials... "
api_configured=0
if [ -f /etc/axonops/axon-server.yml ]; then
  if grep -q "api_key:" /etc/axonops/axon-server.yml && \
     ! grep -q "api_key: *$" /etc/axonops/axon-server.yml && \
     ! grep -q "api_key: *null" /etc/axonops/axon-server.yml; then
    echo "✓ API key configured"
    api_configured=1
  else
    echo "✗ API key not configured"
  fi
else
  echo "✗ server config not found"
fi

echo -n "Checking organization... "
if [ -f /etc/axonops/axon-server.yml ]; then
  if grep -q "organization:" /etc/axonops/axon-server.yml && \
     ! grep -q "organization: *$" /etc/axonops/axon-server.yml && \
     ! grep -q "organization: *null" /etc/axonops/axon-server.yml; then
    org=$(grep "organization:" /etc/axonops/axon-server.yml | awk '{print $2}' | tr -d '"')
    echo "✓ configured as: $org"
  else
    echo "✗ organization not configured"
  fi
else
  echo "✗ server config not found"
fi

# Check for axonops-config-automation integration files
echo ""
echo "==== Config Automation Integration ===="
echo -n "Checking for automation scripts... "
if [ -f /opt/axonops/bin/config-sync.sh ] || [ -f /usr/local/bin/axonops-config-sync ]; then
  echo "✓ found"
else
  echo "- not installed (optional)"
fi

echo -n "Checking for automation markers... "
if [ -f /etc/axonops/.last-config-sync ]; then
  last_sync=$(cat /etc/axonops/.last-config-sync 2>/dev/null || echo "unknown")
  echo "✓ last sync: $last_sync"
else
  echo "- no sync recorded"
fi

echo ""
echo "==== Summary ===="
if [ $api_configured -eq 1 ]; then
  echo "✅ Configuration management is set up!"
  echo "   - API credentials configured"
  echo "   - Ready for configuration automation"
else
  echo "⚠️  Configuration management partially set up"
  echo "   - API credentials need to be configured"
  echo "   - Some features may not work without API key"
fi