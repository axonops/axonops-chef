# Generate self-signed certificates for Elasticsearch if SSL is enabled
if node['axonops']['server']['elastic']['ssl']['enabled'] && node['axonops']['server']['elastic']['ssl']['self_signed']
  elastic_install_dir = node['axonops']['server']['elastic']['install_dir']
  elastic_user = 'elasticsearch'
  elastic_group = 'elasticsearch'
  
  # Create certificate directory
  directory "#{elastic_install_dir}/config/certs" do
    owner elastic_user
    group elastic_group
    mode '0750'
    recursive true
  end
  
  # Get server IP address
  server_ip = node['ipaddress']
  
  # Generate CA certificate
  execute 'generate-ca-certificate' do
    command <<-EOH
      openssl req -x509 -newkey rsa:4096 -nodes \
        -keyout #{elastic_install_dir}/config/certs/ca-key.pem \
        -out #{elastic_install_dir}/config/certs/ca-cert.pem \
        -days 3650 \
        -subj "/C=US/ST=State/L=City/O=AxonOps/CN=AxonOps CA"
    EOH
    creates "#{elastic_install_dir}/config/certs/ca-cert.pem"
    notifies :run, 'execute[fix-certificate-permissions]', :immediately
  end
  
  # Create server certificate config file with SAN
  file "#{elastic_install_dir}/config/certs/server.conf" do
    content <<-EOH
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = AxonOps
CN = #{node['hostname']}

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = #{node['hostname']}
DNS.3 = #{node['fqdn']}
IP.1 = 127.0.0.1
IP.2 = #{server_ip}
    EOH
    owner elastic_user
    group elastic_group
    mode '0640'
  end
  
  # Generate server key and certificate request
  execute 'generate-server-key-and-csr' do
    command <<-EOH
      openssl req -newkey rsa:4096 -nodes \
        -keyout #{elastic_install_dir}/config/certs/server-key.pem \
        -out #{elastic_install_dir}/config/certs/server.csr \
        -config #{elastic_install_dir}/config/certs/server.conf
    EOH
    creates "#{elastic_install_dir}/config/certs/server-key.pem"
    notifies :run, 'execute[fix-certificate-permissions]', :immediately
  end
  
  # Sign server certificate with CA
  execute 'sign-server-certificate' do
    command <<-EOH
      openssl x509 -req \
        -in #{elastic_install_dir}/config/certs/server.csr \
        -CA #{elastic_install_dir}/config/certs/ca-cert.pem \
        -CAkey #{elastic_install_dir}/config/certs/ca-key.pem \
        -CAcreateserial \
        -out #{elastic_install_dir}/config/certs/server-cert.pem \
        -days 3650 \
        -extensions v3_req \
        -extfile #{elastic_install_dir}/config/certs/server.conf
    EOH
    creates "#{elastic_install_dir}/config/certs/server-cert.pem"
    notifies :run, 'execute[fix-certificate-permissions]', :immediately
  end
  
  # Fix certificate permissions
  execute 'fix-certificate-permissions' do
    command "chown -R #{elastic_user}:#{elastic_group} #{elastic_install_dir}/config/certs && chmod 640 #{elastic_install_dir}/config/certs/*"
    action :nothing
  end
end