#!/bin/bash

# Check prerequisites for AxonOps cookbook development and testing

echo "==================================================="
echo "AxonOps Cookbook - Checking Prerequisites"
echo "==================================================="

ERRORS=0
WARNINGS=0

# Function to check command
check_command() {
    local cmd=$1
    local name=$2
    local required=$3
    
    if command -v $cmd &> /dev/null; then
        echo "✅ $name: $($cmd --version 2>&1 | head -1)"
        return 0
    else
        if [ "$required" = "required" ]; then
            echo "❌ $name: NOT FOUND (required)"
            ((ERRORS++))
        else
            echo "⚠️  $name: NOT FOUND (optional)"
            ((WARNINGS++))
        fi
        return 1
    fi
}

# Function to check Ruby gem
check_gem() {
    local gem=$1
    local name=$2
    
    if gem list | grep -q "^$gem "; then
        echo "✅ $name: $(gem list | grep "^$gem " | head -1)"
    else
        echo "⚠️  $name: NOT INSTALLED (optional)"
        ((WARNINGS++))
    fi
}

echo -e "\nCore Requirements:"
echo "=================="
check_command ruby "Ruby" required
check_command bundle "Bundler" required
check_command chef "Chef" optional
check_command kitchen "Test Kitchen" required

echo -e "\nVirtualization:"
echo "==============="
check_command vagrant "Vagrant" required
check_command VBoxManage "VirtualBox" required || check_command vmrun "VMware" optional

echo -e "\nContainer Runtime (Alternative to VMs):"
echo "======================================="
check_command docker "Docker" optional || check_command podman "Podman" optional

echo -e "\nDevelopment Tools:"
echo "=================="
check_command git "Git" required
check_command make "Make" required
check_command cookstyle "Cookstyle" optional
check_command foodcritic "Foodcritic" optional

echo -e "\nRuby Gems:"
echo "==========="
check_gem chefspec "ChefSpec"
check_gem kitchen-vagrant "Kitchen Vagrant"
check_gem kitchen-docker "Kitchen Docker"

echo -e "\nSystem Information:"
echo "==================="
echo "OS: $(uname -s)"
echo "Architecture: $(uname -m)"
echo "Ruby version: $(ruby -v)"

if [ -f Gemfile ]; then
    echo -e "\nBundle Status:"
    echo "=============="
    bundle check || echo "⚠️  Some gems need to be installed - run 'make setup'"
fi

echo -e "\nSummary:"
echo "========"
if [ $ERRORS -gt 0 ]; then
    echo "❌ Found $ERRORS critical errors - please install missing requirements"
    exit 1
else
    echo "✅ All required dependencies are installed"
fi

if [ $WARNINGS -gt 0 ]; then
    echo "⚠️  Found $WARNINGS warnings for optional components"
fi

echo -e "\nNext steps:"
echo "1. Run 'make setup' to install Ruby dependencies"
echo "2. Run 'make help' to see available commands"
echo "3. Run 'make test' to run the full test suite"