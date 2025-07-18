#!/bin/bash
# Verification script for default AxonOps recipe
set -e

echo "=== AxonOps Default Recipe Test Verification ==="
echo ""

# The default recipe should set up common components and Java
echo "==== Common Components ===="

# Check Java installation
echo -n "Checking Java installation... "
if command -v java >/dev/null 2>&1; then
  java_version=$(java -version 2>&1 | grep "version" | head -1)
  echo "✓"
  echo "  └─ Version: $java_version"
  
  # Check JAVA_HOME
  echo -n "  └─ JAVA_HOME... "
  if [ -n "$JAVA_HOME" ]; then
    echo "✓ $JAVA_HOME"
  else
    # Check if it's set in profile
    if grep -q "JAVA_HOME" /etc/profile.d/java.sh 2>/dev/null || \
       grep -q "JAVA_HOME" /etc/environment 2>/dev/null; then
      echo "✓ configured in profile"
    else
      echo "- not set"
    fi
  fi
else
  echo "✗ FAILED - Java is required"
  exit 1
fi

# Check AxonOps user (created by common recipe)
echo -n "Checking axonops user... "
if id axonops >/dev/null 2>&1; then
  echo "✓"
  # Check user properties
  user_info=$(getent passwd axonops)
  echo "  └─ Home: $(echo $user_info | cut -d: -f6)"
  echo "  └─ Shell: $(echo $user_info | cut -d: -f7)"
else
  echo "✗ FAILED"
  exit 1
fi

# Check AxonOps group
echo -n "Checking axonops group... "
if getent group axonops >/dev/null 2>&1; then
  echo "✓"
else
  echo "✗ FAILED"
  exit 1
fi

# Check common directories
echo ""
echo "==== Directory Structure ===="
for dir in /etc/axonops /var/log/axonops /var/lib/axonops /opt/axonops; do
  echo -n "Checking $dir... "
  if [ -d "$dir" ]; then
    echo "✓"
    # Check ownership
    owner=$(stat -c %U "$dir" 2>/dev/null || stat -f %Su "$dir" 2>/dev/null)
    group=$(stat -c %G "$dir" 2>/dev/null || stat -f %Sg "$dir" 2>/dev/null)
    echo "  └─ Owner: $owner:$group"
  else
    echo "✗ FAILED"
    exit 1
  fi
done

# Check system settings
echo ""
echo "==== System Configuration ===="
echo -n "Checking sysctl settings... "
if [ -f /etc/sysctl.d/99-cassandra.conf ] || [ -f /etc/sysctl.d/99-axonops.conf ]; then
  echo "✓ configured"
  echo -n "  └─ vm.max_map_count: "
  max_map_count=$(sysctl -n vm.max_map_count 2>/dev/null || echo "unknown")
  echo "$max_map_count"
else
  echo "- using defaults"
fi

echo -n "Checking limits configuration... "
if [ -f /etc/security/limits.d/cassandra.conf ] || [ -f /etc/security/limits.d/axonops.conf ]; then
  echo "✓ configured"
else
  echo "- using defaults"
fi

# Check package manager setup
echo ""
echo "==== Package Management ===="
echo -n "Checking package manager... "
if command -v apt-get >/dev/null 2>&1; then
  echo "✓ apt (Debian/Ubuntu)"
  # Check for any AxonOps repos
  if [ -f /etc/apt/sources.list.d/axonops.list ]; then
    echo "  └─ AxonOps repository: configured"
  else
    echo "  └─ AxonOps repository: not configured"
  fi
elif command -v yum >/dev/null 2>&1; then
  echo "✓ yum (RHEL/CentOS)"
  if [ -f /etc/yum.repos.d/axonops.repo ]; then
    echo "  └─ AxonOps repository: configured"
  else
    echo "  └─ AxonOps repository: not configured"
  fi
else
  echo "✗ unsupported package manager"
fi

# Check what components are enabled (from attributes)
echo ""
echo "==== Component Status ===="
echo "Based on node attributes, the following should be enabled:"
echo "  - Java: ✓ (always installed)"
echo "  - Common: ✓ (always configured)"
echo "  - Agent: check with 'make verify-agent'"
echo "  - Server: check with 'make test-server'"
echo "  - Dashboard: check with 'make test-dashboard'"
echo ""
echo "Note: The default recipe only sets up prerequisites."
echo "      Other components require their specific recipes."

echo ""
echo "=== Default recipe verification complete! ==="