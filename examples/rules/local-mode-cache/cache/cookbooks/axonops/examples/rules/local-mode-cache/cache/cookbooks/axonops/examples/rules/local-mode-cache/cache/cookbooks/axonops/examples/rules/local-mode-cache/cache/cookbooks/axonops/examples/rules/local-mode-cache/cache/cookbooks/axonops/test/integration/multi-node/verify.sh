#!/bin/bash
# Multi-node deployment verification
# Tests that AxonOps can monitor a separate Cassandra cluster

set -e

echo "=== Multi-Node AxonOps Deployment Verification ==="
echo ""
echo "This test verifies:"
echo "  - VM1: AxonOps Server + Dashboard + Storage (Elasticsearch + Cassandra)"
echo "  - VM2: Apache Cassandra 5.0.4 application cluster with AxonOps Agent"
echo ""

# Since we can't directly access the other VM from this script,
# we'll verify what we can on this node and document manual verification steps

echo "=== Local Node Verification ==="

# Check what role this node has
if [ -f /etc/axonops/axon-server.yml ]; then
    echo "This is the AxonOps Server node"
    
    # Verify AxonOps Server
    echo -n "Checking AxonOps Server... "
    if [ -f /usr/bin/axon-server ]; then
        echo "✓"
    else
        echo "✗ FAILED"
        exit 1
    fi
    
    # Verify Dashboard
    echo -n "Checking AxonOps Dashboard... "
    if [ -f /usr/bin/axon-dash ]; then
        echo "✓"
    else
        echo "✗ FAILED"
        exit 1
    fi
    
    # Verify Elasticsearch
    echo -n "Checking AxonOps Search (Elasticsearch)... "
    if systemctl is-active --quiet axonops-search; then
        echo "✓"
    else
        echo "✗ FAILED"
        exit 1
    fi
    
    # Verify internal Cassandra
    echo -n "Checking AxonOps Data (internal Cassandra)... "
    if [ -f /etc/axonops-data/cassandra.yaml ]; then
        echo "✓"
    else
        echo "✗ FAILED"
        exit 1
    fi
    
elif [ -f /etc/cassandra/cassandra.yaml ] && [ -f /etc/axonops/axon-agent.yml ]; then
    echo "This is the Application Cassandra node"
    
    # Verify Cassandra
    echo -n "Checking Apache Cassandra 5.0... "
    if [ -f /opt/cassandra/bin/cassandra ] || [ -f /usr/bin/cassandra ]; then
        echo "✓"
        
        # Check version
        if command -v cassandra >/dev/null 2>&1; then
            cassandra -v 2>&1 | grep -E "5\.0\.[0-9]+" || echo "  Version check failed"
        fi
    else
        echo "✗ FAILED"
        exit 1
    fi
    
    # Verify AxonOps Agent
    echo -n "Checking AxonOps Agent... "
    if [ -f /usr/bin/axon-agent ]; then
        echo "✓"
        
        # Check agent config points to server
        echo -n "  Checking agent configuration... "
        if grep -q "server:" /etc/axonops/axon-agent.yml; then
            echo "✓"
            grep "hosts:" /etc/axonops/axon-agent.yml | head -1
        else
            echo "✗ No server configured"
        fi
    else
        echo "✗ FAILED"
        exit 1
    fi
    
    # Check Cassandra is running
    echo -n "Checking Cassandra service... "
    if systemctl is-active --quiet cassandra; then
        echo "✓"
    else
        echo "✗ Service not running"
    fi
    
else
    echo "ERROR: Cannot determine node role!"
    echo "Expected either:"
    echo "  - AxonOps Server node (with /etc/axonops/axon-server.yml)"
    echo "  - Cassandra node (with /etc/cassandra/cassandra.yaml and /etc/axonops/axon-agent.yml)"
    exit 1
fi

echo ""
echo "=== Manual Verification Steps ==="
echo ""
echo "To fully verify the multi-node deployment:"
echo ""
echo "1. On the AxonOps Server node:"
echo "   - Check API: curl http://<server-ip>:8080/api/v1/health"
echo "   - Check Dashboard: http://<server-ip>:3000"
echo "   - Check agent connections: curl http://<server-ip>:8080/api/v1/agents"
echo ""
echo "2. On the Cassandra node:"
echo "   - Verify agent connection: tail -f /var/log/axonops/agent.log"
echo "   - Check metrics flow: curl http://<server-ip>:8080/api/v1/metrics/nodes"
echo ""
echo "3. Cross-node verification:"
echo "   - From Cassandra node: telnet <server-ip> 8080"
echo "   - From Server node: telnet <cassandra-ip> 9042"
echo ""

echo "=== Test Status ==="
echo "✅ Local node verification completed"
echo "⚠️  Multi-node connectivity requires manual verification"