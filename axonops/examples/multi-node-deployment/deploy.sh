#!/bin/bash
#
# Multi-node AxonOps deployment helper script
# This script helps deploy a realistic AxonOps monitoring setup
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
COOKBOOK_ROOT="../../"
KITCHEN_FILE=".kitchen.multi-node.yml"

echo -e "${GREEN}=== AxonOps Multi-Node Deployment ===${NC}"
echo ""
echo "This will create:"
echo "  - VM1: AxonOps Server (Dashboard, API, Storage)"
echo "  - VM2: Apache Cassandra 5.0 with AxonOps Agent"
echo ""
echo "Requirements:"
echo "  - 6GB+ RAM available"
echo "  - VirtualBox installed"
echo "  - Vagrant installed"
echo ""

# Check dependencies
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}✗ $1 is not installed${NC}"
        return 1
    else
        echo -e "${GREEN}✓ $1 is installed${NC}"
        return 0
    fi
}

echo "Checking dependencies..."
DEPS_OK=true
check_dependency "vagrant" || DEPS_OK=false
check_dependency "VBoxManage" || DEPS_OK=false
check_dependency "bundle" || DEPS_OK=false

if [ "$DEPS_OK" = false ]; then
    echo -e "${RED}Please install missing dependencies before continuing.${NC}"
    exit 1
fi

# Parse command line arguments
COMMAND=${1:-help}

case $COMMAND in
    up|start|deploy)
        echo -e "${GREEN}Starting multi-node deployment...${NC}"
        cd $COOKBOOK_ROOT
        KITCHEN_YAML=$KITCHEN_FILE bundle exec kitchen create
        echo -e "${YELLOW}VMs created. Converging...${NC}"
        KITCHEN_YAML=$KITCHEN_FILE bundle exec kitchen converge
        echo -e "${GREEN}Deployment complete!${NC}"
        echo ""
        echo "Access points:"
        echo "  - AxonOps Dashboard: http://192.168.56.10:3000"
        echo "  - AxonOps API: http://192.168.56.10:8080"
        echo "  - Cassandra: 192.168.56.20:9042"
        echo ""
        echo "To verify: ./deploy.sh verify"
        echo "To SSH: ./deploy.sh ssh-server or ./deploy.sh ssh-cassandra"
        ;;
        
    verify|test)
        echo -e "${GREEN}Verifying deployment...${NC}"
        cd $COOKBOOK_ROOT
        KITCHEN_YAML=$KITCHEN_FILE bundle exec kitchen verify
        ;;
        
    ssh-server)
        echo -e "${GREEN}Connecting to AxonOps server...${NC}"
        cd $COOKBOOK_ROOT
        KITCHEN_YAML=$KITCHEN_FILE bundle exec kitchen login axonops-server-ubuntu-2204
        ;;
        
    ssh-cassandra|ssh-app)
        echo -e "${GREEN}Connecting to Cassandra application node...${NC}"
        cd $COOKBOOK_ROOT
        KITCHEN_YAML=$KITCHEN_FILE bundle exec kitchen login cassandra-app-ubuntu-2204
        ;;
        
    status)
        echo -e "${GREEN}Checking status...${NC}"
        cd $COOKBOOK_ROOT
        KITCHEN_YAML=$KITCHEN_FILE bundle exec kitchen list
        ;;
        
    stop|halt)
        echo -e "${YELLOW}Stopping VMs (preserving data)...${NC}"
        cd $COOKBOOK_ROOT/.kitchen/kitchen-vagrant/axonops-server-ubuntu-2204 2>/dev/null && vagrant halt || true
        cd $COOKBOOK_ROOT/.kitchen/kitchen-vagrant/cassandra-app-ubuntu-2204 2>/dev/null && vagrant halt || true
        echo "VMs stopped. Use './deploy.sh start' to resume."
        ;;
        
    destroy|cleanup)
        echo -e "${RED}Destroying VMs and cleaning up...${NC}"
        read -p "Are you sure? This will delete all data. [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd $COOKBOOK_ROOT
            KITCHEN_YAML=$KITCHEN_FILE bundle exec kitchen destroy -c
            echo "Cleanup complete."
        else
            echo "Cancelled."
        fi
        ;;
        
    logs-server)
        echo -e "${GREEN}Showing AxonOps server logs...${NC}"
        cd $COOKBOOK_ROOT
        KITCHEN_YAML=$KITCHEN_FILE bundle exec kitchen login axonops-server-ubuntu-2204 -c "sudo journalctl -u axon-server -u axon-dash -f"
        ;;
        
    logs-agent)
        echo -e "${GREEN}Showing AxonOps agent logs...${NC}"
        cd $COOKBOOK_ROOT
        KITCHEN_YAML=$KITCHEN_FILE bundle exec kitchen login cassandra-app-ubuntu-2204 -c "sudo tail -f /var/log/axonops/agent.log"
        ;;
        
    help|*)
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  up, start, deploy  - Create and configure both VMs"
        echo "  verify, test       - Run verification tests"
        echo "  ssh-server         - SSH into AxonOps server VM"
        echo "  ssh-cassandra      - SSH into Cassandra app VM"
        echo "  status             - Show VM status"
        echo "  stop, halt         - Stop VMs (preserves data)"
        echo "  destroy, cleanup   - Destroy VMs and clean up"
        echo "  logs-server        - Tail AxonOps server logs"
        echo "  logs-agent         - Tail AxonOps agent logs"
        echo "  help               - Show this help"
        echo ""
        echo "Example workflow:"
        echo "  $0 deploy          # Create and configure VMs"
        echo "  $0 verify          # Run tests"
        echo "  $0 ssh-server      # Connect to server"
        echo "  $0 destroy         # Clean up when done"
        ;;
esac