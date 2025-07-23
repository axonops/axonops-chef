require 'rspec/core/rake_task'
require 'cookstyle'
require 'rubocop/rake_task'
require 'kitchen'

# Style tests. cookstyle (rubocop) and Foodcritic
namespace :style do
  desc 'Run Ruby style checks'
  RuboCop::RakeTask.new(:ruby)
end

desc 'Run all style checks'
task style: 'style:ruby'

# ChefSpec unit tests
desc 'Run ChefSpec unit tests'
RSpec::Core::RakeTask.new(:unit) do |t|
  t.rspec_opts = '--color --format documentation'
  t.pattern = 'spec/unit/**/*_spec.rb'
end

# Integration tests with Test Kitchen
desc 'Run Test Kitchen integration tests'
task :integration do
  Kitchen.logger = Kitchen.default_file_logger
  Kitchen::Config.new.instances.each do |instance|
    instance.test(:always)
  end
end

desc 'Run all tests'
task test: %i(style unit)

task default: :test
