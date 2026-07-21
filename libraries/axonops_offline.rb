#
# Cookbook:: axonops
# Library:: axonops_offline
#
# Resolves a single named offline package/tarball to a local filesystem path,
# accepting node['axonops']['offline_packages_path'] as either a local
# directory or an http(s):// base URL. When it's a URL, the file is fetched
# once via remote_file into Chef's file cache and the cached path is
# returned; local directories are used as-is (existing behaviour).
#
module AxonOpsOffline
  def self.remote_path?(base_path)
    base_path.to_s.match?(%r{\Ahttps?://}i)
  end

  # recipe: the recipe/resource run context (self from a recipe file) used to
  # declare the remote_file resource when base_path is a URL.
  # filename: the package/tarball file name, e.g. node['axonops']['offline_packages']['server']
  def self.resolve(recipe, filename, label: filename)
    node = recipe.node
    base_path = node['axonops']['offline_packages_path']

    if remote_path?(base_path)
      source_url = "#{base_path.chomp('/')}/#{filename}"
      cache_dir = ::File.join(Chef::Config[:file_cache_path], 'axonops-offline')
      local_path = ::File.join(cache_dir, filename)

      recipe.directory cache_dir do
        recursive true
        mode '0755'
      end

      recipe.remote_file local_path do
        source source_url
        mode '0644'
        action :create
      end

      local_path
    else
      local_path = ::File.join(base_path, filename)
      unless ::File.exist?(local_path)
        raise "Offline package not found: #{local_path} (#{label})"
      end

      local_path
    end
  end
end
