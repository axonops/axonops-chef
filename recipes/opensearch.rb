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

# Repository signing key. The 3.x repositories are signed with the 2025
# release key (opensearch-release.pgp, the key the upstream
# opensearch-3.x.repo file names). The 2.x repositories still use the 2021
# key (opensearch.pgp), whose self-signature uses SHA-1 — EL9/EL10 crypto
# policies reject it: "Signature not supported. Hash algorithm SHA1 not
# available." rpm_key_id is the rpm gpg-pubkey version (last 8 hex digits
# of the key ID) used to check the key is already imported.
opensearch_key = if opensearch_major.to_i >= 3
                   { 'file' => 'opensearch-release.pgp', 'rpm_key_id' => '81191457' }
                 else
                   { 'file' => 'opensearch.pgp', 'rpm_key_id' => '9310d3fc' }
                 end
opensearch_key_url = "https://artifacts.opensearch.org/publickeys/#{opensearch_key['file']}"
opensearch_keyring = "/usr/share/keyrings/#{opensearch_key['file'].sub(/\.pgp\z/, '')}-keyring"
opensearch_data_dir = opensearch_config['data_dir']
opensearch_logs_dir = opensearch_config['logs_dir']

# The top-level merge above is shallow, so merge the nested snapshot hash on
# its own: a partial node['axonops']['server']['opensearch']['snapshot'] then
# overrides single keys instead of replacing every default.
snapshot_config = AxonOpsOpenSearchSnapshot.config(
  node['axonops']['server']['elastic']['snapshot'].to_hash,
  node['axonops']['server']['opensearch'].to_hash['snapshot'] || {}
)
snapshot_enabled = AxonOpsOpenSearchSnapshot.enabled?(snapshot_config)
AxonOpsOpenSearchSnapshot.validate!(snapshot_config) if snapshot_enabled

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
  else
    AxonOpsOffline.unsupported_platform!(node, 'opensearch')
  end
else
  case node['platform_family']
  when 'debian'
    package %w(apt-transport-https gnupg) do
      action :install
    end

    execute 'add-opensearch-apt-key' do
      command "curl -fsSL #{opensearch_key_url} | gpg --dearmor --batch --yes -o #{opensearch_keyring}"
      not_if { ::File.exist?(opensearch_keyring) }
    end

    file "/etc/apt/sources.list.d/opensearch-#{opensearch_major}.x.list" do
      content "deb [signed-by=#{opensearch_keyring}] " \
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
      command "rpm --import #{opensearch_key_url}"
      not_if "rpm -q gpg-pubkey-#{opensearch_key['rpm_key_id']}"
    end

    yum_repository 'opensearch' do
      description "OpenSearch #{opensearch_major}.x"
      baseurl "https://artifacts.opensearch.org/releases/bundle/opensearch/#{opensearch_major}.x/yum"
      gpgkey opensearch_key_url
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
    security_plugin_enabled: opensearch_config['security_plugin_enabled'],
    snapshot_settings: snapshot_enabled ? AxonOpsOpenSearchSnapshot.client_settings(snapshot_config) : {}
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

# Java temporary directory. On a CIS-hardened host (Amazon Linux 2023 and
# others) /tmp is mounted noexec, so the JVM cannot execute the native
# libraries it unpacks into java.io.tmpdir and OpenSearch never starts. Point
# java.io.tmpdir — and OPENSEARCH_TMPDIR, which opensearch-env otherwise
# derives from `mktemp -d` under /tmp — at a cookbook-owned executable
# directory. An empty value or '/tmp' keeps the OS default and manages nothing.
opensearch_java_tmp_dir = opensearch_config['java_tmp_dir'].to_s
manage_java_tmp_dir = !opensearch_java_tmp_dir.empty? && opensearch_java_tmp_dir != '/tmp'

directory opensearch_java_tmp_dir do
  owner 'opensearch'
  group 'opensearch'
  mode '0750'
  recursive true
  only_if { manage_java_tmp_dir }
end

# Drop-in read after the package's own jvm.options; the last -D wins, so this
# needs no patching of the package-owned file. Removed again if the OS default
# is restored.
template '/etc/opensearch/jvm.options.d/tmpdir.options' do
  source 'opensearch-jvm-tmpdir.options.erb'
  owner 'opensearch'
  group 'opensearch'
  mode '0640'
  variables(java_tmp_dir: opensearch_java_tmp_dir)
  notifies :restart, 'service[opensearch]', :delayed
  only_if { manage_java_tmp_dir }
end

file '/etc/opensearch/jvm.options.d/tmpdir.options' do
  action :delete
  notifies :restart, 'service[opensearch]', :delayed
  not_if { manage_java_tmp_dir }
end

# systemd drop-in so the launcher and the plugins that read OPENSEARCH_TMPDIR
# stop defaulting to /tmp as well.
directory '/etc/systemd/system/opensearch.service.d' do
  mode '0755'
  recursive true
  only_if { manage_java_tmp_dir }
end

template '/etc/systemd/system/opensearch.service.d/tmpdir.conf' do
  source 'opensearch-systemd-tmpdir.conf.erb'
  mode '0644'
  variables(java_tmp_dir: opensearch_java_tmp_dir)
  notifies :run, 'execute[opensearch-systemd-daemon-reload]', :immediately
  notifies :restart, 'service[opensearch]', :delayed
  only_if { manage_java_tmp_dir }
end

file '/etc/systemd/system/opensearch.service.d/tmpdir.conf' do
  action :delete
  notifies :run, 'execute[opensearch-systemd-daemon-reload]', :immediately
  notifies :restart, 'service[opensearch]', :delayed
  not_if { manage_java_tmp_dir }
end

execute 'opensearch-systemd-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

if snapshot_enabled
  # Before the service starts: OpenSearch refuses to start with s3.*/gcs.*
  # settings in opensearch.yml when the repository plugin is missing.
  snapshot_plugin = "repository-#{snapshot_config['type']}"
  snapshot_plugin_dir = "/usr/share/opensearch/plugins/#{snapshot_plugin}"
  snapshot_keystore = '/etc/opensearch/opensearch.keystore'
  snapshot_keystore_marker = '/etc/opensearch/.snapshot_keystore.sha256'
  snapshot_gcs_tmp = '/etc/opensearch/.snapshot-gcs-credentials.json'
  snapshot_restart_marker = '/etc/opensearch/.snapshot_restart_pending'
  keystore_cli = '/usr/share/opensearch/bin/opensearch-keystore'
  snapshot_cli_env = { 'OPENSEARCH_PATH_CONF' => '/etc/opensearch' }
  if manage_java_tmp_dir
    snapshot_cli_env['OPENSEARCH_JAVA_OPTS'] = "-Djava.io.tmpdir=#{opensearch_java_tmp_dir}"
    snapshot_cli_env['OPENSEARCH_TMPDIR'] = opensearch_java_tmp_dir
  end

  snapshot_plugin_source =
    if node['axonops']['offline_install']
      offline_key = "opensearch_#{snapshot_plugin.tr('-', '_')}"
      "file://#{AxonOpsOffline.resolve(self, node['axonops']['offline_packages'][offline_key], label: offline_key)}"
    else
      snapshot_plugin
    end

  installed_plugin_version = lambda do
    descriptor = ::File.join(snapshot_plugin_dir, 'plugin-descriptor.properties')
    AxonOpsOpenSearchSnapshot.plugin_version(::File.exist?(descriptor) ? ::File.read(descriptor) : nil)
  end
  pinned_version = opensearch_version.to_s.match?(/\A\d+\.\d+\.\d+\z/)

  # A node that is already running must restart before the repository can be
  # registered. A fresh install needs no extra restart: the service starts
  # below, after the plugin and keystore are in place.
  # The pending marker survives a failed run, so the restart still happens on
  # the next converge even though the plugin and keystore are then in sync.
  ruby_block 'opensearch-snapshot-restart-pending' do
    block do
      if shell_out('systemctl', 'is-active', '--quiet', 'opensearch').exitstatus.zero?
        ::File.write(snapshot_restart_marker, '')
      end
    end
    action :nothing
  end

  # OpenSearch will not start with a plugin built for another version, so a
  # package upgrade needs the plugin reinstalled.
  execute "remove-opensearch-#{snapshot_plugin}" do
    command ['/usr/share/opensearch/bin/opensearch-plugin', 'remove', snapshot_plugin]
    environment snapshot_cli_env
    only_if { pinned_version && ::Dir.exist?(snapshot_plugin_dir) && installed_plugin_version.call != opensearch_version.to_s }
  end

  execute "install-opensearch-#{snapshot_plugin}" do
    command ['/usr/share/opensearch/bin/opensearch-plugin', 'install', '--batch', snapshot_plugin_source]
    environment snapshot_cli_env
    creates snapshot_plugin_dir
    notifies :run, 'ruby_block[opensearch-snapshot-restart-pending]', :immediately
  end

  # opensearch-plugin runs as root and leaves the plugin's config directory
  # root-only, so OpenSearch fails to start with AccessDeniedException on it.
  snapshot_plugin_conf = "/etc/opensearch/#{snapshot_plugin}"
  execute "opensearch-#{snapshot_plugin}-config-permissions" do
    command "chgrp -R opensearch #{snapshot_plugin_conf} && chmod -R g+rX,o-rwx #{snapshot_plugin_conf}"
    only_if do
      ::Dir.exist?(snapshot_plugin_conf) &&
        !shell_out('find', snapshot_plugin_conf,
                   '(', '!', '-group', 'opensearch', '-o', '!', '-perm', '-g=r',
                   '-o', '-type', 'd', '!', '-perm', '-g=x', ')', '-print', '-quit').stdout.empty?
    end
  end

  snapshot_entries = AxonOpsOpenSearchSnapshot.keystore_entries(snapshot_config)
  read_keystore_marker = lambda do
    ::File.exist?(snapshot_keystore_marker) ? ::File.read(snapshot_keystore_marker) : nil
  end
  keystore_list = lambda do
    next [] unless ::File.exist?(snapshot_keystore)

    shell_out!(keystore_cli, 'list', environment: snapshot_cli_env).stdout.split("\n").map(&:strip)
  end

  ruby_block 'opensearch-snapshot-keystore' do
    block do
      if !snapshot_entries.empty? && !::File.exist?(snapshot_keystore)
        shell_out!(keystore_cli, 'create', environment: snapshot_cli_env)
      end
      previous_keys = AxonOpsOpenSearchSnapshot.parse_marker(read_keystore_marker.call)['keys']
      AxonOpsOpenSearchSnapshot.unwanted_entries(keystore_list.call, snapshot_entries, snapshot_config, previous_keys).each do |entry|
        shell_out!(keystore_cli, 'remove', entry, environment: snapshot_cli_env)
      end
      snapshot_entries.each do |key, value|
        if key.end_with?('.credentials_file')
          begin
            ::File.open(snapshot_gcs_tmp, ::File::WRONLY | ::File::CREAT | ::File::TRUNC, 0o600) { |f| f.write(value) }
            shell_out!(keystore_cli, 'add-file', '--force', key, snapshot_gcs_tmp, environment: snapshot_cli_env)
          ensure
            ::FileUtils.rm_f(snapshot_gcs_tmp)
          end
        else
          shell_out!(keystore_cli, 'add', '--stdin', '--force', key, input: value, environment: snapshot_cli_env)
        end
      end
      ::File.open(snapshot_keystore_marker, ::File::WRONLY | ::File::CREAT | ::File::TRUNC, 0o600) do |f|
        f.write("#{AxonOpsOpenSearchSnapshot.marker(snapshot_entries)}\n")
      end
    end
    sensitive true
    not_if do
      if ::File.exist?(snapshot_keystore)
        AxonOpsOpenSearchSnapshot.keystore_in_sync?(keystore_list.call, snapshot_entries, snapshot_config, read_keystore_marker.call)
      else
        snapshot_entries.empty?
      end
    end
    notifies :run, 'ruby_block[opensearch-snapshot-restart-pending]', :immediately
  end

  file snapshot_keystore do
    owner 'root'
    group 'opensearch'
    mode '0640'
    only_if { ::File.exist?(snapshot_keystore) }
  end
end

service 'opensearch' do
  supports status: true, restart: true
  action [:enable, :start]
end

if snapshot_enabled
  service 'opensearch-snapshot-restart' do
    service_name 'opensearch'
    action :restart
    only_if { ::File.exist?(snapshot_restart_marker) }
  end

  file snapshot_restart_marker do
    action :delete
  end
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

# Repository and Snapshot Management policy, registered through the local
# REST API once the node answers. Restoring snapshots is not automated.
if snapshot_enabled && snapshot_config['register']
  snapshot_host = opensearch_config['listen_address'].to_s
  snapshot_host = '127.0.0.1' if snapshot_host.empty? || snapshot_host == '0.0.0.0'
  snapshot_api = AxonOpsOpenSearchSnapshot::Client.new(
    "#{opensearch_config['security_plugin_enabled'] ? 'https' : 'http'}://#{snapshot_host}:#{opensearch_config['listen_port']}",
    username: node['axonops']['server']['search_db']['username'],
    password: node['axonops']['server']['search_db']['password']
  )
  snapshot_repository = snapshot_config['repository_name']
  snapshot_repository_path = "/_snapshot/#{snapshot_repository}"
  snapshot_repository_body = AxonOpsOpenSearchSnapshot.repository_body(snapshot_config)

  ruby_block "opensearch-snapshot-repository-#{snapshot_repository}" do
    block { snapshot_api.request!(:put, snapshot_repository_path, snapshot_repository_body) }
    not_if do
      status, current = snapshot_api.request!(:get, snapshot_repository_path, ok: [200, 404])
      status == 200 && current[snapshot_repository] == snapshot_repository_body
    end
  end

  unless snapshot_config['policy'].nil? || snapshot_config['policy'].empty?
    snapshot_policy_path = "/_plugins/_sm/policies/#{snapshot_config['policy']['name']}"
    snapshot_policy_body = AxonOpsOpenSearchSnapshot.policy_body(snapshot_config)

    # Removing a key from the policy attribute does not remove it from an
    # existing policy; delete the policy and converge again for that.
    ruby_block "opensearch-snapshot-policy-#{snapshot_config['policy']['name']}" do
      block do
        status, current = snapshot_api.request!(:get, snapshot_policy_path, ok: [200, 404])
        if status == 404
          snapshot_api.request!(:post, snapshot_policy_path, snapshot_policy_body, ok: [200, 201])
        else
          snapshot_api.request!(
            :put,
            "#{snapshot_policy_path}?if_seq_no=#{current['_seq_no']}&if_primary_term=#{current['_primary_term']}",
            snapshot_policy_body
          )
        end
      end
      not_if do
        status, current = snapshot_api.request!(:get, snapshot_policy_path, ok: [200, 404])
        status == 200 && AxonOpsOpenSearchSnapshot.policy_in_sync?(current['sm_policy'], snapshot_policy_body)
      end
    end
  end
end
