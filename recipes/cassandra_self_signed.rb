#
# Cookbook:: axonops
# Recipe:: cassandra_self_signed
#
# Creates self-signed certificates and keystore/truststore for Cassandra SSL/TLS
#

# Only proceed if self-signed SSL is enabled
return unless node['axonops']['cassandra']['ssl']['self_signed']

# Get keystore configuration from server_encryption_options (used for both server and client).
# recipes/java.rb's `update-alternatives` call registers java/javac/jar but
# never keytool, so it's never resolvable via PATH — and node['java']
# ['java_home'] only gets pointed at the real install location by the
# offline tarball branch (the online Zulu-package branch installs to
# node['java']['zulu_home'] instead and never updates it). Resolving via
# Ruby ::File at recipe-compile time doesn't work either: compile time runs
# before axonops::java's `execute` resources have actually converged, so
# `/usr/bin/java` may not exist yet. Resolve $KEYTOOL_CMD inside the bash
# script itself instead — it only runs at converge time, guaranteed after
# java is set up, as a sibling of whatever `java` alternatives resolved to.
keytool_override = node['axonops']['cassandra']['ssl']['keytool']
keystore_path = node['axonops']['cassandra']['server_encryption_options']['keystore']
keystore_password = node['axonops']['cassandra']['server_encryption_options']['keystore_password']
truststore_path = node['axonops']['cassandra']['server_encryption_options']['truststore']
truststore_password = node['axonops']['cassandra']['server_encryption_options']['truststore_password']
key_alias = node['axonops']['cassandra']['key_alias'] || 'cassandra'

# openssl is near-universal but not guaranteed on minimal container base
# images (verified missing on a stock Amazon Linux 2023 image) — this
# recipe hard-requires it for the PEM conversion steps below.
package 'openssl' do
  action :install
  not_if { ::File.exist?('/usr/bin/openssl') }
end

# Ensure the directory exists
keystore_dir = ::File.dirname(keystore_path)
directory keystore_dir do
  owner node['axonops']['cassandra']['user']
  group node['axonops']['cassandra']['group']
  mode '0755'
  recursive true
end

# Generate self-signed certificate and keystore
# Note: CN should be the hostname or IP that clients will connect to.
# node['hostname']/node['fqdn'] can come back blank from Ohai on a bare
# container without a resolvable hostname — an empty `dns:` SAN entry makes
# keytool reject the whole -ext flag ("DNSName must not be null or empty"),
# so filter blanks out and always keep localhost as a fallback.
hostname = node['hostname']
fqdn = node['fqdn'] || hostname
cn = fqdn && !fqdn.empty? ? fqdn : 'localhost'
san_entries = ([fqdn, hostname, 'localhost'].compact.reject(&:empty?).uniq.map { |n| "dns:#{n}" } + ['ip:127.0.0.1']).join(',')

bash 'generate_cassandra_keystore' do
  code <<-EOH
    # Resolve keytool as a sibling of the real `java` binary — see comment
    # above for why this can't be resolved at Ruby compile time or via PATH.
    #{if keytool_override
        "KEYTOOL_CMD=#{keytool_override}"
      else
        <<~SHELL.chomp
          JAVA_BIN="$(command -v java || true)"
              if [ -n "$JAVA_BIN" ]; then
                KEYTOOL_CMD="$(dirname "$(readlink -f "$JAVA_BIN")")/keytool"
              else
                KEYTOOL_CMD="keytool"
              fi
        SHELL
      end}

    # Remove existing keystore if it exists
    rm -f #{keystore_path}

    # Generate keypair with self-signed certificate
    $KEYTOOL_CMD -genkeypair \
      -keyalg RSA \
      -keysize 2048 \
      -validity 3650 \
      -alias #{key_alias} \
      -keystore #{keystore_path} \
      -storepass #{keystore_password} \
      -keypass #{keystore_password} \
      -dname "CN=#{cn}, OU=Cassandra, O=AxonOps, L=City, ST=State, C=US" \
      -ext "SAN=#{san_entries}"

    # Export the certificate
    $KEYTOOL_CMD -exportcert \
      -alias #{key_alias} \
      -keystore #{keystore_path} \
      -storepass #{keystore_password} \
      -file /tmp/cassandra-cert.der

    # Convert DER to PEM format for the certificate
    openssl x509 -inform DER -in /tmp/cassandra-cert.der -out #{node['axonops']['cassandra']['ssl']['cert_file']}

    # Export the certificate in PEM format (same as ca.pem since it's self-signed)
    cp #{node['axonops']['cassandra']['ssl']['cert_file']} #{node['axonops']['cassandra']['ssl']['ca_file']}

    # Export private key from keystore (requires conversion through PKCS12)
    $KEYTOOL_CMD -importkeystore \
      -srckeystore #{keystore_path} \
      -srcstorepass #{keystore_password} \
      -srckeypass #{keystore_password} \
      -srcalias #{key_alias} \
      -destkeystore /tmp/cassandra-key.p12 \
      -deststoretype PKCS12 \
      -deststorepass #{keystore_password} \
      -destkeypass #{keystore_password}

    # Extract private key in PEM format
    openssl pkcs12 -in /tmp/cassandra-key.p12 -nodes -nocerts -out #{node['axonops']['cassandra']['ssl']['key_file']} -passin pass:#{keystore_password}

    # Create truststore and import the certificate
    rm -f #{truststore_path}
    $KEYTOOL_CMD -importcert \
      -alias #{key_alias} \
      -keystore #{truststore_path} \
      -storepass #{truststore_password} \
      -file /tmp/cassandra-cert.der \
      -noprompt

    # Clean up temporary files
    rm -f /tmp/cassandra-cert.der /tmp/cassandra-key.p12

    # Set proper ownership
    chown #{node['axonops']['cassandra']['user']}:#{node['axonops']['cassandra']['group']} #{keystore_path}
    chown #{node['axonops']['cassandra']['user']}:#{node['axonops']['cassandra']['group']} #{truststore_path}
    chown #{node['axonops']['cassandra']['user']}:#{node['axonops']['cassandra']['group']} #{node['axonops']['cassandra']['ssl']['cert_file']}
    chown #{node['axonops']['cassandra']['user']}:#{node['axonops']['cassandra']['group']} #{node['axonops']['cassandra']['ssl']['ca_file']}
    chown #{node['axonops']['cassandra']['user']}:#{node['axonops']['cassandra']['group']} #{node['axonops']['cassandra']['ssl']['key_file']}
    chmod 600 #{keystore_path}
    chmod 600 #{truststore_path}
    chmod 644 #{node['axonops']['cassandra']['ssl']['cert_file']}
    chmod 644 #{node['axonops']['cassandra']['ssl']['ca_file']}
    chmod 640 #{node['axonops']['cassandra']['ssl']['key_file']}
  EOH
  not_if { ::File.exist?(keystore_path) && ::File.exist?(truststore_path) }
end


# Log success
log 'cassandra_ssl_keystore' do
  message "Cassandra SSL keystore and truststore created at #{keystore_path} and #{truststore_path}"
  level :info
end

# Create cqlshrc for root user when SSL is enabled
if node['axonops']['cassandra']['client_encryption_options']['enabled']
  directory '/root/.cassandra' do
    owner 'root'
    group 'root'
    mode '0700'
  end

  file '/root/.cassandra/cqlshrc' do
    content <<-EOH
[connection]
hostname = #{node['axonops']['cassandra']['rpc_address']}
port = 9042

[ssl]
validate = false
; The path to a trusted certificate file.
ca_certs = #{node['axonops']['cassandra']['ssl']['cert_file']}
; The path to your client certificate file.
certfile = #{node['axonops']['cassandra']['ssl']['cert_file']}
; The path to your client private key file.
keyfile = #{node['axonops']['cassandra']['ssl']['key_file']}
EOH
    owner 'root'
    group 'root'
    mode '0600'
  end

  log 'cqlshrc_created' do
    message 'Created /root/.cassandra/cqlshrc with SSL configuration for root user'
    level :info
  end
end
