#!/bin/bash

# Simple shell-based tests for AxonOps agent
set -e

echo "Starting AxonOps Agent integration tests..."

# Test 1: Check if the agent binary exists (test mode)
echo "Test 1: Checking if AxonOps agent binary exists..."
if [ -f "/usr/bin/axon-agent" ]; then
    echo "✓ AxonOps agent binary exists"
    # Check if it's executable
    if [ -x "/usr/bin/axon-agent" ]; then
        echo "✓ AxonOps agent binary is executable"
    fi
else
    echo "✗ AxonOps agent binary does NOT exist"
    exit 1
fi

# Test 2: Check if the agent service exists
echo "Test 2: Checking if AxonOps agent service exists..."
if systemctl list-unit-files | grep -q axon-agent; then
    echo "✓ AxonOps agent service exists"
else
    echo "✗ AxonOps agent service does NOT exist"
    exit 1
fi

# Test 3: Check if the configuration directory exists
echo "Test 3: Checking configuration directory..."
if [ -d "/etc/axonops" ]; then
    echo "✓ Configuration directory exists"
else
    echo "✗ Configuration directory does NOT exist"
    exit 1
fi

# Test 4: Check if the configuration file exists
echo "Test 4: Checking configuration file..."
if [ -f "/etc/axonops/axon-agent.yml" ]; then
    echo "✓ Configuration file exists"
    
    # Check if the configuration contains expected values
    if grep -q "test-agent-key" /etc/axonops/axon-agent.yml; then
        echo "✓ API key is configured"
    else
        echo "✗ API key is NOT configured"
        exit 1
    fi
else
    echo "✗ Configuration file does NOT exist"
    exit 1
fi

# Test 5: Check if Cassandra detection worked
echo "Test 5: Checking Cassandra detection..."
if [ -f "/etc/axonops/.cassandra_detected" ]; then
    echo "✓ Cassandra detection completed"
    cat /etc/axonops/.cassandra_detected
else
    echo "✓ No existing Cassandra detected (as expected for test environment)"
fi

echo ""
echo "All tests passed successfully!"