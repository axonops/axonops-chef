#!/bin/bash
# Test runner script that works around bundler/vagrant conflicts

set -e

COOKBOOK_DIR="/Users/johnny/Development/axonops-chef/axonops"
KITCHEN_DIR="$COOKBOOK_DIR/.kitchen/kitchen-vagrant"
VAGRANT="/usr/local/bin/vagrant"

# Function to create and test a suite
run_test() {
    local suite=$1
    local suite_dir="$KITCHEN_DIR/${suite}-ubuntu-2204"
    
    echo "==========================================="
    echo "Testing: $suite"
    echo "==========================================="
    
    # Create directory if it doesn't exist
    mkdir -p "$suite_dir"
    cd "$suite_dir"
    
    # Check if Vagrantfile exists, if not create it
    if [ ! -f "Vagrantfile" ]; then
        echo "Creating Vagrantfile for $suite..."
        
        # Get the run list and attributes from .kitchen.yml
        cat > Vagrantfile <<'EOF'
Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"
  config.vm.hostname = "SUITE-ubuntu-2204"
  
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 2
  end
  
  config.vm.provision "chef_solo" do |chef|
    chef.install = true
    chef.version = "17.10.0"
    chef.cookbooks_path = ["../../../", "../../../berks-cookbooks"]
    chef.run_list = RUN_LIST
    chef.json = ATTRIBUTES
  end
end
EOF
        
        # Replace SUITE placeholder with actual suite name
        sed -i '' "s/SUITE/$suite/g" Vagrantfile
        
        # Get run list and attributes based on suite
        case $suite in
            "default")
                sed -i '' 's/RUN_LIST/["recipe[axonops::default]"]/g' Vagrantfile
                sed -i '' 's/ATTRIBUTES/{}/g' Vagrantfile
                ;;
            "agent")
                sed -i '' 's/RUN_LIST/["recipe[axonops::agent_test]"]/g' Vagrantfile
                sed -i '' 's/ATTRIBUTES/{"axonops": {"agent": {"enabled": true, "type": "saas"}}}/g' Vagrantfile
                ;;
            "server")
                sed -i '' 's/RUN_LIST/["recipe[axonops::server_test]"]/g' Vagrantfile
                sed -i '' 's/ATTRIBUTES/{"axonops": {"server": {"enabled": true}}}/g' Vagrantfile
                ;;
            "dashboard")
                sed -i '' 's/RUN_LIST/["recipe[axonops::dashboard_test]"]/g' Vagrantfile
                sed -i '' 's/ATTRIBUTES/{"axonops": {"dash": {"enabled": true}}}/g' Vagrantfile
                ;;
            "cassandra")
                sed -i '' 's/RUN_LIST/["recipe[axonops::cassandra_test]"]/g' Vagrantfile
                sed -i '' 's/ATTRIBUTES/{"cassandra": {"install_method": "package"}}/g' Vagrantfile
                ;;
            "configure")
                sed -i '' 's/RUN_LIST/["recipe[axonops::configure_test]"]/g' Vagrantfile
                sed -i '' 's/ATTRIBUTES/{"axonops": {"configure_api": true}}/g' Vagrantfile
                ;;
            "offline")
                sed -i '' 's/RUN_LIST/["recipe[axonops::offline_test]"]/g' Vagrantfile
                sed -i '' 's/ATTRIBUTES/{"axonops": {"offline_install": true}}/g' Vagrantfile
                ;;
            "full-stack")
                sed -i '' 's/RUN_LIST/["recipe[axonops::full_stack_test]"]/g' Vagrantfile
                sed -i '' 's/ATTRIBUTES/{"axonops": {"agent": {"enabled": true}, "server": {"enabled": true}, "dash": {"enabled": true}}}/g' Vagrantfile
                ;;
        esac
    fi
    
    # Check if VM exists
    if $VAGRANT status --machine-readable | grep -q "state,running"; then
        echo "VM already running, destroying first..."
        $VAGRANT destroy -f
    fi
    
    # Create and provision VM
    echo "Creating VM..."
    $VAGRANT up --no-provision
    
    # Now we need to manually set up Chef and run it
    echo "Installing Chef..."
    $VAGRANT ssh -c "curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -v 17.10.0"
    
    # Copy cookbook files
    echo "Copying cookbook files..."
    $VAGRANT ssh -c "sudo mkdir -p /tmp/chef/cookbooks/axonops"
    cd "$COOKBOOK_DIR"
    tar -czf - --exclude='.kitchen' --exclude='.git' --exclude='test' . | $VAGRANT ssh -c "sudo tar -xzf - -C /tmp/chef/cookbooks/axonops"
    cd "$suite_dir"
    
    # Create Chef solo configuration
    $VAGRANT ssh -c "sudo tee /tmp/chef/solo.rb > /dev/null" <<'SOLOEOF'
cookbook_path '/tmp/chef/cookbooks'
json_attribs '/tmp/chef/node.json'
SOLOEOF
    
    # Create node attributes based on suite
    case $suite in
        "default")
            $VAGRANT ssh -c "sudo tee /tmp/chef/node.json > /dev/null" <<'EOF'
{
  "run_list": ["recipe[axonops::default]"]
}
EOF
            ;;
        "agent")
            $VAGRANT ssh -c "sudo tee /tmp/chef/node.json > /dev/null" <<'EOF'
{
  "run_list": ["recipe[axonops::agent_test]"],
  "axonops": {
    "agent": {
      "enabled": true,
      "type": "saas"
    }
  }
}
EOF
            ;;
        "server")
            $VAGRANT ssh -c "sudo tee /tmp/chef/node.json > /dev/null" <<'EOF'
{
  "run_list": ["recipe[axonops::server_test]"],
  "axonops": {
    "server": {
      "enabled": true
    }
  }
}
EOF
            ;;
        "dashboard")
            $VAGRANT ssh -c "sudo tee /tmp/chef/node.json > /dev/null" <<'EOF'
{
  "run_list": ["recipe[axonops::dashboard_test]"],
  "axonops": {
    "dash": {
      "enabled": true
    }
  }
}
EOF
            ;;
        "cassandra")
            $VAGRANT ssh -c "sudo tee /tmp/chef/node.json > /dev/null" <<'EOF'
{
  "run_list": ["recipe[axonops::cassandra_test]"],
  "cassandra": {
    "install_method": "package"
  }
}
EOF
            ;;
        "configure")
            $VAGRANT ssh -c "sudo tee /tmp/chef/node.json > /dev/null" <<'EOF'
{
  "run_list": ["recipe[axonops::configure_test]"],
  "axonops": {
    "configure_api": true
  }
}
EOF
            ;;
        "offline")
            $VAGRANT ssh -c "sudo tee /tmp/chef/node.json > /dev/null" <<'EOF'
{
  "run_list": ["recipe[axonops::offline_test]"],
  "axonops": {
    "offline_install": true
  }
}
EOF
            ;;
        "full-stack")
            $VAGRANT ssh -c "sudo tee /tmp/chef/node.json > /dev/null" <<'EOF'
{
  "run_list": ["recipe[axonops::full_stack_test]"],
  "axonops": {
    "agent": {
      "enabled": true
    },
    "server": {
      "enabled": true
    },
    "dash": {
      "enabled": true
    }
  }
}
EOF
            ;;
    esac
    
    # Run Chef
    echo "Running Chef..."
    $VAGRANT ssh -c "sudo chef-solo -c /tmp/chef/solo.rb -j /tmp/chef/node.json"
    
    # Run verification
    echo ""
    echo "Running verification tests..."
    if [ -f "$COOKBOOK_DIR/test/integration/$suite/verify.sh" ]; then
        $VAGRANT ssh < "$COOKBOOK_DIR/test/integration/$suite/verify.sh"
        test_result=$?
    else
        echo "WARNING: No verification script found at $COOKBOOK_DIR/test/integration/$suite/verify.sh"
        test_result=1
    fi
    
    # Clean up
    echo ""
    echo "Cleaning up VM..."
    $VAGRANT destroy -f
    
    if [ $test_result -eq 0 ]; then
        echo "✅ $suite test PASSED"
    else
        echo "❌ $suite test FAILED"
        exit 1
    fi
    
    cd - > /dev/null
    echo ""
}

# Main execution
echo "AxonOps Chef Cookbook Integration Test Runner"
echo "============================================="
echo ""

# Check if specific suite was requested
if [ $# -eq 1 ]; then
    run_test "$1"
else
    # Run all tests
    for suite in default agent server dashboard cassandra configure offline full-stack; do
        run_test "$suite"
    done
fi

echo ""
echo "All tests completed!"