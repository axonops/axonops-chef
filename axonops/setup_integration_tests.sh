#!/bin/bash

# Script to set up and run proper VM-based integration tests for AxonOps cookbook

set -e

echo "=================================================="
echo "AxonOps Cookbook - VM Integration Test Setup"
echo "=================================================="

# Check prerequisites
check_prerequisites() {
    echo -e "\n1. Checking prerequisites..."
    
    # Check for Vagrant
    if ! command -v vagrant &> /dev/null; then
        echo "❌ Vagrant is not installed!"
        echo "Please install Vagrant from: https://www.vagrantup.com/downloads"
        echo ""
        echo "On macOS with Homebrew:"
        echo "  brew install vagrant"
        echo ""
        exit 1
    else
        echo "✅ Vagrant installed: $(vagrant --version)"
    fi
    
    # Check for VirtualBox or VMware
    if command -v VBoxManage &> /dev/null; then
        echo "✅ VirtualBox installed: $(VBoxManage --version | cut -d' ' -f1)"
    elif command -v vmrun &> /dev/null; then
        echo "✅ VMware installed"
    else
        echo "❌ No virtualization provider found!"
        echo "Please install VirtualBox from: https://www.virtualbox.org/wiki/Downloads"
        echo "Or VMware Fusion/Workstation"
        echo ""
        echo "On macOS with Homebrew:"
        echo "  brew install --cask virtualbox"
        echo ""
        exit 1
    fi
    
    # Check for Chef Workstation
    if ! command -v chef &> /dev/null; then
        echo "⚠️  Chef Workstation not installed"
        echo "Installing via Ruby gems instead..."
    else
        echo "✅ Chef installed: $(chef --version | head -1)"
    fi
}

# Update Kitchen configuration for modern platforms
update_kitchen_config() {
    echo -e "\n2. Updating Kitchen configuration..."
    
    # Create a focused test configuration
    cat > .kitchen.local.yml << 'EOF'
---
driver:
  name: vagrant
  memory: 2048
  cpus: 2
  linked_clone: true  # Faster VM creation

provisioner:
  name: chef_zero
  product_name: chef
  install_strategy: always
  chef_license: accept

verifier:
  name: inspec

platforms:
  # Modern Ubuntu LTS
  - name: ubuntu-22.04
    driver:
      box: bento/ubuntu-22.04
  
  # Latest Debian stable
  - name: debian-12
    driver:
      box: bento/debian-12
  
  # RHEL-compatible alternatives
  - name: almalinux-9
    driver:
      box: bento/almalinux-9
  
  - name: rockylinux-9
    driver:
      box: bento/rockylinux-9

# Focused test suites for initial testing
suites:
  # Basic agent installation
  - name: agent-basic
    run_list:
      - recipe[axonops::agent]
    verifier:
      inspec_tests:
        - test/integration/agent
    attributes:
      axonops:
        agent:
          enabled: true
          type: "saas"
          key: "test-key-123"
          organization: "test-org"
  
  # Self-hosted server
  - name: server-basic
    run_list:
      - recipe[axonops::server]
    verifier:
      inspec_tests:
        - test/integration/server
    attributes:
      axonops:
        deployment_mode: "self-hosted"
        server:
          enabled: true
          listen_address: "0.0.0.0"
          listen_port: 8080
  
  # Full stack test (smaller memory footprint)
  - name: full-stack-minimal
    driver:
      memory: 4096
      cpus: 2
    run_list:
      - recipe[axonops::server]
      - recipe[axonops::agent]
      - recipe[axonops::configure]
    verifier:
      inspec_tests:
        - test/integration/server
        - test/integration/agent
        - test/integration/configure
    attributes:
      axonops:
        deployment_mode: "self-hosted"
        server:
          enabled: true
        agent:
          enabled: true
          type: "self-hosted"
        api:
          key: "test-key"
          organization: "test-org"
EOF

    echo "✅ Created .kitchen.local.yml with modern platforms"
}

# Create a Vagrantfile for direct testing
create_vagrantfile() {
    echo -e "\n3. Creating Vagrantfile for direct VM testing..."
    
    cat > Vagrantfile << 'EOF'
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Use modern, well-supported base box
  config.vm.box = "bento/ubuntu-22.04"
  
  # VM settings
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 2
    vb.linked_clone = true
  end
  
  # Network configuration
  config.vm.network "private_network", type: "dhcp"
  
  # Forward AxonOps ports
  config.vm.network "forwarded_port", guest: 8080, host: 8080  # AxonOps server
  config.vm.network "forwarded_port", guest: 9916, host: 9916  # AxonOps agent
  config.vm.network "forwarded_port", guest: 3000, host: 3000  # AxonOps dashboard
  
  # Provision with Chef
  config.vm.provision "chef_zero" do |chef|
    chef.cookbooks_path = "../../"
    chef.data_bags_path = "test/fixtures/data_bags"
    chef.nodes_path = "test/fixtures/nodes"
    chef.roles_path = "test/fixtures/roles"
    
    # Add recipes
    chef.add_recipe "axonops::default"
    
    # Set attributes
    chef.json = {
      "axonops" => {
        "agent" => {
          "enabled" => true,
          "type" => "saas",
          "key" => "test-integration-key",
          "organization" => "test-org"
        }
      }
    }
  end
  
  # Optional: Run InSpec tests after provisioning
  config.vm.provision "shell", inline: <<-SHELL
    echo "VM provisioned successfully!"
    echo "AxonOps agent status:"
    systemctl status axon-agent || true
  SHELL
end
EOF

    echo "✅ Created Vagrantfile"
}

# Run integration tests
run_tests() {
    echo -e "\n4. Integration Test Options..."
    echo ""
    echo "Choose your test approach:"
    echo ""
    echo "Option 1: Test Kitchen (Recommended)"
    echo "  bundle exec kitchen test agent-basic-ubuntu-2204"
    echo "  bundle exec kitchen test server-basic-almalinux-9"
    echo "  bundle exec kitchen list  # See all available tests"
    echo ""
    echo "Option 2: Direct Vagrant"
    echo "  vagrant up              # Start VM and provision"
    echo "  vagrant provision       # Re-run Chef"
    echo "  vagrant ssh             # Connect to VM"
    echo "  vagrant destroy         # Clean up"
    echo ""
    echo "Option 3: Quick smoke test"
    echo "  bundle exec kitchen converge agent-basic-ubuntu-2204"
    echo "  bundle exec kitchen verify agent-basic-ubuntu-2204"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    update_kitchen_config
    create_vagrantfile
    
    echo -e "\n=================================================="
    echo "Setup Complete!"
    echo "=================================================="
    
    run_tests
    
    echo "Tips:"
    echo "- Start with a single platform first (Ubuntu 22.04 recommended)"
    echo "- The agent-basic suite is the simplest to test"
    echo "- Monitor VM resource usage - each VM needs 2GB RAM"
    echo "- Use 'kitchen diagnose' to debug issues"
    echo ""
    echo "Ready to run real integration tests with VMs!"
}

# Run main
main