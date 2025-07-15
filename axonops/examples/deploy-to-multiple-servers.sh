#!/bin/bash
# Deploy AxonOps Agent to Multiple Servers
# This script shows how to apply Chef cookbook to multiple servers
# (Similar to how Ansible uses inventory)

# Configuration
ORG_NAME="your-org-name"
ORG_KEY="your-org-key"
CLUSTER_NAME="production"

# List your servers here (like Ansible inventory)
SERVERS=(
    "cassandra1.example.com"
    "cassandra2.example.com"
    "cassandra3.example.com"
)

# Or read from a file
# SERVERS=($(cat servers.txt))

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Deploying AxonOps Agent to ${#SERVERS[@]} servers...${NC}"

# Function to deploy to a single server
deploy_to_server() {
    local server=$1
    echo -e "\n${YELLOW}Deploying to $server...${NC}"
    
    # Create the configuration
    cat > /tmp/node.json <<EOF
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

    # Copy cookbook and configuration to server
    echo "  - Copying cookbook..."
    ssh $server "sudo mkdir -p /etc/chef/cookbooks" 2>/dev/null
    scp -r ../axonops $server:/tmp/ >/dev/null 2>&1
    ssh $server "sudo rm -rf /etc/chef/cookbooks/axonops && sudo mv /tmp/axonops /etc/chef/cookbooks/" 2>/dev/null
    
    echo "  - Copying configuration..."
    scp /tmp/node.json $server:/tmp/ >/dev/null 2>&1
    ssh $server "sudo mkdir -p /etc/chef && sudo mv /tmp/node.json /etc/chef/" 2>/dev/null
    
    # Create Chef solo configuration
    ssh $server "sudo tee /etc/chef/solo.rb > /dev/null" <<'EOF'
cookbook_path "/etc/chef/cookbooks"
json_attribs "/etc/chef/node.json"
log_level :info
log_location STDOUT
EOF

    # Run Chef
    echo "  - Running Chef..."
    if ssh $server "sudo chef-client --local-mode --config /etc/chef/solo.rb" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Success${NC}"
        return 0
    else
        echo -e "  ${RED}✗ Failed${NC}"
        return 1
    fi
}

# Deploy to all servers
SUCCESS_COUNT=0
FAILED_SERVERS=()

for server in "${SERVERS[@]}"; do
    if deploy_to_server "$server"; then
        ((SUCCESS_COUNT++))
    else
        FAILED_SERVERS+=("$server")
    fi
done

# Summary
echo -e "\n${GREEN}Deployment Complete!${NC}"
echo "  - Successful: $SUCCESS_COUNT/${#SERVERS[@]}"

if [ ${#FAILED_SERVERS[@]} -gt 0 ]; then
    echo -e "  - ${RED}Failed servers:${NC}"
    for server in "${FAILED_SERVERS[@]}"; do
        echo "    - $server"
    done
fi

# Cleanup
rm -f /tmp/node.json

echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Check AxonOps dashboard - clusters should appear soon"
echo "2. Verify on each server: ssh <server> 'sudo systemctl status axon-agent'"