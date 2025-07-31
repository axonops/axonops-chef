#
# Cookbook:: axonops
# Recipe:: cassandra_self_signed
#
# Creates self-signed certificates and keystore/truststore for Cassandra SSL/TLS
#

# Only proceed if self-signed SSL is enabled
return unless node['axonops']['cassandra']['ssl']['self_signed']

# Get keystore configuration from server_encryption_options (used for both server and client)
keytool_cmd = node['axonops']['cassandra']['ssl']['keytool'] || "keytool"
keystore_path = node['axonops']['cassandra']['server_encryption_options']['keystore']
keystore_password = node['axonops']['cassandra']['server_encryption_options']['keystore_password']
truststore_path = node['axonops']['cassandra']['server_encryption_options']['truststore']
truststore_password = node['axonops']['cassandra']['server_encryption_options']['truststore_password']
key_alias = node['axonops']['cassandra']['key_alias'] || 'cassandra'

# Ensure the directory exists
keystore_dir = ::File.dirname(keystore_path)
directory keystore_dir do
  owner node['axonops']['cassandra']['user']
  group node['axonops']['cassandra']['group']
  mode '0755'
  recursive true
end

# Generate self-signed certificate and keystore
# Note: CN should be the hostname or IP that clients will connect to
hostname = node['hostname']
fqdn = node['fqdn'] || hostname

bash 'generate_cassandra_keystore' do
  code <<-EOH
    # Remove existing keystore if it exists
    rm -f #{keystore_path}
    
    # Generate keypair with self-signed certificate
    #{keytool_cmd} -genkeypair \
      -keyalg RSA \
      -keysize 2048 \
      -validity 3650 \
      -alias #{key_alias} \
      -keystore #{keystore_path} \
      -storepass #{keystore_password} \
      -keypass #{keystore_password} \
      -dname "CN=#{fqdn}, OU=Cassandra, O=AxonOps, L=City, ST=State, C=US" \
      -ext "SAN=dns:#{fqdn},dns:#{hostname},dns:localhost,ip:127.0.0.1"
    
    # Export the certificate
    #{keytool_cmd} -exportcert \
      -alias #{key_alias} \
      -keystore #{keystore_path} \
      -storepass #{keystore_password} \
      -file /tmp/cassandra-cert.pem
    
    # Create truststore and import the certificate
    rm -f #{truststore_path}
    #{keytool_cmd} -importcert \
      -alias #{key_alias} \
      -keystore #{truststore_path} \
      -storepass #{truststore_password} \
      -file /tmp/cassandra-cert.pem \
      -noprompt
    
    # Clean up temporary certificate file
    rm -f /tmp/cassandra-cert.pem
    
    # Set proper ownership
    chown #{node['axonops']['cassandra']['user']}:#{node['axonops']['cassandra']['group']} #{keystore_path}
    chown #{node['axonops']['cassandra']['user']}:#{node['axonops']['cassandra']['group']} #{truststore_path}
    chmod 600 #{keystore_path}
    chmod 600 #{truststore_path}
  EOH
  not_if { ::File.exist?(keystore_path) && ::File.exist?(truststore_path) }
end

# Log success
log 'cassandra_ssl_keystore' do
  message "Cassandra SSL keystore and truststore created at #{keystore_path} and #{truststore_path}"
  level :info
end