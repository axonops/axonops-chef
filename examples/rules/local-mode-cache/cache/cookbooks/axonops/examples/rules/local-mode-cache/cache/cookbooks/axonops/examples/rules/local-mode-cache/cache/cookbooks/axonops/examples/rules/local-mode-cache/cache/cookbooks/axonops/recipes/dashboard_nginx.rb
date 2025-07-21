#
# Cookbook:: axonops
# Recipe:: dashboard_nginx
#
# Sets up Nginx as a reverse proxy for AxonOps Dashboard
#

# Only run if nginx proxy is enabled
unless node['axonops']['dashboard']['nginx_proxy']
  Chef::Log.info('Nginx proxy for dashboard is not enabled, skipping nginx setup')
  return
end

# Install nginx
package 'nginx' do
  action :install
end

# Ensure nginx is stopped during configuration
service 'nginx-stop' do
  service_name 'nginx'
  action :stop
  only_if { ::File.exist?('/etc/nginx/sites-enabled/default') }
end

# Remove default nginx site
file '/etc/nginx/sites-enabled/default' do
  action :delete
  notifies :restart, 'service[nginx]', :delayed
end

# SSL certificate validation
if node['axonops']['dashboard']['nginx']['ssl_enabled']
  unless node['axonops']['dashboard']['nginx']['ssl_certificate'] && 
         node['axonops']['dashboard']['nginx']['ssl_certificate_key']
    raise Chef::Exceptions::ConfigurationError, 
          'SSL is enabled but certificate paths are not configured. ' \
          'Please set axonops.dashboard.nginx.ssl_certificate and ssl_certificate_key'
  end
  
  # Verify SSL files exist
  [node['axonops']['dashboard']['nginx']['ssl_certificate'],
   node['axonops']['dashboard']['nginx']['ssl_certificate_key']].each do |ssl_file|
    unless ::File.exist?(ssl_file)
      Chef::Log.warn("SSL file not found: #{ssl_file}")
    end
  end
end

# Create sites-available directory if it doesn't exist
directory '/etc/nginx/sites-available' do
  owner 'root'
  group 'root'
  mode '0755'
end

# Create sites-enabled directory if it doesn't exist
directory '/etc/nginx/sites-enabled' do
  owner 'root'
  group 'root'
  mode '0755'
end

# Generate nginx site configuration
template '/etc/nginx/sites-available/axonops-dashboard' do
  source 'nginx-axonops-dashboard.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    server_name: node['axonops']['dashboard']['nginx']['server_name'],
    listen_port: node['axonops']['dashboard']['nginx']['listen_port'],
    ssl_enabled: node['axonops']['dashboard']['nginx']['ssl_enabled'],
    ssl_port: node['axonops']['dashboard']['nginx']['ssl_port'],
    ssl_certificate: node['axonops']['dashboard']['nginx']['ssl_certificate'],
    ssl_certificate_key: node['axonops']['dashboard']['nginx']['ssl_certificate_key'],
    dashboard_address: node['axonops']['dashboard']['listen_address'],
    dashboard_port: node['axonops']['dashboard']['listen_port'],
    context_path: node['axonops']['dashboard']['context_path'] || '',
    client_max_body_size: node['axonops']['dashboard']['nginx']['client_max_body_size'],
    proxy_read_timeout: node['axonops']['dashboard']['nginx']['proxy_read_timeout'],
    proxy_connect_timeout: node['axonops']['dashboard']['nginx']['proxy_connect_timeout'],
    proxy_send_timeout: node['axonops']['dashboard']['nginx']['proxy_send_timeout']
  )
  notifies :restart, 'service[nginx]', :delayed
end

# Enable the site
link '/etc/nginx/sites-enabled/axonops-dashboard' do
  to '/etc/nginx/sites-available/axonops-dashboard'
  notifies :restart, 'service[nginx]', :delayed
end

# Test nginx configuration
execute 'test-nginx-config' do
  command 'nginx -t'
  action :run
  notifies :restart, 'service[nginx]', :delayed
end

# Enable and start nginx service
service 'nginx' do
  supports status: true, restart: true, reload: true
  action [:enable, :start]
end

# Log access information
log 'nginx-proxy-info' do
  message lazy {
    if node['axonops']['dashboard']['nginx']['ssl_enabled']
      "AxonOps Dashboard is available via nginx proxy at https://#{node['axonops']['dashboard']['nginx']['server_name']}:#{node['axonops']['dashboard']['nginx']['ssl_port']}#{node['axonops']['dashboard']['context_path']}"
    else
      "AxonOps Dashboard is available via nginx proxy at http://#{node['axonops']['dashboard']['nginx']['server_name']}:#{node['axonops']['dashboard']['nginx']['listen_port']}#{node['axonops']['dashboard']['context_path']}"
    end
  }
  level :info
end
