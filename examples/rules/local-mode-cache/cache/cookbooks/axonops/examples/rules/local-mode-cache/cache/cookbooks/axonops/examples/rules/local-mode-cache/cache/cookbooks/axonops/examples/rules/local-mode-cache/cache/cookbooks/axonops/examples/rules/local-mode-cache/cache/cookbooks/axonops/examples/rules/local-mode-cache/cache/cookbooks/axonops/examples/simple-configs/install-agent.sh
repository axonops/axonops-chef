#!/bin/bash
# Simple AxonOps Agent Installation Script
# Usage: ./install-agent.sh ORG_NAME ORG_KEY CLUSTER_NAME

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -ne 3 ]; then
    echo -e "${RED}Error: Missing arguments${NC}"
    echo "Usage: $0 ORG_NAME ORG_KEY CLUSTER_NAME"
    echo "Example: $0 my-company abc123xyz789 production-cluster"
    exit 1
fi

ORG_NAME=$1
ORG_KEY=$2
CLUSTER_NAME=$3

echo -e "${GREEN}Starting AxonOps Agent Installation...${NC}"

# Detect OS
if [ -f /etc/debian_version ]; then
    OS="debian"
    CHEF_URL="https://packages.chef.io/files/stable/chef/18.2.7/ubuntu/22.04/chef_18.2.7-1_amd64.deb"
    CHEF_FILE="chef.deb"
elif [ -f /etc/redhat-release ]; then
    OS="redhat"
    CHEF_URL="https://packages.chef.io/files/stable/chef/18.2.7/el/8/chef-18.2.7-1.el8.x86_64.rpm"
    CHEF_FILE="chef.rpm"
else
    echo -e "${RED}Error: Unsupported operating system${NC}"
    exit 1
fi

# Step 1: Install Chef if not present
if ! command -v chef-client &> /dev/null; then
    echo -e "${YELLOW}Installing Chef...${NC}"
    wget -q $CHEF_URL -O /tmp/$CHEF_FILE
    
    if [ "$OS" = "debian" ]; then
        sudo dpkg -i /tmp/$CHEF_FILE
    else
        sudo rpm -Uvh /tmp/$CHEF_FILE
    fi
    rm /tmp/$CHEF_FILE
else
    echo -e "${GREEN}Chef already installed${NC}"
fi

# Step 2: Create Chef directories
echo -e "${YELLOW}Setting up Chef directories...${NC}"
sudo mkdir -p /etc/chef/cookbooks
sudo mkdir -p /var/chef/cache
sudo mkdir -p /var/chef/backup

# Step 3: Download cookbook
echo -e "${YELLOW}Downloading AxonOps cookbook...${NC}"
cd /tmp
rm -rf axonops-chef
git clone -q https://github.com/axonops/axonops-chef.git
sudo rm -rf /etc/chef/cookbooks/axonops
sudo cp -r axonops-chef/axonops /etc/chef/cookbooks/
rm -rf axonops-chef

# Step 4: Create Chef configuration
echo -e "${YELLOW}Creating Chef configuration...${NC}"
sudo tee /etc/chef/solo.rb > /dev/null <<EOF
cookbook_path "/etc/chef/cookbooks"
json_attribs "/etc/chef/node.json"
log_level :info
log_location STDOUT
file_cache_path "/var/chef/cache"
file_backup_path "/var/chef/backup"
EOF

# Step 5: Create node configuration
echo -e "${YELLOW}Creating AxonOps configuration...${NC}"
sudo tee /etc/chef/node.json > /dev/null <<EOF
{
  "run_list": ["recipe[axonops::agent]"],
  "axonops": {
    "agent": {
      "org": "$ORG_NAME",
      "org_key": "$ORG_KEY",
      "cluster_name": "$CLUSTER_NAME"
    }
  }
}
EOF

# Step 6: Run Chef
echo -e "${YELLOW}Installing AxonOps Agent...${NC}"
sudo chef-client --local-mode --config /etc/chef/solo.rb

# Step 7: Verify installation
echo -e "${YELLOW}Verifying installation...${NC}"
if sudo systemctl is-active --quiet axon-agent; then
    echo -e "${GREEN}✓ AxonOps Agent is running${NC}"
    echo -e "${GREEN}✓ Installation complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Check your AxonOps dashboard - your cluster should appear in a few minutes"
    echo "2. View agent logs: sudo tail -f /var/log/axonops/agent.log"
    echo "3. Check agent status: sudo systemctl status axon-agent"
else
    echo -e "${RED}✗ Agent is not running${NC}"
    echo "Check logs: sudo journalctl -u axon-agent -n 50"
    exit 1
fi