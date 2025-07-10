#!/usr/bin/env ruby

# Simple syntax validation for all Ruby files in the cookbook

require 'open3'

def check_ruby_syntax(file)
  stdout, stderr, status = Open3.capture3("ruby -c #{file}")

  if status.success?
    { file: file, status: :pass, message: stdout.strip }
  else
    { file: file, status: :fail, message: stderr.strip }
  end
end

def check_erb_syntax(file)
  # Basic ERB syntax check
  begin
    content = File.read(file)
    # Check for basic ERB syntax issues
    if content.scan(/<%/).length != content.scan(/%>/).length
      { file: file, status: :fail, message: 'Mismatched ERB tags' }
    else
      { file: file, status: :pass, message: 'ERB syntax OK' }
    end
  rescue => e
    { file: file, status: :fail, message: e.message }
  end
end

puts 'AxonOps Cookbook Syntax Validation'
puts '=' * 50

# Find all Ruby files
ruby_files = Dir.glob('**/*.rb').reject { |f| f.start_with?('test_syntax.rb', 'validate_cookbook.rb') }
erb_files = Dir.glob('**/*.erb')

errors = []
warnings = []

puts "\nChecking Ruby syntax (#{ruby_files.length} files)..."
ruby_files.each do |file|
  result = check_ruby_syntax(file)

  case result[:status]
  when :pass
    print '.'
  when :fail
    print 'F'
    errors << result
  end
end

puts "\n\nChecking ERB syntax (#{erb_files.length} files)..."
erb_files.each do |file|
  result = check_erb_syntax(file)

  case result[:status]
  when :pass
    print '.'
  when :fail
    print 'F'
    errors << result
  end
end

puts "\n\n" + '=' * 50
puts 'RESULTS'
puts '=' * 50

if errors.empty?
  puts "\n✓ All syntax checks passed!"
  puts "  - #{ruby_files.length} Ruby files OK"
  puts "  - #{erb_files.length} ERB templates OK"
else
  puts "\n✗ Found #{errors.length} syntax errors:\n\n"

  errors.each do |error|
    puts "File: #{error[:file]}"
    puts "Error: #{error[:message]}"
    puts '-' * 30
  end
end

# Check for common issues
puts "\n" + '=' * 50
puts 'COMMON ISSUES CHECK'
puts '=' * 50

# Check for missing 'end' keywords
ruby_files.each do |file|
  content = File.read(file)

  # Count various block starters and 'end' keywords
  block_starters = content.scan(/\b(class|module|def|if|unless|case|while|until|for|begin|do)\b/).length
  end_count = content.scan(/\bend\b/).length

  if block_starters > end_count + 5 # Allow some tolerance for inline blocks
    warnings << "#{file}: Possible missing 'end' statements (#{block_starters} blocks, #{end_count} ends)"
  end
end

if warnings.any?
  puts "\nWarnings:"
  warnings.each { |w| puts "  ⚠ #{w}" }
end

puts "\nSyntax validation complete!"
exit(errors.empty? ? 0 : 1)
