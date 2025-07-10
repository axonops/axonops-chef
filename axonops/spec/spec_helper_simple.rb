# Simplified spec helper for basic testing without full Chef environment
require 'rspec'
require 'json'

RSpec.configure do |config|
  config.color = true
  config.formatter = :documentation

  # Disable monkey patching
  config.disable_monkey_patching!

  # Use expect syntax
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end

# Only define Chef mock if it's not already loaded
unless defined?(Chef)
  module Chef
    class Log
      def self.info(msg); end
      def self.warn(msg); end
      def self.error(msg); end
    end

    class Recipe; end
    class Resource; end

    module DSL
      module Recipe; end
    end
  end
end

# Load the library files but avoid circular dependencies
lib_path = File.join(File.dirname(__FILE__), '../libraries')
if File.directory?(lib_path)
  Dir[File.join(lib_path, '*.rb')].each do |lib|
    require lib
  end
end
