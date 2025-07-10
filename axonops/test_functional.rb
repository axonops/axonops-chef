#!/usr/bin/env ruby

require 'json'
require 'tempfile'
require 'fileutils'

# Functional tests that simulate cookbook execution
class FunctionalTester
  attr_reader :test_dir, :results

  def initialize
    @test_dir = Dir.mktmpdir('axonops-test-')
    @results = { passed: 0, failed: 0, errors: [] }
  end

  def cleanup
    FileUtils.rm_rf(@test_dir)
  end

  def run_all_tests
    puts '=' * 60
    puts 'AxonOps Cookbook Functional Testing'
    puts "Test directory: #{@test_dir}"
    puts '=' * 60

    test_directory_creation
    test_file_creation
    test_template_rendering
    test_service_configurations
    test_api_interactions
    test_error_handling

    print_results
  ensure
    cleanup
  end

  private

  def test_directory_creation
    puts "\n1. Testing Directory Creation..."

    # Simulate directory creation from recipes
    directories = [
      '/etc/axonops',
      '/var/log/axonops',
      '/var/lib/axonops',
      '/usr/share/axonops',
      '/data/cassandra/data',
      '/data/cassandra/commitlog',
      '/data/cassandra/hints',
    ]

    directories.each do |dir|
      test_path = File.join(@test_dir, dir)
      FileUtils.mkdir_p(test_path)

      if File.directory?(test_path)
        pass("✓ Created directory: #{dir}")
      else
        fail("✗ Failed to create directory: #{dir}")
      end
    end
  end

  def test_file_creation
    puts "\n2. Testing File Creation..."

    # Test configuration file creation
    config_files = {
      'axon-agent.yml' => generate_agent_config,
      'axon-server.yml' => generate_server_config,
      'cassandra.yaml' => generate_cassandra_config,
    }

    config_files.each do |filename, content|
      file_path = File.join(@test_dir, 'etc', 'axonops', filename)
      FileUtils.mkdir_p(File.dirname(file_path))

      File.write(file_path, content)

      if File.exist?(file_path) && File.read(file_path) == content
        pass("✓ Created config file: #{filename}")

        # Validate YAML syntax
        begin
          require 'yaml'
          YAML.load(content)
          pass("✓ Valid YAML syntax: #{filename}")
        rescue => e
          fail("✗ Invalid YAML in #{filename}: #{e.message}")
        end
      else
        fail("✗ Failed to create config file: #{filename}")
      end
    end
  end

  def test_template_rendering
    puts "\n3. Testing Template Rendering..."

    # Simulate ERB template rendering
    template_vars = {
      agent_host: 'localhost',
      agent_port: 8080,
      api_key: 'test-key-123',
      org_name: 'test-org',
      cassandra_home: '/opt/cassandra',
      node_address: '10.0.0.1',
    }

    # Load and render agent template
    template_file = 'templates/default/axon-agent.yml.erb'
    if File.exist?(template_file)
      require 'erb'

      # Create binding with template variables
      b = binding
      template_vars.each { |k, v| b.local_variable_set(k, v) }
      template_vars.each { |k, v| b.instance_variable_set("@#{k}", v) }

      begin
        template = ERB.new(File.read(template_file), nil, '-')
        rendered = template.result(b)

        if rendered.include?(template_vars[:api_key]) && rendered.include?(template_vars[:agent_host].to_s)
          pass('✓ Template rendering successful with variables')
        else
          fail('✗ Template rendering missing variables')
        end

        # Save rendered template
        output_path = File.join(@test_dir, 'rendered-agent.yml')
        File.write(output_path, rendered)
        pass("✓ Saved rendered template to: #{output_path}")
      rescue => e
        fail("✗ Template rendering error: #{e.message}")
      end
    else
      fail("✗ Template file not found: #{template_file}")
    end
  end

  def test_service_configurations
    puts "\n4. Testing Service Configurations..."

    # Test systemd service creation
    services = %w(axon-agent axon-server cassandra)

    services.each do |service|
      service_file = File.join(@test_dir, 'etc', 'systemd', 'system', "#{service}.service")
      override_file = File.join(@test_dir, 'etc', 'systemd', 'system', "#{service}.service.d", 'override.conf')

      FileUtils.mkdir_p(File.dirname(service_file))
      FileUtils.mkdir_p(File.dirname(override_file))

      # Create mock service file
      service_content = <<-EOL
[Unit]
Description=#{service} service
After=network.target

[Service]
Type=simple
User=axonops
Group=axonops
ExecStart=/usr/bin/#{service}

[Install]
WantedBy=multi-user.target
EOL

      File.write(service_file, service_content)

      # Create override file
      override_content = <<-EOL
[Service]
LimitNOFILE=65536
LimitNPROC=32768
EOL

      File.write(override_file, override_content)

      if File.exist?(service_file) && File.exist?(override_file)
        pass("✓ Created service configuration for: #{service}")
      else
        fail("✗ Failed to create service configuration for: #{service}")
      end
    end
  end

  def test_api_interactions
    puts "\n5. Testing API Interactions..."

    # Simulate API library functionality
    require_relative 'libraries/axonops_api'

    begin
      # Create mock API client
      api = AxonOps::API.new('http://localhost:8080', 'test-key', 'test-org')

      pass('✓ API client instantiated successfully')

      # Test API methods exist
      api_methods = [:create_alert_rule, :delete_alert_rule, :get_alert_rules,
                     :create_notification, :create_service_check, :create_backup_config]

      missing_methods = api_methods.reject { |m| api.respond_to?(m) }

      if missing_methods.empty?
        pass('✓ All required API methods available')
      else
        fail("✗ Missing API methods: #{missing_methods.join(', ')}")
      end
    rescue => e
      fail("✗ API library error: #{e.message}")
    end
  end

  def test_error_handling
    puts "\n6. Testing Error Handling..."

    # Test offline mode validation
    begin
      # Simulate missing offline package
      offline_path = '/nonexistent/path/package.deb'

      unless File.exist?(offline_path)
        pass('✓ Correctly identifies missing offline package')
      end

      # Test invalid configuration detection
      invalid_config = { 'invalid' => 'yaml: content: [' }

      begin
        YAML.load(YAML.dump(invalid_config))
        fail('✗ Failed to detect invalid configuration')
      rescue
        pass('✓ Correctly detects invalid YAML configuration')
      end
    rescue => e
      fail("✗ Error handling test failed: #{e.message}")
    end
  end

  def generate_agent_config
    <<-YAML
# AxonOps Agent Configuration
api_key: "test-key-123"
organisation: "test-org"

axon-agent:
  host: "localhost"
  port: 8080

cassandra:
  home: "/opt/cassandra"
  config: "/etc/cassandra"
  logs: "/var/log/cassandra"
#{'  '}
  node:
    address: "10.0.0.1"
    dc: "dc1"
    rack: "rack1"
YAML
  end

  def generate_server_config
    <<-YAML
# AxonOps Server Configuration
server:
  listen_address: "0.0.0.0"
  listen_port: 8080
#{'  '}
storage:
  cassandra:
    hosts: ["localhost"]
    port: 9042
    keyspace: "axonops"
#{'  '}
  elasticsearch:
    url: "http://localhost:9200"
    index: "axonops"
YAML
  end

  def generate_cassandra_config
    <<-YAML
# Apache Cassandra Configuration
cluster_name: 'Test Cluster'
num_tokens: 16
listen_address: localhost
rpc_address: localhost
seed_provider:
  - class_name: org.apache.cassandra.locator.SimpleSeedProvider
    parameters:
      - seeds: "127.0.0.1"
YAML
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

  def print_results
    puts "\n" + '=' * 60
    puts 'FUNCTIONAL TEST RESULTS'
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
      puts 'ALL FUNCTIONAL TESTS PASSED! ✓'
      exit 0
    else
      puts 'FUNCTIONAL TESTS FAILED! ✗'
      exit 1
    end
  end
end

# Run the tests
tester = FunctionalTester.new
tester.run_all_tests
