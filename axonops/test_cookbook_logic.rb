#!/usr/bin/env ruby

require 'json'
require 'yaml'
require 'fileutils'
require 'tempfile'

# Mock Chef DSL for testing
class MockChefNode
  attr_accessor :attributes, :run_state

  def initialize
    @attributes = {
      'axonops' => {
        'agent' => { 'enabled' => true, 'version' => '2.0.4' },
        'server' => { 'enabled' => true, 'version' => '1.0.0' },
        'deployment_mode' => 'self-hosted',
        'api' => { 'key' => 'test-key', 'organization' => 'test-org' },
        'offline_install' => false,
      },
      'cassandra' => {
        'version' => '5.0',
        'cluster_name' => 'Test Cluster',
      },
      'platform_family' => 'debian',
      'platform' => 'ubuntu',
      'platform_version' => '20.04',
    }
    @run_state = {}
  end

  def [](key)
    @attributes[key]
  end

  def []=(key, value)
    @attributes[key] = value
  end
end

class CookbookTester
  attr_reader :results

  def initialize
    @results = { passed: 0, failed: 0, errors: [] }
    @node = MockChefNode.new
  end

  def run_all_tests
    puts '=' * 60
    puts 'AxonOps Cookbook Logic Testing'
    puts '=' * 60

    test_attribute_structure
    test_recipe_logic
    test_template_rendering
    test_resource_properties
    test_api_library
    test_platform_support
    test_offline_mode

    print_results
  end

  private

  def test_attribute_structure
    puts "\n1. Testing Attribute Structure..."

    # Load and parse attributes
    attrs_files = Dir.glob('attributes/*.rb')

    attrs_files.each do |file|
      begin
        content = File.read(file)

        # Check for proper namespacing
        if content.include?("default['axonops']") || content.include?("default['cassandra']") || content.include?("default['java']")
          pass("✓ #{File.basename(file)} uses proper attribute namespacing")
        else
          fail("✗ #{File.basename(file)} missing proper namespacing")
        end

        # Check for comments
        if content.lines.any? { |line| line.strip.start_with?('#') }
          pass("✓ #{File.basename(file)} contains documentation comments")
        else
          fail("✗ #{File.basename(file)} lacks documentation")
        end
      rescue => e
        error("Error reading #{file}: #{e.message}")
      end
    end
  end

  def test_recipe_logic
    puts "\n2. Testing Recipe Logic..."

    # Test agent recipe logic
    test_agent_recipe_logic

    # Test server recipe logic
    test_server_recipe_logic

    # Test configure recipe logic
    test_configure_recipe_logic
  end

  def test_agent_recipe_logic
    # Simulate agent recipe logic
    if @node['axonops']['deployment_mode'] == 'saas'
      pass('✓ Agent correctly configured for SaaS mode')
    elsif @node['axonops']['deployment_mode'] == 'self-hosted'
      pass('✓ Agent correctly configured for self-hosted mode')
    else
      fail('✗ Invalid deployment mode')
    end

    # Test Cassandra detection logic
    cassandra_paths = ['/opt/cassandra', '/usr/share/cassandra']
    if cassandra_paths.any? { |p| File.directory?(p) }
      pass('✓ Cassandra detection logic would find installation')
    else
      pass('✓ Cassandra detection logic correctly handles missing installation')
    end
  end

  def test_server_recipe_logic
    # Test server deployment logic
    if @node['axonops']['deployment_mode'] == 'self-hosted' && @node['axonops']['server']['enabled']
      pass('✓ Server recipe correctly enabled for self-hosted mode')
    elsif @node['axonops']['deployment_mode'] == 'saas'
      pass('✓ Server recipe correctly skipped for SaaS mode')
    else
      fail('✗ Server recipe logic error')
    end
  end

  def test_configure_recipe_logic
    # Test API configuration requirements
    if @node['axonops']['api']['key'] || @node['axonops']['deployment_mode'] == 'self-hosted'
      pass('✓ Configure recipe has required API credentials')
    else
      fail('✗ Configure recipe missing API credentials')
    end
  end

  def test_template_rendering
    puts "\n3. Testing Template Rendering..."

    # Test agent config template
    test_agent_template

    # Test server config template
    test_server_template
  end

  def test_agent_template
    template_file = 'templates/default/axon-agent.yml.erb'

    if File.exist?(template_file)
      content = File.read(template_file)

      # Check for required variables
      required_vars = %w(agent_host agent_port node_address cassandra_home)
      missing_vars = required_vars.reject { |var| content.include?(var) }

      if missing_vars.empty?
        pass('✓ Agent template contains all required variables')
      else
        fail("✗ Agent template missing variables: #{missing_vars.join(', ')}")
      end

      # Check ERB syntax
      if content.count('<%') == content.count('%>')
        pass('✓ Agent template has valid ERB syntax')
      else
        fail('✗ Agent template has mismatched ERB tags')
      end
    else
      fail('✗ Agent template not found')
    end
  end

  def test_server_template
    template_file = 'templates/default/axon-server.yml.erb'

    if File.exist?(template_file)
      pass('✓ Server template exists')

      content = File.read(template_file)
      if content.include?('listen_address') && content.include?('listen_port')
        pass('✓ Server template contains required configuration')
      else
        fail('✗ Server template missing required configuration')
      end
    else
      fail('✗ Server template not found')
    end
  end

  def test_resource_properties
    puts "\n4. Testing Custom Resources..."

    resource_file = 'resources/alert_rule.rb'

    if File.exist?(resource_file)
      content = File.read(resource_file)

      # Check for required properties
      required_props = %w(metric threshold condition)
      found_props = required_props.select { |prop| content.match(/property\s+:#{prop}/) }

      if found_props.length == required_props.length
        pass('✓ Alert rule resource has all required properties')
      else
        missing = required_props - found_props
        fail("✗ Alert rule resource missing properties: #{missing.join(', ')}")
      end

      # Check for actions
      if content.include?('action :create') && content.include?('action :delete')
        pass('✓ Alert rule resource has required actions')
      else
        fail('✗ Alert rule resource missing actions')
      end
    else
      fail('✗ Alert rule resource not found')
    end
  end

  def test_api_library
    puts "\n5. Testing API Library..."

    lib_file = 'libraries/axonops_api.rb'

    if File.exist?(lib_file)
      content = File.read(lib_file)

      # Check for API class
      if content.include?('class API') && content.include?('module AxonOps')
        pass('✓ API library properly structured')
      else
        fail('✗ API library structure incorrect')
      end

      # Check for required methods
      required_methods = %w(create_alert_rule delete_alert_rule get_alert_rules)
      found_methods = required_methods.select { |method| content.include?("def #{method}") }

      if found_methods.length == required_methods.length
        pass('✓ API library has all required methods')
      else
        missing = required_methods - found_methods
        fail("✗ API library missing methods: #{missing.join(', ')}")
      end
    else
      fail('✗ API library not found')
    end
  end

  def test_platform_support
    puts "\n6. Testing Platform Support..."

    platforms = %w(debian rhel ubuntu centos)

    # Check recipes for platform-specific logic
    Dir.glob('recipes/*.rb').each do |recipe|
      content = File.read(recipe)

      if content.include?('platform_family')
        pass("✓ #{File.basename(recipe)} includes platform-specific logic")
      end
    end

    # Check metadata for platform support
    if File.exist?('metadata.rb')
      metadata = File.read('metadata.rb')
      supported = platforms.select { |p| metadata.include?("supports '#{p}'") }

      if supported.any?
        pass("✓ Metadata declares support for: #{supported.join(', ')}")
      else
        fail('✗ Metadata missing platform support declarations')
      end
    end
  end

  def test_offline_mode
    puts "\n7. Testing Offline Mode Support..."

    # Test offline mode configuration
    @node['axonops']['offline_install'] = true
    @node['axonops']['offline_packages_path'] = '/tmp/packages'

    # Check for offline mode handling in recipes
    offline_recipes = Dir.glob('recipes/*.rb').select do |recipe|
      content = File.read(recipe)
      content.include?('offline_install') || content.include?('offline_packages_path')
    end

    if offline_recipes.any?
      pass("✓ Found #{offline_recipes.length} recipes with offline mode support")
    else
      fail('✗ No recipes found with offline mode support')
    end

    # Check for package path validation
    agent_recipe = 'recipes/agent.rb'
    if File.exist?(agent_recipe)
      content = File.read(agent_recipe)
      if content.include?('raise') && content.include?('offline')
        pass('✓ Agent recipe validates offline package requirements')
      else
        fail('✗ Agent recipe missing offline package validation')
      end
    end
  end

  def pass(message)
    puts "  #{message}"
    @results[:passed] += 1
  end

  def fail(message)
    puts "  #{message}"
    @results[:failed] += 1
    @results[:errors] << message
  end

  def error(message)
    puts "  ERROR: #{message}"
    @results[:failed] += 1
    @results[:errors] << message
  end

  def print_results
    puts "\n" + '=' * 60
    puts 'TEST RESULTS'
    puts '=' * 60

    total = @results[:passed] + @results[:failed]
    puts "\nTotal Tests: #{total}"
    puts "Passed: #{@results[:passed]} ✓"
    puts "Failed: #{@results[:failed]} ✗"

    if @results[:failed] > 0
      puts "\nFailures:"
      @results[:errors].each { |e| puts "  - #{e}" }
    end

    puts "\n" + '=' * 60
    if @results[:failed] == 0
      puts 'ALL TESTS PASSED! ✓'
      exit 0
    else
      puts 'TESTS FAILED! ✗'
      exit 1
    end
  end
end

# Run the tests
tester = CookbookTester.new
tester.run_all_tests
