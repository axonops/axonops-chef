require 'chefspec'
require 'chefspec/berkshelf'

RSpec.configure do |config|
  config.color = true
  config.formatter = :documentation
  config.log_level = :error

  # Use chef-zero for fast tests
  config.file_cache_path = Chef::Config[:file_cache_path]

  # Set platform defaults for ChefSpec
  config.platform = 'ubuntu'
  config.version = '20.04'
end
