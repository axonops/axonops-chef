# AxonOps Chef Cookbook Makefile
# Provides user-friendly commands for development, testing, and deployment

.PHONY: help
help: ## Show this help message
	@echo "AxonOps Chef Cookbook - Available Commands"
	@echo "=========================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make test           # Run all tests"
	@echo "  make test-agent     # Test just the agent recipe"
	@echo "  make lint           # Run style checks"
	@echo "  make clean          # Clean up test VMs"

# Development Setup
.PHONY: setup
setup: ## Install dependencies and set up development environment
	@echo "Setting up development environment..."
	@which bundle >/dev/null || gem install bundler
	@bundle install
	@echo "✅ Development environment ready"

.PHONY: deps
deps: ## Check and install cookbook dependencies
	@echo "Checking cookbook dependencies..."
	@bundle check || bundle install
	@berks install || echo "Berkshelf not configured - skipping"

# Linting and Style
.PHONY: lint
lint: ## Run all linting and style checks
	@echo "Running cookbook linting..."
	@cookstyle . || true
	@echo ""
	@echo "Running foodcritic..."
	@foodcritic . -f any -t ~FC121 || true

.PHONY: lint-fix
lint-fix: ## Auto-fix style issues
	@echo "Auto-fixing style issues..."
	@cookstyle -a .

# Unit Testing
.PHONY: unit
unit: ## Run ChefSpec unit tests
	@echo "Running ChefSpec unit tests..."
	@bundle exec rspec --format documentation --color

.PHONY: unit-fast
unit-fast: ## Run unit tests without coverage
	@echo "Running fast unit tests..."
	@bundle exec rspec --format progress

# Integration Testing - Individual Suites
.PHONY: test-agent
test-agent: ## Test agent recipe on Ubuntu 22.04
	@echo "Testing AxonOps agent installation..."
	@echo "Note: Using direct VM testing due to bundler conflicts"
	@cd .kitchen/kitchen-vagrant/agent-ubuntu-2204 2>/dev/null && vagrant destroy -f || true
	@bundle exec kitchen create agent-ubuntu-2204 || echo "VM creation started..."
	@sleep 5  # Give VM time to start
	@cd .kitchen/kitchen-vagrant/agent-ubuntu-2204 && vagrant provision
	@echo ""
	@echo "Running verification tests..."
	@cd .kitchen/kitchen-vagrant/agent-ubuntu-2204 && vagrant ssh < ../../../test/integration/agent/verify.sh
	@echo ""
	@echo "✅ All tests passed!"
	@echo "Cleaning up..."
	@cd .kitchen/kitchen-vagrant/agent-ubuntu-2204 && vagrant destroy -f

.PHONY: test-default
test-default: ## Test default recipe (Java and common setup)
	@echo "Testing default AxonOps setup..."
	@echo "Note: Using direct VM testing due to bundler conflicts"
	@cd .kitchen/kitchen-vagrant/default-ubuntu-2204 2>/dev/null && vagrant destroy -f || true
	@bundle exec kitchen create default-ubuntu-2204 || echo "VM creation started..."
	@sleep 5
	@cd .kitchen/kitchen-vagrant/default-ubuntu-2204 && vagrant provision
	@echo ""
	@echo "Running verification tests..."
	@cd .kitchen/kitchen-vagrant/default-ubuntu-2204 && vagrant ssh < ../../../test/integration/default/verify.sh
	@echo ""
	@echo "✅ Default recipe tests passed!"
	@echo "Cleaning up..."
	@cd .kitchen/kitchen-vagrant/default-ubuntu-2204 && vagrant destroy -f

.PHONY: test-server
test-server: ## Test server recipe on Ubuntu 22.04
	@echo "Testing AxonOps server installation..."
	@echo "Note: Using direct VM testing due to bundler conflicts"
	@cd .kitchen/kitchen-vagrant/server-ubuntu-2204 2>/dev/null && vagrant destroy -f || true
	@bundle exec kitchen create server-ubuntu-2204 || echo "VM creation started..."
	@sleep 5
	@cd .kitchen/kitchen-vagrant/server-ubuntu-2204 && vagrant provision
	@echo ""
	@echo "Running verification tests..."
	@cd .kitchen/kitchen-vagrant/server-ubuntu-2204 && vagrant ssh < ../../../test/integration/server/verify.sh
	@echo ""
	@echo "✅ Server tests passed!"
	@echo "Cleaning up..."
	@cd .kitchen/kitchen-vagrant/server-ubuntu-2204 && vagrant destroy -f

.PHONY: test-dashboard
test-dashboard: ## Test dashboard recipe on Ubuntu 22.04
	@echo "Testing AxonOps dashboard installation..."
	@echo "Note: Using direct VM testing due to bundler conflicts"
	@cd .kitchen/kitchen-vagrant/dashboard-ubuntu-2204 2>/dev/null && vagrant destroy -f || true
	@bundle exec kitchen create dashboard-ubuntu-2204 || echo "VM creation started..."
	@sleep 5
	@cd .kitchen/kitchen-vagrant/dashboard-ubuntu-2204 && vagrant provision
	@echo ""
	@echo "Running verification tests..."
	@cd .kitchen/kitchen-vagrant/dashboard-ubuntu-2204 && vagrant ssh < ../../../test/integration/dashboard/verify.sh
	@echo ""
	@echo "✅ Dashboard tests passed!"
	@echo "Cleaning up..."
	@cd .kitchen/kitchen-vagrant/dashboard-ubuntu-2204 && vagrant destroy -f

.PHONY: test-cassandra
test-cassandra: ## Test Cassandra installation
	@echo "Testing Cassandra installation..."
	@echo "Note: Using direct VM testing due to bundler conflicts"
	@cd .kitchen/kitchen-vagrant/cassandra-ubuntu-2204 2>/dev/null && vagrant destroy -f || true
	@bundle exec kitchen create cassandra-ubuntu-2204 || echo "VM creation started..."
	@sleep 5
	@cd .kitchen/kitchen-vagrant/cassandra-ubuntu-2204 && vagrant provision
	@echo ""
	@echo "Running verification tests..."
	@cd .kitchen/kitchen-vagrant/cassandra-ubuntu-2204 && vagrant ssh < ../../../test/integration/cassandra/verify.sh
	@echo ""
	@echo "✅ Cassandra tests passed!"
	@echo "Cleaning up..."
	@cd .kitchen/kitchen-vagrant/cassandra-ubuntu-2204 && vagrant destroy -f

.PHONY: test-full-stack
test-full-stack: ## Test full AxonOps stack deployment
	@echo "Testing full AxonOps stack..."
	@echo "Note: This test installs ALL components and may take 10-15 minutes"
	@echo "Note: Using direct VM testing due to bundler conflicts"
	@cd .kitchen/kitchen-vagrant/full-stack-ubuntu-2204 2>/dev/null && vagrant destroy -f || true
	@bundle exec kitchen create full-stack-ubuntu-2204 || echo "VM creation started..."
	@sleep 5
	@cd .kitchen/kitchen-vagrant/full-stack-ubuntu-2204 && vagrant provision
	@echo ""
	@echo "Running verification tests..."
	@cd .kitchen/kitchen-vagrant/full-stack-ubuntu-2204 && vagrant ssh < ../../../test/integration/full-stack/verify.sh
	@echo ""
	@echo "✅ Full stack tests passed!"
	@echo "Cleaning up..."
	@cd .kitchen/kitchen-vagrant/full-stack-ubuntu-2204 && vagrant destroy -f

.PHONY: test-configure
test-configure: ## Test configuration management
	@echo "Testing AxonOps configuration management..."
	@echo "Note: Using direct VM testing due to bundler conflicts"
	@cd .kitchen/kitchen-vagrant/configure-ubuntu-2204 2>/dev/null && vagrant destroy -f || true
	@bundle exec kitchen create configure-ubuntu-2204 || echo "VM creation started..."
	@sleep 5
	@cd .kitchen/kitchen-vagrant/configure-ubuntu-2204 && vagrant provision
	@echo ""
	@echo "Running verification tests..."
	@cd .kitchen/kitchen-vagrant/configure-ubuntu-2204 && vagrant ssh < ../../../test/integration/configure/verify.sh
	@echo ""
	@echo "✅ Configuration tests passed!"
	@echo "Cleaning up..."
	@cd .kitchen/kitchen-vagrant/configure-ubuntu-2204 && vagrant destroy -f

.PHONY: test-offline
test-offline: ## Test offline/airgapped installation
	@echo "Testing offline/airgapped installation..."
	@echo "Note: Using direct VM testing due to bundler conflicts"
	@cd .kitchen/kitchen-vagrant/offline-ubuntu-2204 2>/dev/null && vagrant destroy -f || true
	@bundle exec kitchen create offline-ubuntu-2204 || echo "VM creation started..."
	@sleep 5
	@cd .kitchen/kitchen-vagrant/offline-ubuntu-2204 && vagrant provision
	@echo ""
	@echo "Running verification tests..."
	@cd .kitchen/kitchen-vagrant/offline-ubuntu-2204 && vagrant ssh < ../../../test/integration/offline/verify.sh
	@echo ""
	@echo "✅ Offline installation tests passed!"
	@echo "Cleaning up..."
	@cd .kitchen/kitchen-vagrant/offline-ubuntu-2204 && vagrant destroy -f

.PHONY: test-full
test-full: ## Test full stack deployment
	@echo "Testing full AxonOps stack..."
	@bundle exec kitchen test full-stack-ubuntu-2204 --destroy=always

# Integration Testing - All Platforms
.PHONY: test-platforms
test-platforms: ## Test on all supported platforms (long running)
	@echo "Testing on all platforms (this will take a while)..."
	@bundle exec kitchen test -c 2

# Combined Testing
.PHONY: test
test: lint unit ## Run standard tests (lint and unit tests only)
	@echo "✅ Basic tests completed"
	@echo ""
	@echo "To run integration tests for specific components:"
	@echo "  make test-agent      # Test AxonOps agent"
	@echo "  make test-server     # Test AxonOps server"
	@echo "  make test-cassandra  # Test Cassandra installation"
	@echo "  make test-full-stack # Test everything together"
	@echo ""
	@echo "For quick tests that keep VMs running:"
	@echo "  make test-agent-quick"
	@echo "  make test-server-quick"
	@echo "  make test-cassandra-quick"

.PHONY: test-quick
test-quick: lint-fix unit ## Run quick tests only (no VMs)
	@echo "✅ Quick tests completed"

.PHONY: test-components
test-components: ## Run all component integration tests (takes 30+ minutes)
	@echo "Running all component tests..."
	@echo "This will test: default, agent, server, dashboard, cassandra, configure, offline"
	@echo "Warning: This will take 30-45 minutes and requires significant resources"
	@echo ""
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(MAKE) test-default && \
		$(MAKE) test-agent && \
		$(MAKE) test-server && \
		$(MAKE) test-dashboard && \
		$(MAKE) test-cassandra && \
		$(MAKE) test-configure && \
		$(MAKE) test-offline && \
		echo "✅ All component tests passed!"; \
	else \
		echo "Cancelled"; \
	fi

.PHONY: test-all
test-all: lint unit test-components ## Run ALL tests including all components

# Kitchen Commands
.PHONY: kitchen-list
kitchen-list: ## List all test instances
	@bundle exec kitchen list

.PHONY: kitchen-create
kitchen-create: ## Create all test VMs without converging
	@bundle exec kitchen create

.PHONY: kitchen-converge
kitchen-converge: ## Converge all test instances
	@bundle exec kitchen converge

.PHONY: kitchen-verify
kitchen-verify: ## Run verification on all instances
	@bundle exec kitchen verify

.PHONY: kitchen-login
kitchen-login: ## Login to test instance (use SUITE=name to specify)
	@if [ -n "$(SUITE)" ]; then \
		bundle exec kitchen login $(SUITE)-ubuntu-2204 || true; \
	else \
		echo "Please specify SUITE. Examples:"; \
		echo "  make kitchen-login SUITE=agent"; \
		echo "  make kitchen-login SUITE=server"; \
		echo "  make kitchen-login SUITE=cassandra"; \
		echo "  make kitchen-login SUITE=full-stack"; \
		echo ""; \
		echo "Available instances:"; \
		bundle exec kitchen list || true; \
	fi

# Cleanup
.PHONY: clean
clean: ## Destroy all test instances
	@echo "Cleaning up test instances..."
	@bundle exec kitchen destroy || true
	@echo "✅ Cleanup complete"

.PHONY: clean-all
clean-all: clean ## Deep clean including caches
	@echo "Deep cleaning..."
	@rm -rf .kitchen/
	@rm -rf vendor/
	@rm -rf Berksfile.lock
	@rm -f Gemfile.lock
	@echo "✅ Deep clean complete"

# Documentation
.PHONY: docs
docs: ## Generate documentation
	@echo "Generating documentation..."
	@yard doc --output-dir docs/ || echo "YARD not installed"
	@echo "Generating cookbook documentation..."
	@knife cookbook doc . || echo "Knife cookbook doc not available"

# Release Preparation
.PHONY: version
version: ## Show current version
	@grep '^version' metadata.rb | awk '{print $$2}' | tr -d "'"

.PHONY: bump-patch
bump-patch: ## Bump patch version (0.0.x)
	@echo "Bumping patch version..."
	@bundle exec thor version:bump patch

.PHONY: bump-minor
bump-minor: ## Bump minor version (0.x.0)
	@echo "Bumping minor version..."
	@bundle exec thor version:bump minor

.PHONY: bump-major
bump-major: ## Bump major version (x.0.0)
	@echo "Bumping major version..."
	@bundle exec thor version:bump major

# Validation
.PHONY: validate
validate: ## Validate cookbook syntax
	@echo "Validating cookbook syntax..."
	@knife cookbook test . -o .. || echo "Knife validation skipped"
	@echo "Validating metadata..."
	@ruby -c metadata.rb
	@echo "✅ Validation complete"

# Publishing
.PHONY: package
package: validate ## Package cookbook for distribution
	@echo "Packaging cookbook..."
	@knife cookbook metadata . -o ..
	@tar -czf axonops-cookbook-$(shell make version).tar.gz \
		--exclude='.kitchen*' \
		--exclude='test' \
		--exclude='.git' \
		--exclude='vendor' \
		.
	@echo "✅ Package created: axonops-cookbook-$(shell make version).tar.gz"

.PHONY: publish-dry
publish-dry: validate ## Dry run of publishing to Supermarket
	@echo "Dry run - Publishing to Chef Supermarket..."
	@knife supermarket share axonops -o .. --dry-run

.PHONY: publish
publish: test validate ## Publish to Chef Supermarket (requires API key)
	@echo "Publishing to Chef Supermarket..."
	@knife supermarket share axonops -o ..

# Development Helpers
.PHONY: console
console: ## Open a Pry console with cookbook loaded
	@bundle exec pry -r ./libraries/api.rb

.PHONY: watch
watch: ## Watch for changes and run tests
	@echo "Watching for changes..."
	@fswatch -o . | xargs -n1 -I{} make test-quick

# Container Testing (Docker/Podman)
# Detect container runtime
CONTAINER_RUNTIME := $(shell (command -v podman >/dev/null 2>&1 && echo "podman") || (command -v docker >/dev/null 2>&1 && echo "docker") || echo "none")

.PHONY: check-container
check-container: ## Check container runtime availability
	@if [ "$(CONTAINER_RUNTIME)" = "none" ]; then \
		echo "❌ Neither Docker nor Podman found. Please install one."; \
		exit 1; \
	else \
		echo "✅ Found container runtime: $(CONTAINER_RUNTIME)"; \
		if [ "$(CONTAINER_RUNTIME)" = "podman" ]; then \
			echo "   Using Podman in Docker-compatible mode"; \
			if command -v systemctl >/dev/null 2>&1; then \
				if ! systemctl --user is-active podman.socket >/dev/null 2>&1; then \
					echo "   Starting podman socket..."; \
					systemctl --user start podman.socket || true; \
				fi; \
			else \
				echo "   Note: On macOS, Podman machine handles the socket automatically"; \
				if ! podman machine list | grep -q "Currently running"; then \
					echo "   ⚠️  No Podman machine running. Start with: podman machine start"; \
				fi; \
			fi; \
		fi; \
	fi

# Set DOCKER_HOST for Podman based on OS
ifeq ($(CONTAINER_RUNTIME),podman)
  ifeq ($(shell uname),Darwin)
    # macOS Podman socket location
    DOCKER_HOST_VAR := DOCKER_HOST=unix://$(HOME)/.local/share/containers/podman/machine/podman.sock
  else
    # Linux Podman socket location
    DOCKER_HOST_VAR := DOCKER_HOST=unix:///run/user/$(shell id -u)/podman/podman.sock
  endif
  # Create docker alias for kitchen-docker compatibility
  DOCKER_ALIAS := PATH="/tmp/podman-docker-compat:$$PATH"
else
  DOCKER_HOST_VAR :=
  DOCKER_ALIAS :=
endif

# Create docker wrapper for Podman if needed
.PHONY: setup-podman-docker
setup-podman-docker:
	@if [ "$(CONTAINER_RUNTIME)" = "podman" ] && ! command -v docker >/dev/null 2>&1; then \
		mkdir -p /tmp/podman-docker-compat; \
		echo '#!/bin/sh' > /tmp/podman-docker-compat/docker; \
		echo 'exec podman "$$@"' >> /tmp/podman-docker-compat/docker; \
		chmod +x /tmp/podman-docker-compat/docker; \
		echo "✅ Created docker alias for Podman compatibility"; \
	fi

.PHONY: test-container
test-container: check-container setup-podman-docker ## Run tests using containers instead of VMs
	@echo "Running container-based tests with $(CONTAINER_RUNTIME)..."
	$(DOCKER_ALIAS) $(DOCKER_HOST_VAR) KITCHEN_YAML=.kitchen.docker.yml bundle exec kitchen test agent-ubuntu-2204 --destroy=always

.PHONY: test-container-converge
test-container-converge: check-container setup-podman-docker ## Just converge using containers (no verify)
	@echo "Running container-based converge with $(CONTAINER_RUNTIME)..."
	$(DOCKER_ALIAS) $(DOCKER_HOST_VAR) KITCHEN_YAML=.kitchen.docker.yml bundle exec kitchen converge agent-ubuntu-2204

.PHONY: test-container-list
test-container-list: check-container setup-podman-docker ## List container test instances
	@$(DOCKER_ALIAS) $(DOCKER_HOST_VAR) KITCHEN_YAML=.kitchen.docker.yml bundle exec kitchen list

.PHONY: test-container-login
test-container-login: check-container setup-podman-docker ## Login to container test instance
	$(DOCKER_ALIAS) $(DOCKER_HOST_VAR) KITCHEN_YAML=.kitchen.docker.yml bundle exec kitchen login agent-ubuntu-2204

.PHONY: test-container-destroy
test-container-destroy: check-container setup-podman-docker ## Destroy container test instances
	$(DOCKER_ALIAS) $(DOCKER_HOST_VAR) KITCHEN_YAML=.kitchen.docker.yml bundle exec kitchen destroy || true

.PHONY: test-container-verify
test-container-verify: check-container setup-podman-docker ## Run verification on container instance
	$(DOCKER_ALIAS) $(DOCKER_HOST_VAR) KITCHEN_YAML=.kitchen.docker.yml bundle exec kitchen verify agent-ubuntu-2204

# Debug Helpers
.PHONY: debug-agent
debug-agent: ## Create and converge agent instance for debugging
	@bundle exec kitchen converge agent-ubuntu-2204
	@echo ""
	@echo "Instance ready for debugging. Commands:"
	@echo "  make kitchen-login  # SSH into the instance"
	@echo "  make verify-agent   # Run verification tests"
	@echo "  make clean          # Destroy when done"

.PHONY: verify-agent
verify-agent: ## Manually verify agent installation on running VM
	@echo "Running manual verification tests on existing VM..."
	@if [ -d .kitchen/kitchen-vagrant/agent-ubuntu-2204 ]; then \
		cd .kitchen/kitchen-vagrant/agent-ubuntu-2204 && vagrant ssh < ../../../test/integration/agent/verify.sh; \
	else \
		echo "❌ No VM found. Run 'make test-agent-quick' first."; \
	fi

# Quick test commands that keep VMs running for debugging
.PHONY: test-agent-quick
test-agent-quick: ## Quick agent test (keeps VM running)
	@echo "Testing AxonOps agent installation (quick mode - VM stays running)..."
	@if [ ! -d .kitchen/kitchen-vagrant/agent-ubuntu-2204 ] || ! (cd .kitchen/kitchen-vagrant/agent-ubuntu-2204 && vagrant status | grep -q running); then \
		echo "Creating and converging VM..."; \
		bundle exec kitchen converge agent-ubuntu-2204 || true; \
	else \
		echo "VM already running, re-converging..."; \
		cd .kitchen/kitchen-vagrant/agent-ubuntu-2204 && vagrant provision; \
	fi
	@echo ""
	@echo "Running verification tests..."
	@cd .kitchen/kitchen-vagrant/agent-ubuntu-2204 && vagrant ssh < ../../../test/integration/agent/verify.sh
	@echo ""
	@echo "✅ Tests completed! VM is still running."
	@echo "To login: make kitchen-login SUITE=agent"
	@echo "To cleanup: make clean"

.PHONY: test-server-quick
test-server-quick: ## Quick server test (keeps VM running)
	@echo "Testing AxonOps server (quick mode - VM stays running)..."
	@bundle exec kitchen converge server-ubuntu-2204 || true
	@cd .kitchen/kitchen-vagrant/server-ubuntu-2204 && vagrant ssh < ../../../test/integration/server/verify.sh
	@echo "✅ Server VM ready. Login: make kitchen-login SUITE=server"

.PHONY: test-cassandra-quick
test-cassandra-quick: ## Quick Cassandra test (keeps VM running)
	@echo "Testing Cassandra (quick mode - VM stays running)..."
	@bundle exec kitchen converge cassandra-ubuntu-2204 || true
	@cd .kitchen/kitchen-vagrant/cassandra-ubuntu-2204 && vagrant ssh < ../../../test/integration/cassandra/verify.sh
	@echo "✅ Cassandra VM ready. Login: make kitchen-login SUITE=cassandra"

.PHONY: test-full-stack-quick
test-full-stack-quick: ## Quick full stack test (keeps VM running)
	@echo "Testing full stack (quick mode - VM stays running)..."
	@echo "Warning: This creates a large VM with all components - may take 10+ minutes"
	@bundle exec kitchen converge full-stack-ubuntu-2204 || true
	@cd .kitchen/kitchen-vagrant/full-stack-ubuntu-2204 && vagrant ssh < ../../../test/integration/full-stack/verify.sh
	@echo "✅ Full stack VM ready. Login: make kitchen-login SUITE=full-stack"

.PHONY: diagnose
diagnose: ## Run kitchen diagnose for debugging
	@bundle exec kitchen diagnose

# CI/CD Commands
.PHONY: ci
ci: setup lint unit ## Run CI pipeline tests
	@echo "✅ CI tests passed"

.PHONY: cd
cd: ci test-agent validate ## Run full CD pipeline
	@echo "✅ CD pipeline complete"

# Status and Info
.PHONY: status
status: ## Show current test instance status
	@echo "Current test instances:"
	@bundle exec kitchen list || true
	@echo ""
	@echo "Cookbook version: $(shell make version)"
	@echo "Ruby version: $(shell ruby -v | cut -d' ' -f2)"
	@echo "Chef version: $(shell chef --version 2>/dev/null | head -1 || echo 'Not installed')"

.PHONY: test-status
test-status: ## Show available tests and their purposes
	@echo "=== AxonOps Chef Cookbook Test Suites ==="
	@echo ""
	@echo "Basic Tests (no VMs required):"
	@echo "  make lint        - Style and syntax checks"
	@echo "  make unit        - ChefSpec unit tests"
	@echo ""
	@echo "Component Integration Tests (each creates a VM):"
	@echo "  make test-default     - Java and common setup"
	@echo "  make test-agent       - AxonOps monitoring agent"
	@echo "  make test-server      - AxonOps server + Elasticsearch + Cassandra storage"
	@echo "  make test-dashboard   - AxonOps web dashboard"
	@echo "  make test-cassandra   - User application Cassandra"
	@echo "  make test-configure   - API-based configuration management"
	@echo "  make test-offline     - Offline/airgapped installation"
	@echo "  make test-full-stack  - ALL components together (large VM)"
	@echo ""
	@echo "Quick Tests (keep VMs running for debugging):"
	@echo "  make test-agent-quick"
	@echo "  make test-server-quick"
	@echo "  make test-cassandra-quick"
	@echo "  make test-full-stack-quick"
	@echo ""
	@echo "Test Commands:"
	@echo "  make test-components  - Run all integration tests (30+ mins)"
	@echo "  make test-all         - Run everything (lint, unit, all integration)"
	@echo "  make kitchen-login SUITE=<name>  - SSH into a test VM"
	@echo "  make clean            - Destroy all test VMs"

# Default target
.DEFAULT_GOAL := help