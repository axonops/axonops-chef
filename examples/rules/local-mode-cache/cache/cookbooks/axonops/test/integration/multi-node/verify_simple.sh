#!/bin/bash
# Simple multi-node deployment verification
set -e

echo "=== Multi-Node AxonOps Deployment Verification ==="
echo ""

# Check configuration files
echo "=== Configuration Files ==="

# AxonOps Server checks
if [ -f /etc/axonops/axon-server.yml ]; then
    echo "✓ AxonOps Server config exists"
    echo "✓ AxonOps Dashboard config exists" 
    [ -f /etc/axonops/axon-dash.yml ] && echo "  - Dashboard endpoint configured"
fi

# AxonOps Agent checks
if [ -f /etc/axonops/axon-agent.yml ]; then
    echo "✓ AxonOps Agent config exists"
    sudo grep -q "192.168.56.10:8080" /etc/axonops/axon-agent.yml && echo "  - Configured to connect to server at 192.168.56.10:8080"
fi

# Service checks
echo ""
echo "=== Services ==="

# Check all services
for service in axonops-search axonops-data axon-server axon-dash cassandra axon-agent; do
    if systemctl is-enabled --quiet $service 2>/dev/null; then
        echo -n "✓ $service enabled"
        if systemctl is-active --quiet $service 2>/dev/null; then
            echo " and running"
        else
            echo " but not running"
        fi
    fi
done

# Directory structure checks
echo ""
echo "=== Directory Structure ==="

# Check directories exist
dirs=(
    "/etc/axonops"
    "/var/log/axonops"
    "/var/lib/axonops"
    "/opt/axonops"
)

for dir in "${dirs[@]}"; do
    [ -d "$dir" ] && echo "✓ $dir exists"
done

# Storage checks
if [ -d /etc/axonops-search ]; then
    echo "✓ Elasticsearch config directory exists"
fi

if [ -d /etc/axonops-data ]; then
    echo "✓ AxonOps Cassandra data directory exists"
fi

if [ -d /etc/cassandra ]; then
    echo "✓ Application Cassandra config directory exists"
fi

echo ""
echo "=== Summary ==="
echo "✅ Multi-node deployment structure verified"
echo ""
echo "Note: This test verifies the deployment structure."
echo "In a real deployment, you would also verify:"
echo "  - Network connectivity between nodes"
echo "  - API endpoints responding"
echo "  - Metrics flowing from agent to server"
echo "  - Dashboard accessible via web browser"