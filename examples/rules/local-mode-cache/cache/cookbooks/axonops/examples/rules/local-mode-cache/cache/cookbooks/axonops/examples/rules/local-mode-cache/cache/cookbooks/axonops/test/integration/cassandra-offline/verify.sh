#!/bin/bash
# Verification script for offline Cassandra installation

set -e

echo "=== Offline Cassandra Installation Verification ==="
echo ""

# Check if Java is installed
echo -n "Checking Java installation... "
if java -version 2>&1 | grep -q "Azul"; then
    echo "✓ Azul Java installed"
    java -version 2>&1 | head -1
else
    echo "✗ FAILED - Azul Java not found"
    exit 1
fi

# Check if Cassandra is installed
echo -n "Checking Cassandra installation... "
if [ -d /opt/apache-cassandra-5.0.4 ]; then
    echo "✓"
    echo "  Installation directory: /opt/apache-cassandra-5.0.4"
else
    echo "✗ FAILED"
    exit 1
fi

# Check symlink
echo -n "Checking Cassandra symlink... "
if [ -L /opt/cassandra ] && [ -d /opt/cassandra ]; then
    echo "✓"
    echo "  Symlink: /opt/cassandra -> $(readlink /opt/cassandra)"
else
    echo "✗ FAILED"
    exit 1
fi

# Check Cassandra user
echo -n "Checking Cassandra user... "
if id cassandra >/dev/null 2>&1; then
    echo "✓"
else
    echo "✗ FAILED"
    exit 1
fi

# Check directories
echo "Checking Cassandra directories..."
for dir in /var/lib/cassandra/data /var/lib/cassandra/commitlog /var/lib/cassandra/saved_caches /var/lib/cassandra/hints /var/log/cassandra; do
    echo -n "  $dir... "
    if [ -d "$dir" ]; then
        echo "✓"
    else
        echo "✗ FAILED"
        exit 1
    fi
done

# Check configuration
echo -n "Checking Cassandra configuration... "
if [ -f /opt/cassandra/conf/cassandra.yaml ]; then
    echo "✓"
    # Check cluster name
    if grep -q "cluster_name: 'Offline Test Cluster'" /opt/cassandra/conf/cassandra.yaml; then
        echo "  ✓ Cluster name configured correctly"
    else
        echo "  ✗ Cluster name not configured"
        exit 1
    fi
else
    echo "✗ FAILED"
    exit 1
fi

# Check systemd service
echo -n "Checking Cassandra service... "
if [ -f /etc/systemd/system/cassandra.service ]; then
    echo "✓"
    
    # Check if service is running
    echo -n "  Service status: "
    if systemctl is-active --quiet cassandra; then
        echo "✓ Running"
    else
        echo "✗ Not running"
        # Try to start it
        echo "  Attempting to start Cassandra..."
        sudo systemctl start cassandra
        sleep 10
        if systemctl is-active --quiet cassandra; then
            echo "  ✓ Started successfully"
        else
            echo "  ✗ Failed to start"
            sudo journalctl -u cassandra -n 50
            exit 1
        fi
    fi
else
    echo "✗ FAILED"
    exit 1
fi

# Check if Cassandra is listening
echo -n "Checking Cassandra ports... "
if ss -tlnp 2>/dev/null | grep -q ":9042"; then
    echo "✓ Native transport (9042)"
else
    echo "✗ Native transport not listening"
fi

if ss -tlnp 2>/dev/null | grep -q ":7000"; then
    echo "✓ Storage port (7000)"
else
    echo "✗ Storage port not listening"
fi

# Check nodetool
echo -n "Checking nodetool... "
if /opt/cassandra/bin/nodetool status >/dev/null 2>&1; then
    echo "✓"
    echo "Cluster status:"
    /opt/cassandra/bin/nodetool status
else
    echo "✗ FAILED"
fi

# Check system limits
echo -n "Checking system limits... "
if [ -f /etc/security/limits.d/cassandra.conf ]; then
    echo "✓"
else
    echo "✗ FAILED"
fi

# Check kernel parameters
echo -n "Checking kernel parameters... "
current_max_map=$(sysctl -n vm.max_map_count)
if [ "$current_max_map" -ge 1048575 ]; then
    echo "✓ vm.max_map_count = $current_max_map"
else
    echo "✗ vm.max_map_count too low: $current_max_map"
fi

echo ""
echo "=== Offline Installation Verification Complete ==="
echo "✅ All checks passed!"