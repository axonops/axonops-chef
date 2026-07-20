#
# Cookbook:: axonops
# Recipe:: opensearch
#
# Installs OpenSearch (used internally by AxonOps Server for storing
# configuration/search data) from the official OpenSearch package repo —
# previously a manually-extracted Elasticsearch tarball. Package name,
# paths (/etc/opensearch, /usr/share/opensearch, /var/lib/opensearch,
# /var/log/opensearch), user/group (opensearch), and the systemd unit
# (opensearch.service) all come from the package itself; this recipe
# doesn't reinvent any of them the way the old tarball install had to.
# See docs/OPENSEARCH.md.
#

# 'opensearch' is the preferred attribute namespace; 'elastic' is kept for
# backwards compatibility. Merge with opensearch winning key-by-key over
# elastic so either (or both, mixed) can be set in node config.
opensearch_config = node['axonops']['server']['elastic'].to_hash.merge(
  node['axonops']['server']['opensearch'].to_hash.reject { |_, v| v.nil? }
)

opensearch_version = opensearch_config['version']
# OpenSearch publishes a separate package repo per major (…/opensearch/2.x,
# …/opensearch/3.x). Derive the major from the requested version so the repo
# matches; fall back to '3' when the version isn't a plain X.Y.Z (e.g. 'latest').
opensearch_major = opensearch_version.to_s[/\A(\d+)\./, 1] || '3'
opensearch_data_dir = opensearch_config['data_dir']
opensearch_logs_dir = opensearch_config['logs_dir']

# System tuning OpenSearch (like Elasticsearch before it) requires.
execute 'set-vm-max-map-count' do
  command 'sysctl -w vm.max_map_count=262144'
  not_if 'test $(sysctl -n vm.max_map_count) -ge 262144'
  not_if { node['axonops']['skip_vm_max_map_count'] }
end

directory '/etc/sysctl.d' do
  recursive true
end

file '/etc/sysctl.d/99-opensearch.conf' do
  content 'vm.max_map_count=262144'
  mode '0644'
  not_if { node['axonops']['skip_vm_max_map_count'] }
end

if node['axonops']['offline_install']
  package_path = AxonOpsOffline.resolve(self, node['axonops']['offline_packages']['opensearch'])

  case node['platform_family']
  when 'debian'
    dpkg_package 'opensearch' do
      source package_path
      action :install
      notifies :restart, 'service[opensearch]', :delayed
    end
  when 'rhel', 'fedora', 'amazon'
    rpm_package 'opensearch' do
      source package_path
      action :install
      notifies :restart, 'service[opensearch]', :delayed
    end
  end
else
  case node['platform_family']
  when 'debian'
    package %w(apt-transport-https gnupg) do
      action :install
    end

    execute 'add-opensearch-apt-key' do
      command 'curl -o- https://artifacts.opensearch.org/publickeys/opensearch.pgp | ' \
              'gpg --dearmor --batch --yes -o /usr/share/keyrings/opensearch-keyring'
      not_if { ::File.exist?('/usr/share/keyrings/opensearch-keyring') }
    end

    file "/etc/apt/sources.list.d/opensearch-#{opensearch_major}.x.list" do
      content 'deb [signed-by=/usr/share/keyrings/opensearch-keyring] ' \
              "https://artifacts.opensearch.org/releases/bundle/opensearch/#{opensearch_major}.x/apt stable main\n"
      mode '0644'
      notifies :run, 'execute[apt-update-opensearch]', :immediately
    end

    execute 'apt-update-opensearch' do
      command 'apt-get update'
      action :nothing
    end

    apt_package 'opensearch' do
      version opensearch_version
      action :install
      notifies :restart, 'service[opensearch]', :delayed
    end
  when 'rhel', 'fedora', 'amazon'
    execute 'import-opensearch-rpm-key' do
      command 'rpm --import https://artifacts.opensearch.org/publickeys/opensearch.pgp'
      not_if 'rpm -q gpg-pubkey --qf "%{summary}\n" | grep -qi opensearch'
    end

    yum_repository 'opensearch' do
      description "OpenSearch #{opensearch_major}.x"
      baseurl "https://artifacts.opensearch.org/releases/bundle/opensearch/#{opensearch_major}.x/yum"
      gpgkey 'https://artifacts.opensearch.org/publickeys/opensearch.pgp'
      gpgcheck true
      action :create
    end

    package 'opensearch' do
      version opensearch_version
      action :install
      flush_cache [:before]
      notifies :restart, 'service[opensearch]', :delayed
    end
  end
end

directory opensearch_data_dir do
  owner 'opensearch'
  group 'opensearch'
  mode '0750'
  recursive true
end

directory opensearch_logs_dir do
  owner 'opensearch'
  group 'opensearch'
  mode '0750'
  recursive true
end

template '/etc/opensearch/opensearch.yml' do
  source 'opensearch.yml.erb'
  owner 'opensearch'
  group 'opensearch'
  mode '0640'
  variables(
    cluster_name: opensearch_config['cluster_name'],
    node_name: "#{node['hostname']}-axonops",
    listen_host: opensearch_config['listen_address'],
    listen_port: opensearch_config['listen_port'],
    path_data: opensearch_data_dir,
    path_logs: opensearch_logs_dir,
    security_plugin_enabled: opensearch_config['security_plugin_enabled']
  )
  notifies :restart, 'service[opensearch]', :delayed
end

directory '/etc/opensearch/jvm.options.d' do
  owner 'opensearch'
  group 'opensearch'
  mode '0750'
  recursive true
end

template '/etc/opensearch/jvm.options.d/heap.options' do
  source 'opensearch-jvm-heap.options.erb'
  owner 'opensearch'
  group 'opensearch'
  mode '0640'
  variables(heap_size: opensearch_config['heap_size'])
  notifies :restart, 'service[opensearch]', :delayed
end

service 'opensearch' do
  supports status: true, restart: true
  action [:enable, :start]
end

# Wait for OpenSearch to be ready. Bounded retry loop, matching the same
# pattern used by recipes/server.rb's wait-for-axon-server — not
# Timeout.timeout, which interrupts via Thread#raise at an arbitrary point
# (including mid-Net::HTTP.get_response) rather than unwinding cleanly.
ruby_block 'wait-for-opensearch' do
  block do
    require 'net/http'
    require 'uri'

    retries = 30
    uri = URI("http://127.0.0.1:#{opensearch_config['listen_port']}/_cluster/health")

    begin
      retries.times do
        begin
          response = Net::HTTP.get_response(uri)
          break if response.code == '200'
        rescue StandardError
          # Connection refused, keep trying
        end
        sleep 2
      end
    rescue StandardError => e
      Chef::Log.warn("Failed to connect to OpenSearch: #{e.message}")
    end
  end
  action :run
end
