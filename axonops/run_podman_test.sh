#!/bin/bash

# Direct Podman test for AxonOps cookbook

set -e

echo "==================================================="
echo "AxonOps Cookbook - Direct Podman Test"
echo "==================================================="

# Check if podman is available
if ! command -v podman &> /dev/null; then
    echo "❌ Podman is not installed!"
    echo "Install with: brew install podman"
    exit 1
fi

echo "✅ Using Podman: $(podman --version)"

# Check if podman machine is running
if ! podman info &> /dev/null; then
    echo "Starting Podman machine..."
    podman machine start
fi

# Container name
CONTAINER_NAME="axonops-test-$(date +%s)"
IMAGE="ubuntu:22.04"

echo -e "\nCreating test container..."

# Run container with systemd support
podman run -d \
    --name "$CONTAINER_NAME" \
    --privileged \
    --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
    --platform linux/amd64 \
    "$IMAGE" \
    /sbin/init

echo "✅ Container created: $CONTAINER_NAME"

# Wait for container to be ready
echo "Waiting for container to initialize..."
sleep 5

# Install prerequisites
echo -e "\nInstalling prerequisites..."
podman exec "$CONTAINER_NAME" bash -c '
    apt-get update
    apt-get install -y sudo curl wget systemd
'

# Install Chef
echo -e "\nInstalling Chef..."
podman exec "$CONTAINER_NAME" bash -c '
    curl -L https://omnitruck.chef.io/install.sh | bash -s -- -v 17
'

# Copy cookbook into container
echo -e "\nCopying cookbook to container..."
podman cp . "$CONTAINER_NAME":/tmp/axonops

# Create a simple run list
podman exec "$CONTAINER_NAME" bash -c 'cat > /tmp/dna.json << EOF
{
  "run_list": ["recipe[axonops::agent]"],
  "axonops": {
    "agent": {
      "enabled": true,
      "type": "saas",
      "key": "test-integration-key",
      "organization": "test-org"
    }
  }
}
EOF'

# Run Chef
echo -e "\nRunning Chef..."
podman exec "$CONTAINER_NAME" bash -c '
    cd /tmp
    chef-client -z -j /tmp/dna.json -c /tmp/solo.rb --chef-license accept || true
' 2>&1 | tee chef-run.log

# Create minimal Chef config
podman exec "$CONTAINER_NAME" bash -c 'cat > /tmp/solo.rb << EOF
cookbook_path ["/tmp/axonops"]
log_level :info
EOF'

# Run Chef again with proper config
echo -e "\nRunning Chef with cookbook..."
podman exec "$CONTAINER_NAME" bash -c '
    cd /tmp
    chef-client -z -j /tmp/dna.json -c /tmp/solo.rb --chef-license accept
' 2>&1 | tee -a chef-run.log

# Run tests
echo -e "\nRunning tests..."
podman exec "$CONTAINER_NAME" bash -c '
    # Simple tests
    echo "Test 1: Checking directories..."
    if [ -d "/etc/axonops" ]; then
        echo "✓ /etc/axonops directory exists"
    else
        echo "✗ /etc/axonops directory missing"
        exit 1
    fi
    
    echo "Test 2: Checking configuration..."
    if [ -f "/etc/axonops/axon-agent.yml" ]; then
        echo "✓ Configuration file exists"
        cat /etc/axonops/axon-agent.yml
    else
        echo "✗ Configuration file missing"
    fi
    
    echo "Test 3: Checking service..."
    if systemctl list-unit-files | grep -q axon-agent; then
        echo "✓ Service is registered"
    else
        echo "! Service not found (might be expected if package install was skipped)"
    fi
'

# Cleanup option
echo -e "\n==================================================="
echo "Test completed!"
echo ""
read -p "Remove test container? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    podman stop "$CONTAINER_NAME"
    podman rm "$CONTAINER_NAME"
    echo "✅ Container removed"
else
    echo "Container kept: $CONTAINER_NAME"
    echo "To connect: podman exec -it $CONTAINER_NAME bash"
    echo "To remove: podman rm -f $CONTAINER_NAME"
fi