#!/usr/bin/env ruby

# Simple validation script for the AxonOps cookbook

require 'json'
require 'yaml'

class CookbookValidator
  attr_reader :errors, :warnings, :successes

  def initialize(cookbook_path = '.')
    @cookbook_path = cookbook_path
    @errors = []
    @warnings = []
    @successes = []
  end

  def validate!
    puts "Validating AxonOps cookbook at: #{@cookbook_path}\n\n"

    validate_metadata
    validate_recipes
    validate_attributes
    validate_templates
    validate_resources
    validate_libraries
    validate_tests
    validate_kitchen

    print_results
  end

  private

  def validate_metadata
    puts 'Checking metadata.rb...'
    metadata_file = File.join(@cookbook_path, 'metadata.rb')

    if File.exist?(metadata_file)
      content = File.read(metadata_file)

      if content.include?("name 'axonops'")
        @successes << "✓ Cookbook name is correctly set to 'axonops'"
      else
        @errors << "✗ Cookbook name should be 'axonops'"
      end

      if content.match(/version\s+['"](\d+\.\d+\.\d+)['"]/)
        @successes << '✓ Version is properly formatted'
      else
        @errors << '✗ Version format is incorrect'
      end

      if content.include?('Apache-2.0')
        @successes << '✓ License is set to Apache-2.0'
      else
        @warnings << '⚠ License should be Apache-2.0'
      end
    else
      @errors << '✗ metadata.rb file is missing'
    end
  end

  def validate_recipes
    puts "\nChecking recipes..."
    recipes_dir = File.join(@cookbook_path, 'recipes')

    if Dir.exist?(recipes_dir)
      recipes = Dir.glob(File.join(recipes_dir, '*.rb'))

      required_recipes = %w(default.rb agent.rb server.rb cassandra.rb configure.rb dashboard.rb)

      required_recipes.each do |recipe|
        if recipes.any? { |r| r.end_with?(recipe) }
          @successes << "✓ Found required recipe: #{recipe}"
        else
          @errors << "✗ Missing required recipe: #{recipe}"
        end
      end

      @successes << "✓ Found #{recipes.length} total recipes"
    else
      @errors << '✗ recipes directory is missing'
    end
  end

  def validate_attributes
    puts "\nChecking attributes..."
    attrs_dir = File.join(@cookbook_path, 'attributes')

    if Dir.exist?(attrs_dir)
      attrs = Dir.glob(File.join(attrs_dir, '*.rb'))

      if attrs.any? { |a| a.end_with?('default.rb') }
        @successes << '✓ Found default attributes file'

        # Check for proper attribute namespacing
        content = File.read(File.join(attrs_dir, 'default.rb'))
        if content.include?("default['axonops']")
          @successes << "✓ Attributes are properly namespaced under 'axonops'"
        else
          @warnings << "⚠ Attributes should be namespaced under 'axonops'"
        end
      else
        @errors << '✗ Missing default.rb attributes file'
      end
    else
      @errors << '✗ attributes directory is missing'
    end
  end

  def validate_templates
    puts "\nChecking templates..."
    templates_dir = File.join(@cookbook_path, 'templates')

    if Dir.exist?(templates_dir)
      templates = Dir.glob(File.join(templates_dir, '**/*.erb'))

      required_templates = %w(axon-agent.yml.erb axon-server.yml.erb)

      required_templates.each do |template|
        if templates.any? { |t| t.end_with?(template) }
          @successes << "✓ Found required template: #{template}"
        else
          @warnings << "⚠ Missing template: #{template}"
        end
      end

      @successes << "✓ Found #{templates.length} total templates"
    else
      @warnings << '⚠ templates directory is missing (may be okay if not using templates)'
    end
  end

  def validate_resources
    puts "\nChecking custom resources..."
    resources_dir = File.join(@cookbook_path, 'resources')

    if Dir.exist?(resources_dir)
      resources = Dir.glob(File.join(resources_dir, '*.rb'))

      expected_resources = %w(alert_rule.rb notification.rb service_check.rb backup.rb)

      expected_resources.each do |resource|
        if resources.any? { |r| r.end_with?(resource) }
          @successes << "✓ Found custom resource: #{resource}"
        else
          @warnings << "⚠ Missing custom resource: #{resource}"
        end
      end
    else
      @warnings << '⚠ resources directory is missing (may be okay if not using custom resources)'
    end
  end

  def validate_libraries
    puts "\nChecking libraries..."
    libraries_dir = File.join(@cookbook_path, 'libraries')

    if Dir.exist?(libraries_dir)
      libraries = Dir.glob(File.join(libraries_dir, '*.rb'))

      if libraries.any? { |l| l.end_with?('axonops_api.rb') }
        @successes << '✓ Found AxonOps API library'
      else
        @warnings << '⚠ Missing axonops_api.rb library'
      end
    else
      @warnings << '⚠ libraries directory is missing'
    end
  end

  def validate_tests
    puts "\nChecking tests..."

    # Check for unit tests
    spec_dir = File.join(@cookbook_path, 'spec')
    if Dir.exist?(spec_dir)
      specs = Dir.glob(File.join(spec_dir, '**/*_spec.rb'))
      @successes << "✓ Found #{specs.length} unit test files"

      if File.exist?(File.join(spec_dir, 'spec_helper.rb'))
        @successes << '✓ Found spec_helper.rb'
      else
        @warnings << '⚠ Missing spec_helper.rb'
      end
    else
      @errors << '✗ spec directory is missing (no unit tests)'
    end

    # Check for integration tests
    test_dir = File.join(@cookbook_path, 'test', 'integration')
    if Dir.exist?(test_dir)
      test_suites = Dir.entries(test_dir).reject { |e| e.start_with?('.') }
      @successes << "✓ Found #{test_suites.length} integration test suites"
    else
      @warnings << '⚠ test/integration directory is missing (no integration tests)'
    end
  end

  def validate_kitchen
    puts "\nChecking Test Kitchen configuration..."
    kitchen_file = File.join(@cookbook_path, '.kitchen.yml')

    if File.exist?(kitchen_file)
      @successes << '✓ Found .kitchen.yml'

      begin
        kitchen_config = YAML.load_file(kitchen_file)

        if kitchen_config['suites']
          @successes << "✓ Found #{kitchen_config['suites'].length} test suites"
        else
          @warnings << '⚠ No test suites defined in .kitchen.yml'
        end

        if kitchen_config['platforms']
          @successes << "✓ Testing on #{kitchen_config['platforms'].length} platforms"
        else
          @warnings << '⚠ No platforms defined in .kitchen.yml'
        end
      rescue => e
        @errors << "✗ Error parsing .kitchen.yml: #{e.message}"
      end
    else
      @warnings << '⚠ .kitchen.yml is missing'
    end
  end

  def print_results
    puts "\n" + '=' * 60
    puts 'VALIDATION RESULTS'
    puts '=' * 60

    if @successes.any?
      puts "\nSuccesses (#{@successes.length}):"
      @successes.each { |s| puts "  #{s}" }
    end

    if @warnings.any?
      puts "\nWarnings (#{@warnings.length}):"
      @warnings.each { |w| puts "  #{w}" }
    end

    if @errors.any?
      puts "\nErrors (#{@errors.length}):"
      @errors.each { |e| puts "  #{e}" }
    end

    puts "\n" + '=' * 60
    puts "Summary: #{@successes.length} successes, #{@warnings.length} warnings, #{@errors.length} errors"

    if @errors.empty?
      puts '✓ Cookbook validation PASSED!'
      exit 0
    else
      puts '✗ Cookbook validation FAILED!'
      exit 1
    end
  end
end

# Run validation
validator = CookbookValidator.new(ARGV[0] || '.')
validator.validate!
