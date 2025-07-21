# InSpec test for recipe axonops::dashboard

control 'axonops-dashboard-installation' do
  impact 1.0
  title 'AxonOps Dashboard Installation'
  desc 'Verify AxonOps dashboard is properly installed'

  describe package('axon-dash') do
    it { should be_installed }
  end

  # Web files should exist
  describe directory('/usr/share/axonops-dashboard') do
    it { should exist }
    its('owner') { should eq 'axonops' }
    its('group') { should eq 'axonops' }
  end

  %w(
    /usr/share/axonops-dashboard/public
    /usr/share/axonops-dashboard/assets
    /etc/axonops-dashboard
    /var/log/axonops-dashboard
  ).each do |dir|
    describe directory(dir) do
      it { should exist }
      its('owner') { should eq 'axonops' }
      its('group') { should eq 'axonops' }
    end
  end
end

control 'axonops-dashboard-configuration' do
  impact 1.0
  title 'AxonOps Dashboard Configuration'
  desc 'Verify dashboard configuration'

  describe file('/etc/axonops-dashboard/config.json') do
    it { should exist }
    its('owner') { should eq 'axonops' }
    its('group') { should eq 'axonops' }
    its('mode') { should cmp '0644' }

    # Verify JSON is valid
    describe json(content: File.read('/etc/axonops-dashboard/config.json')) do
      its('api_url') { should_not be_nil }
      its('api_url') { should match %r{https?://} }
    end
  end

  describe file('/etc/axonops-dashboard/nginx.conf') do
    it { should exist }
    its('content') { should match /listen\s+3000/ }
    its('content') { should match %r{root\s+/usr/share/axonops-dashboard} }
    its('content') { should match %r{location\s+/api} }
  end
end

control 'axonops-dashboard-service' do
  impact 1.0
  title 'AxonOps Dashboard Service'
  desc 'Verify dashboard service is running'

  describe systemd_service('axon-dash') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  describe port(3000) do
    it { should be_listening }
    its('protocols') { should include 'tcp' }
  end

  # Health check endpoint
  describe http('http://localhost:3000/health') do
    its('status') { should eq 200 }
  end

  # Main page should load
  describe http('http://localhost:3000/') do
    its('status') { should eq 200 }
    its('headers.Content-Type') { should match %r{text/html} }
  end
end

control 'axonops-dashboard-nginx' do
  impact 0.8
  title 'Dashboard Nginx Configuration'
  desc 'Verify Nginx is properly configured for dashboard'

  describe service('nginx') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  describe port(80) do
    it { should be_listening }
  end

  # Nginx configuration syntax check
  describe command('nginx -t') do
    its('exit_status') { should eq 0 }
    its('stderr') { should match /syntax is ok/ }
  end

  # Verify dashboard vhost
  describe file('/etc/nginx/sites-enabled/axonops-dashboard') do
    it { should exist }
    it { should be_symlink }
    its('link_path') { should eq '/etc/nginx/sites-available/axonops-dashboard' }
  end

  # API proxy configuration
  describe file('/etc/nginx/sites-available/axonops-dashboard') do
    its('content') { should match %r{proxy_pass\s+http://localhost:8080} }
    its('content') { should match /proxy_set_header\s+X-Real-IP/ }
    its('content') { should match /proxy_set_header\s+X-Forwarded-For/ }
  end
end

control 'axonops-dashboard-security' do
  impact 0.9
  title 'Dashboard Security'
  desc 'Verify security configurations'

  # SSL/TLS configuration
  describe port(443) do
    it { should be_listening }
  end if node['axonops']['dashboard']['ssl_enabled']

  describe file('/etc/nginx/sites-available/axonops-dashboard') do
    its('content') { should match /listen\s+443\s+ssl/ }
    its('content') { should match /ssl_certificate/ }
    its('content') { should match /ssl_certificate_key/ }
    its('content') { should match /ssl_protocols\s+TLSv1\.2\s+TLSv1\.3/ }
  end if node['axonops']['dashboard']['ssl_enabled']

  describe ssl(port: 443) do
    it { should be_enabled }
    its('protocols') { should_not include 'tls1.0' }
    its('protocols') { should_not include 'tls1.1' }
  end if node['axonops']['dashboard']['ssl_enabled']

  # Security headers
  describe http('http://localhost:3000/') do
    its('headers.X-Frame-Options') { should eq 'DENY' }
    its('headers.X-Content-Type-Options') { should eq 'nosniff' }
    its('headers.X-XSS-Protection') { should eq '1; mode=block' }
  end

  # CORS configuration
  describe file('/etc/nginx/sites-available/axonops-dashboard') do
    its('content') { should match /add_header\s+'Access-Control-Allow-Origin'/ }
  end if node['axonops']['dashboard']['cors_enabled']
end

control 'axonops-dashboard-performance' do
  impact 0.6
  title 'Dashboard Performance'
  desc 'Verify performance configurations'

  # Nginx performance settings
  describe file('/etc/nginx/nginx.conf') do
    its('content') { should match /worker_processes\s+auto/ }
    its('content') { should match /worker_connections\s+\d+/ }
    its('content') { should match /keepalive_timeout\s+65/ }
  end

  # Compression enabled
  describe file('/etc/nginx/sites-available/axonops-dashboard') do
    its('content') { should match /gzip\s+on/ }
    its('content') { should match /gzip_types/ }
  end

  # Static asset caching
  describe file('/etc/nginx/sites-available/axonops-dashboard') do
    its('content') { should match /location\s+~\s+\\.\\(js\\|css\\|png\\|jpg\\|gif\\|ico\\)/ }
    its('content') { should match /expires\s+\d+[dhm]/ }
  end
end

control 'axonops-dashboard-logging' do
  impact 0.5
  title 'Dashboard Logging'
  desc 'Verify logging configuration'

  describe file('/var/log/axonops-dashboard/access.log') do
    it { should exist }
    its('owner') { should eq 'axonops' }
  end

  describe file('/var/log/axonops-dashboard/error.log') do
    it { should exist }
    its('owner') { should eq 'axonops' }
  end

  # Nginx logs
  describe file('/var/log/nginx/axonops-dashboard-access.log') do
    it { should exist }
  end

  describe file('/var/log/nginx/axonops-dashboard-error.log') do
    it { should exist }
  end

  # Log rotation
  describe file('/etc/logrotate.d/axonops-dashboard') do
    it { should exist }
    its('content') { should match %r{/var/log/axonops-dashboard/\*.log} }
  end
end

control 'axonops-dashboard-integration' do
  impact 0.8
  title 'Dashboard Integration'
  desc 'Verify dashboard integrates with AxonOps server'

  # API connectivity test
  describe http('http://localhost:3000/api/v1/health',
    headers: { 'Accept' => 'application/json' }) do
    its('status') { should eq 200 }
  end

  # Login page should be accessible
  describe http('http://localhost:3000/login') do
    its('status') { should eq 200 }
    its('body') { should match /login|sign in/i }
  end

  # Dashboard should redirect to login if not authenticated
  describe http('http://localhost:3000/dashboard',
    max_redirects: 0) do
    its('status') { should eq 302 }
    its('headers.Location') { should match %r{/login} }
  end
end

control 'axonops-dashboard-monitoring' do
  impact 0.5
  title 'Dashboard Monitoring'
  desc 'Verify dashboard monitoring endpoints'

  # Metrics endpoint
  describe http('http://localhost:3000/metrics') do
    its('status') { should eq 200 }
    its('body') { should match /nginx_connections_active/ }
  end if node['axonops']['dashboard']['metrics_enabled']

  # Dashboard process
  describe processes('nginx') do
    its('users') { should include 'www-data' }
    its('states') { should include 'S' }
  end

  describe processes('axon-dash') do
    its('users') { should include 'axonops' }
    its('states') { should include 'S' }
  end
end
