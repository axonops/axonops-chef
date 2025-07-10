#!/usr/bin/env ruby

require 'fileutils'
require 'yaml'
require 'json'
require 'erb'
require 'open3'

# Integration tests for AxonOps cookbook
class IntegrationTester
  attr_reader :test_root, :results

  def initialize
    @test_root = Dir.pwd
    @results = { passed: 0, failed: 0, errors: [], warnings: [] }
  end

  def run_all_tests
    puts '=' * 70
    puts 'AxonOps Cookbook Integration Testing'
    puts "Running in: #{@test_root}"
    puts '=' * 70

    # Core functionality tests
    test_cookbook_structure
    test_metadata_validity
    test_attribute_files
    test_recipe_syntax
    test_template_compilation
    test_library_loading
    test_resource_definitions
    test_kitchen_configuration
    test_documentation

    print_results
  end

  private

  def test_cookbook_structure
    puts "\n1. Testing Cookbook Structure..."

    required_dirs = %w(
      attributes
      libraries
      recipes
      resources
      templates
      test
      spec
    )

    required_dirs.each do |dir|
      if Dir.exist?(dir)
        file_count = Dir.glob("#{dir}/**/*").select { |f| File.file?(f) }.count
        pass("✓ Directory '#{dir}' exists with #{file_count} files")
      else
        fail("✗ Missing required directory: #{dir}")
      end
    end

    # Check for required files
    required_files = %w(
      metadata.rb
      README.md
      .kitchen.yml
    )

    required_files.each do |file|
      if File.exist?(file)
        pass("✓ Required file exists: #{file}")
      else
        fail("✗ Missing required file: #{file}")
      end
    end
  end

  def test_metadata_validity
    puts "\n2. Testing Metadata Validity..."

    metadata_file = 'metadata.rb'
    if File.exist?(metadata_file)
      content = File.read(metadata_file)

      # Check required metadata fields
      checks = {
        "name 'axonops'" => 'cookbook name',
        'maintainer' => 'maintainer information',
        'license' => 'license declaration',
        'version' => 'version number',
        'description' => 'cookbook description',
      }

      checks.each do |pattern, description|
        if content.include?(pattern.split(' ').first)
          pass("✓ Metadata includes #{description}")
        else
          fail("✗ Metadata missing #{description}")
        end
      end

      # Extract version
      if content =~ /version\s+['"](\d+\.\d+\.\d+)['"]/
        version = Regexp.last_match(1)
        pass("✓ Valid semantic version: #{version}")
      else
        fail('✗ Invalid version format')
      end
    else
      fail('✗ metadata.rb not found')
    end
  end

  def test_attribute_files
    puts "\n3. Testing Attribute Files..."

    attr_files = Dir.glob('attributes/*.rb')

    attr_files.each do |file|
      basename = File.basename(file)
      content = File.read(file)

      # Check for syntax errors
      stdout, stderr, status = Open3.capture3("ruby -c #{file}")

      if status.success?
        pass("✓ Valid Ruby syntax: #{basename}")
      else
        fail("✗ Syntax error in #{basename}: #{stderr}")
      end

      # Check for proper attribute structure
      if content =~ /default\[['"][\w]+['"]\]/
        pass("✓ Proper attribute structure in #{basename}")
      else
        warn("⚠ No default attributes found in #{basename}")
      end
    end
  end

  def test_recipe_syntax
    puts "\n4. Testing Recipe Syntax..."

    recipe_files = Dir.glob('recipes/*.rb')

    recipe_files.each do |file|
      basename = File.basename(file)

      # Basic Ruby syntax check
      stdout, stderr, status = Open3.capture3("ruby -c #{file}")

      if status.success?
        pass("✓ Valid syntax: #{basename}")

        # Check for common Chef patterns
        content = File.read(file)

        # Look for resource declarations
        if content =~ /^\s*(package|service|template|directory|file|user|group)\s+/
          pass("✓ Contains Chef resources: #{basename}")
        elsif basename == 'default.rb'
          pass('✓ Default recipe (may be empty)')
        else
          warn("⚠ No Chef resources found in #{basename}")
        end

      else
        fail("✗ Syntax error in #{basename}: #{stderr}")
      end
    end
  end

  def test_template_compilation
    puts "\n5. Testing Template Compilation..."

    template_files = Dir.glob('templates/**/*.erb')

    template_files.each do |file|
      basename = File.basename(file)

      begin
        content = File.read(file)

        # Check ERB syntax
        ERB.new(content)
        pass("✓ Valid ERB syntax: #{basename}")

        # Check for common template variables
        variables = content.scan(/@(\w+)/).flatten.uniq

        if variables.any?
          pass("✓ Template uses #{variables.length} variables: #{basename}")
        else
          warn("⚠ No template variables found in #{basename}")
        end
      rescue SyntaxError => e
        fail("✗ ERB syntax error in #{basename}: #{e.message}")
      rescue => e
        fail("✗ Error processing #{basename}: #{e.message}")
      end
    end
  end

  def test_library_loading
    puts "\n6. Testing Library Loading..."

    lib_files = Dir.glob('libraries/*.rb')

    lib_files.each do |file|
      basename = File.basename(file)

      # Test Ruby syntax
      stdout, stderr, status = Open3.capture3("ruby -c #{file}")

      if status.success?
        pass("✓ Valid library syntax: #{basename}")

        # Check for module/class definitions
        content = File.read(file)

        if content =~ /^\s*(module|class)\s+\w+/
          pass("✓ Contains module/class definition: #{basename}")
        else
          warn("⚠ No module/class definition in #{basename}")
        end
      else
        fail("✗ Syntax error in #{basename}: #{stderr}")
      end
    end
  end

  def test_resource_definitions
    puts "\n7. Testing Custom Resources..."

    resource_files = Dir.glob('resources/*.rb')

    if resource_files.empty?
      warn('⚠ No custom resources found')
    else
      resource_files.each do |file|
        basename = File.basename(file)
        content = File.read(file)

        # Check syntax
        stdout, stderr, status = Open3.capture3("ruby -c #{file}")

        if status.success?
          pass("✓ Valid resource syntax: #{basename}")

          # Check for required resource elements
          if content =~ /property\s+:\w+/
            pass("✓ Contains property definitions: #{basename}")
          else
            warn("⚠ No properties defined in #{basename}")
          end

          if content =~ /action\s+:\w+/
            pass("✓ Contains action definitions: #{basename}")
          else
            fail("✗ No actions defined in #{basename}")
          end
        else
          fail("✗ Syntax error in #{basename}: #{stderr}")
        end
      end
    end
  end

  def test_kitchen_configuration
    puts "\n8. Testing Kitchen Configuration..."

    kitchen_file = '.kitchen.yml'

    if File.exist?(kitchen_file)
      begin
        config = YAML.load_file(kitchen_file)

        # Check for required sections
        %w(driver provisioner verifier platforms suites).each do |section|
          if config[section]
            pass("✓ Kitchen config has '#{section}' section")
          else
            fail("✗ Kitchen config missing '#{section}' section")
          end
        end

        # Check suites
        if config['suites']
          suite_count = config['suites'].length
          pass("✓ Kitchen defines #{suite_count} test suites")

          # List suite names
          suite_names = config['suites'].map { |s| s['name'] }
          puts "    Test suites: #{suite_names.join(', ')}"
        end

        # Check platforms
        if config['platforms']
          platform_count = config['platforms'].length
          pass("✓ Kitchen tests on #{platform_count} platforms")

          platform_names = config['platforms'].map { |p| p['name'] }
          puts "    Platforms: #{platform_names.join(', ')}"
        end
      rescue => e
        fail("✗ Error parsing .kitchen.yml: #{e.message}")
      end
    else
      fail('✗ .kitchen.yml not found')
    end
  end

  def test_documentation
    puts "\n9. Testing Documentation..."

    # Check README
    if File.exist?('README.md')
      content = File.read('README.md')

      # Check for important sections
      sections = {
        '# AxonOps' => 'Main title',
        '## Requirements' => 'Requirements section',
        '## Usage' => 'Usage section',
        '## Attributes' => 'Attributes documentation',
        '## Recipes' => 'Recipe documentation',
      }

      sections.each do |pattern, description|
        if content.include?(pattern)
          pass("✓ README contains #{description}")
        else
          warn("⚠ README missing #{description}")
        end
      end

      # Check for examples
      if content.include?('```')
        pass('✓ README contains code examples')
      else
        warn('⚠ README lacks code examples')
      end
    else
      fail('✗ README.md not found')
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

  def warn(message)
    puts "  #{message}"
    @results[:warnings] << message
  end

  def print_results
    puts "\n" + '=' * 70
    puts 'INTEGRATION TEST RESULTS'
    puts '=' * 70

    total = @results[:passed] + @results[:failed]
    puts "\nTotal Checks: #{total}"
    puts "Passed: #{@results[:passed]} ✓"
    puts "Failed: #{@results[:failed]} ✗"
    puts "Warnings: #{@results[:warnings].length} ⚠"

    if @results[:warnings].any?
      puts "\nWarnings:"
      @results[:warnings].each { |w| puts "  #{w}" }
    end

    if @results[:failed] > 0
      puts "\nFailures:"
      @results[:errors].each { |e| puts "  #{e}" }
    end

    puts "\n" + '=' * 70

    if @results[:failed] == 0
      puts 'INTEGRATION TESTS PASSED! ✓'
      puts "Note: #{@results[:warnings].length} warnings should be reviewed"
      exit 0
    else
      puts 'INTEGRATION TESTS FAILED! ✗'
      exit 1
    end
  end
end

# Run the tests
tester = IntegrationTester.new
tester.run_all_tests
