#!/bin/bash

# Script to run integration tests with either Docker or Podman

set -e

echo "==================================================="
echo "AxonOps Cookbook - Container Integration Tests"
echo "==================================================="

# Detect container runtime
if command -v podman &> /dev/null; then
    CONTAINER_BINARY="podman"
    echo "✅ Found Podman: $(podman --version)"
    
    # Check if podman-docker compatibility package is installed
    if ! command -v docker &> /dev/null; then
        echo ""
        echo "⚠️  Warning: 'docker' command not found."
        echo "For best compatibility, install podman-docker package:"
        echo "  brew install podman-docker  # macOS"
        echo "  sudo dnf install podman-docker  # Fedora/RHEL"
        echo ""
        echo "Or create an alias:"
        echo "  alias docker=podman"
        echo ""
    fi
elif command -v docker &> /dev/null; then
    CONTAINER_BINARY="docker"
    echo "✅ Found Docker: $(docker --version)"
else
    echo "❌ Neither Docker nor Podman found!"
    echo "Please install one of them:"
    echo "  - Docker Desktop: https://www.docker.com/products/docker-desktop"
    echo "  - Podman: brew install podman"
    exit 1
fi

# Check if container service is running
echo -e "\nChecking container service..."
if $CONTAINER_BINARY info &> /dev/null; then
    echo "✅ Container service is running"
else
    echo "❌ Container service is not running!"
    if [ "$CONTAINER_BINARY" = "podman" ]; then
        echo "Start Podman machine with: podman machine start"
    else
        echo "Start Docker Desktop or Docker daemon"
    fi
    exit 1
fi

# Export for kitchen to use
export CONTAINER_BINARY
export KITCHEN_YAML=".kitchen.container.yml"

# Show available test suites
echo -e "\nAvailable test suites:"
kitchen list

# Function to run a specific test
run_test() {
    local suite=$1
    echo -e "\n==================================================="
    echo "Running test: $suite"
    echo "==================================================="
    
    # For Podman, we might need to use --root for privileged containers
    if [ "$CONTAINER_BINARY" = "podman" ]; then
        export DOCKER_HOST="unix://$(podman info --format '{{.Host.RemoteSocket.Path}}')"
    fi
    
    kitchen test "$suite" --destroy=always
}

# Main menu
echo -e "\nWhat would you like to test?"
echo "1. Agent installation (quick test)"
echo "2. Server installation"
echo "3. All tests"
echo "4. List available tests only"
echo "5. Exit"

read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        run_test "agent-ubuntu-2204"
        ;;
    2)
        run_test "server-ubuntu-2204"
        ;;
    3)
        echo "Running all tests..."
        kitchen test --destroy=always
        ;;
    4)
        echo "Available tests listed above."
        ;;
    5)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice. Running agent test as default..."
        run_test "agent-ubuntu-2204"
        ;;
esac

echo -e "\n✅ Testing completed!"