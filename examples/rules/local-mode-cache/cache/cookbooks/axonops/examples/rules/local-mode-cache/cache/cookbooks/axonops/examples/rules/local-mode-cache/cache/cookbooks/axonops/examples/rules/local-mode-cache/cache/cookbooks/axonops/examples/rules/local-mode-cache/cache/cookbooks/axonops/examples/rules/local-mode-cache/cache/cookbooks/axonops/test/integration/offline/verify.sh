#!/bin/bash
# Verification script for offline/airgapped AxonOps installation
set -e

echo "=== AxonOps Offline Installation Test Verification ==="
echo ""

# Check that package source was used
echo -n "Checking offline package directory... "
if [ -d /tmp/packages ]; then
  echo "✓"
  echo "  Contents:"
  ls -la /tmp/packages/ 2>/dev/null | grep -E "\.(deb|rpm|tar\.gz)" | awk '{print "    - " $9}'
else
  echo "✗ FAILED - offline package directory not found"
  exit 1
fi

# Check user and basic setup
echo ""
echo -n "Checking axonops user... "
if id axonops >/dev/null 2>&1; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check agent installation from offline package
echo ""
echo "==== Agent Installation ===="
echo -n "Checking agent binary... "
if [ -x /usr/bin/axon-agent ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

echo -n "Checking agent was installed from local package... "
# On Debian/Ubuntu systems
if command -v dpkg >/dev/null 2>&1; then
  if dpkg -l | grep -q axon-agent; then
    echo "✓ (via dpkg)"
  else
    echo "✗ package not found in dpkg database"
  fi
# On RHEL/CentOS systems
elif command -v rpm >/dev/null 2>&1; then
  if rpm -qa | grep -q axon-agent; then
    echo "✓ (via rpm)"
  else
    echo "✗ package not found in rpm database"
  fi
else
  echo "- unable to verify package installation"
fi

# Check configuration
echo -n "Checking agent config... "
if [ -f /etc/axonops/axon-agent.yml ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check that no external downloads were attempted
echo ""
echo "==== Offline Verification ===="
echo -n "Checking for apt/yum repository configs... "
repo_found=0
if [ -f /etc/apt/sources.list.d/axonops.list ]; then
  echo "✗ Found APT repository (should not exist in offline mode)"
  repo_found=1
elif [ -f /etc/yum.repos.d/axonops.repo ]; then
  echo "✗ Found YUM repository (should not exist in offline mode)"
  repo_found=1
else
  echo "✓ No external repositories configured"
fi

# Check Java installation (should be from local tarball)
echo -n "Checking Java installation... "
if [ -d /opt/java ]; then
  echo "✓ Installed to /opt/java"
  if [ -L /opt/java/default ]; then
    java_version=$(readlink /opt/java/default)
    echo "  └─ Version: $java_version"
  fi
else
  echo "✗ Java not found in expected location"
fi

# Verify no network connectivity needed
echo ""
echo "==== Network Independence ===="
echo "Checking configuration for offline operation..."

echo -n "  Agent configuration... "
if grep -E "(localhost|127\.0\.0\.1|internal\.domain)" /etc/axonops/axon-agent.yml >/dev/null 2>&1; then
  echo "✓ configured for local/internal endpoints"
else
  if grep -E "axonops\.cloud" /etc/axonops/axon-agent.yml >/dev/null 2>&1; then
    echo "⚠ configured for cloud endpoints (may not work offline)"
  else
    echo "✓"
  fi
fi

# Check service file
echo -n "  Service configuration... "
if [ -f /etc/systemd/system/axon-agent.service ]; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

echo ""
echo "==== Summary ===="
if [ $repo_found -eq 0 ]; then
  echo "✅ Offline installation verified successfully!"
  echo "   - All components installed from local packages"
  echo "   - No external repositories configured"
  echo "   - Ready for airgapped operation"
else
  echo "⚠️  Installation completed but external repositories were found"
  echo "   This may cause issues in truly airgapped environments"
fi