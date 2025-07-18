#!/bin/bash
#
# Verification script for multi-node deployment with real AxonOps packages
#

set -e

echo "===== Multi-Node Real Package Verification ====="
echo ""

# Function to check if a service is installed (even if not running)
check_service_installed() {
    local service=$1
    if systemctl list-unit-files | grep -q "^${service}.service"; then
        echo "✓ ${service} service is installed"
        return 0
    else
        echo "✗ ${service} service is NOT installed"
        return 1
    fi
}

# Function to check if a package is installed
check_package_installed() {
    local package=$1
    if dpkg -l | grep -q "^ii  ${package} "; then
        echo "✓ ${package} is installed"
        return 0
    else
        echo "✗ ${package} is NOT installed"
        return 1
    fi
}

# Check hostname to determine which node we're on
HOSTNAME=$(hostname)
echo "Running on: $HOSTNAME"
echo ""

if [[ "$HOSTNAME" == *"axonops-server"* ]]; then
    echo "=== AxonOps Server Node Checks ==="
    
    # Check packages
    echo ""
    echo "Checking installed packages:"
    check_package_installed "axon-server"
    check_package_installed "axon-dash"
    
    # Check services (may not be running on ARM64)
    echo ""
    echo "Checking services:"
    check_service_installed "axon-server"
    check_service_installed "axon-dash"
    check_service_installed "elasticsearch"
    check_service_installed "axonops-data"
    
    # Check configuration files
    echo ""
    echo "Checking configuration files:"
    for config in /etc/axonops/axon-server.yml /etc/axonops/axon-dash.yml; do
        if [ -f "$config" ]; then
            echo "✓ $config exists"
            echo "  Owner: $(stat -c '%U:%G' $config)"
            echo "  Permissions: $(stat -c '%a' $config)"
        else
            echo "✗ $config missing"
        fi
    done
    
    # Check directories
    echo ""
    echo "Checking directories:"
    for dir in /var/log/axonops /var/lib/axonops /opt/axonops; do
        if [ -d "$dir" ]; then
            echo "✓ $dir exists (owner: $(stat -c '%U:%G' $dir))"
        else
            echo "✗ $dir missing"
        fi
    done
    
    # Check binaries (even if they can't run)
    echo ""
    echo "Checking binaries:"
    for binary in /usr/bin/axon-server /usr/bin/axon-dash; do
        if [ -f "$binary" ]; then
            echo "✓ $binary exists"
            # Try to get version (may fail on wrong architecture)
            if $binary --version 2>/dev/null; then
                echo "  Version: $($binary --version 2>&1 | head -1)"
            else
                echo "  Note: Binary may not be executable on this architecture"
            fi
        else
            echo "✗ $binary missing"
        fi
    done
    
elif [[ "$HOSTNAME" == *"cassandra-app"* ]]; then
    echo "=== Cassandra Application Node Checks ==="
    
    # Check packages
    echo ""
    echo "Checking installed packages:"
    check_package_installed "axon-agent"
    dpkg -l | grep -E "axon-cassandra.*-agent" && echo "✓ Java agent package found" || echo "✗ Java agent package NOT found"
    
    # Check service
    echo ""
    echo "Checking services:"
    check_service_installed "axon-agent"
    check_service_installed "cassandra"
    
    # Check configuration
    echo ""
    echo "Checking configuration files:"
    if [ -f "/etc/axonops/axon-agent.yml" ]; then
        echo "✓ /etc/axonops/axon-agent.yml exists"
        echo "  Configured server: $(grep -A1 'server:' /etc/axonops/axon-agent.yml | grep 'hosts:' | awk '{print $2}')"
    else
        echo "✗ /etc/axonops/axon-agent.yml missing"
    fi
    
    # Check Java agent integration
    echo ""
    echo "Checking Java agent integration:"
    CASS_JVM_OPTIONS="/opt/cassandra/conf/jvm-server.options"
    if [ -f "$CASS_JVM_OPTIONS" ]; then
        if grep -q "javaagent.*axon" "$CASS_JVM_OPTIONS"; then
            echo "✓ AxonOps Java agent configured in Cassandra"
            grep "javaagent.*axon" "$CASS_JVM_OPTIONS" | sed 's/^/  /'
        else
            echo "✗ AxonOps Java agent NOT configured in Cassandra"
        fi
    else
        echo "✗ Cassandra JVM options file not found"
    fi
    
    # Check if Cassandra is running
    echo ""
    echo "Checking Cassandra status:"
    if systemctl is-active cassandra >/dev/null 2>&1; then
        echo "✓ Cassandra is running"
        # Try to connect
        if command -v cqlsh >/dev/null 2>&1; then
            cqlsh -e "SELECT cluster_name FROM system.local;" 2>/dev/null && echo "✓ Can connect to Cassandra" || echo "✗ Cannot connect to Cassandra"
        fi
    else
        echo "✗ Cassandra is NOT running"
    fi
fi

echo ""
echo "===== Verification Complete ====="
echo ""
echo "Note: On ARM64 systems, AMD64 binaries may be installed but not runnable."
echo "This is expected behavior for cross-architecture testing."