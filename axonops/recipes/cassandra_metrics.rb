#
# Cookbook:: cassandra-ops
# Recipe:: cassandra_tarball
#
# Installs Cassandra from tarball for AxonOps metrics storage
#

# Install Java first
include_recipe 'axonops::java'

# Define installation paths
cassandra_version = node['axonops']['server']['cassandra']['version']
cassandra_install_dir = node['axonops']['server']['cassandra']['install_dir']
cassandra_data_root = node['axonops']['server']['cassandra']['data_dir']
cassandra_user = 'cassandra'
cassandra_group = 'cassandra'

# Create cassandra user and group
group cassandra_group do
  system true
  action :create
end

user cassandra_user do
  group cassandra_group
  system true
  shell '/bin/false'
  home cassandra_data_root
  manage_home false
  action :create
end

# Create required directories
[
  cassandra_install_dir,
  cassandra_data_root,
  "#{cassandra_data_root}/data",
  "#{cassandra_data_root}/commitlog",
  "#{cassandra_data_root}/saved_caches",
  "#{cassandra_data_root}/hints",
  '/var/log/axonops-cassandra',
  '/etc/axonops-cassandra',
].each do |dir|
  directory dir do
    owner cassandra_user
    group cassandra_group
    mode '0755'
    recursive true
  end
end

# Download or copy Cassandra tarball
if node['axonops']['offline_install']
  # Offline installation
  tarball_name = node['axonops']['packages']['cassandra_tarball'] || "apache-cassandra-#{cassandra_version}-bin.tar.gz"
  tarball_path = ::File.join(node['axonops']['offline_packages_path'], tarball_name)

  unless ::File.exist?(tarball_path)
    raise("Offline Cassandra tarball not found: #{tarball_path}")
  end

  # Copy tarball to temp location
  execute 'copy-cassandra-tarball' do
    command "cp #{tarball_path} /tmp/#{tarball_name}"
    not_if { ::File.exist?("/tmp/#{tarball_name}") }
  end

  tarball_source = "/tmp/#{tarball_name}"
else
  # Online installation
  tarball_url = node['axonops']['server']['cassandra']['tarball_url'] ||
                "https://archive.apache.org/dist/cassandra/#{cassandra_version}/apache-cassandra-#{cassandra_version}-bin.tar.gz"

  remote_file "/tmp/cassandra-#{cassandra_version}.tar.gz" do
    source tarball_url
    checksum node['axonops']['server']['cassandra']['tarball_checksum'] if node['axonops']['server']['cassandra']['tarball_checksum']
    owner 'root'
    group 'root'
    mode '0644'
    action :create
  end

  tarball_source = "/tmp/cassandra-#{cassandra_version}.tar.gz"
end

# Extract Cassandra
execute 'extract-cassandra' do
  command <<-EOH
    tar -xzf #{tarball_source} -C #{cassandra_install_dir} --strip-components=1
    chown -R #{cassandra_user}:#{cassandra_group} #{cassandra_install_dir}
  EOH
  not_if { ::File.exist?("#{cassandra_install_dir}/bin/cassandra") }
end

# Configure Cassandra for AxonOps metrics
template "#{cassandra_install_dir}/conf/cassandra.yaml" do
  source 'axonops-cassandra.yaml.erb'
  owner cassandra_user
  group cassandra_group
  mode '0640'
  variables(
    cluster_name: 'AxonOps Metrics',
    data_dir: "#{cassandra_data_root}/data",
    commitlog_dir: "#{cassandra_data_root}/commitlog",
    saved_caches_dir: "#{cassandra_data_root}/saved_caches",
    hints_dir: "#{cassandra_data_root}/hints",
    listen_address: '127.0.0.1',
    rpc_address: '127.0.0.1',
    seeds: '127.0.0.1',
    dc: node['axonops']['server']['cassandra']['dc'],
    rack: 'rack1',
    authenticator: 'AllowAllAuthenticator', # Simple auth for local metrics
    authorizer: 'AllowAllAuthorizer'
  )
  notifies :restart, 'service[axonops-cassandra]', :delayed
end

# JVM options
template "#{cassandra_install_dir}/conf/jvm-server.options" do
  source 'cassandra-jvm.options.erb'
  owner cassandra_user
  group cassandra_group
  mode '0640'
  variables(
    heap_size: '1G', # Small heap for metrics storage
    new_heap_size: '256M'
  )
  notifies :restart, 'service[axonops-cassandra]', :delayed
  only_if { cassandra_version.to_f >= 4.0 }
end

# Configure cassandra-env.sh
template "#{cassandra_install_dir}/conf/cassandra-env.sh" do
  source 'cassandra-env.sh.erb'
  owner cassandra_user
  group cassandra_group
  mode '0755'
  variables(
    heap_size: '1G',
    new_heap_size: '256M',
    log_dir: '/var/log/axonops-cassandra'
  )
  notifies :restart, 'service[axonops-cassandra]', :delayed
end

# Create systemd service
systemd_unit 'axonops-cassandra.service' do
  content <<-EOU
[Unit]
Description=AxonOps Cassandra Metrics Storage
After=network.target

[Service]
Type=forking
PIDFile=/var/run/axonops-cassandra/cassandra.pid
User=#{cassandra_user}
Group=#{cassandra_group}

RuntimeDirectory=axonops-cassandra
Environment=CASSANDRA_HOME=#{cassandra_install_dir}
Environment=CASSANDRA_CONF=#{cassandra_install_dir}/conf

ExecStart=#{cassandra_install_dir}/bin/cassandra -p /var/run/axonops-cassandra/cassandra.pid
ExecStop=/bin/kill -TERM $MAINPID

LimitNOFILE=100000
LimitMEMLOCK=infinity
LimitNPROC=32768
LimitAS=infinity

StandardOutput=journal
StandardError=journal

RestartSec=30
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOU
  action [:create, :enable]
  notifies :restart, 'service[axonops-cassandra]', :delayed
end

# Enable and start Cassandra
service 'axonops-cassandra' do
  supports status: true, restart: true
  action [:enable, :start]
end

# Wait for Cassandra to be ready
ruby_block 'wait-for-cassandra' do
  block do
    require 'socket'

    retries = 30
    port = 9042

    begin
      retries.times do
        begin
          socket = TCPSocket.new('127.0.0.1', port)
          socket.close
          break
        rescue Errno::ECONNREFUSED
          # Connection refused, keep trying
          sleep 2
        end
      end
    rescue StandardError => e
      Chef::Log.warn("Failed to connect to Cassandra: #{e.message}")
    end
  end
  action :run
end
