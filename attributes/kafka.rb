#
# Cookbook:: axonops
# Attributes:: kafka
#
# Attributes for Apache Kafka installation
#

# Kafka version and installation
default['axonops']['kafka']['version'] = '3.9.1'
default['axonops']['kafka']['scala_version'] = '2.13'
default['axonops']['kafka']['install_dir'] = '/opt/kafka'
default['axonops']['kafka']['user'] = 'kafka'
default['axonops']['kafka']['group'] = 'kafka'
default['axonops']['kafka']['user_home'] = '/home/kafka'

# Kafka download settings
default['axonops']['kafka']['apache_mirror'] = 'https://archive.apache.org/dist'
default['axonops']['kafka']['tarball_url'] = nil
default['axonops']['kafka']['tarball_checksum'] = nil

# Kafka directories
default['axonops']['kafka']['data_dir'] = '/var/lib/kafka/data'
default['axonops']['kafka']['log_dir'] = '/var/log/kafka'
default['axonops']['kafka']['tmp_dir'] = '/var/tmp/kafka'
default['axonops']['kafka']['config_dir'] = '/opt/kafka/config'

# Kafka server properties
default['axonops']['kafka']['broker_id'] = 1
default['axonops']['kafka']['port'] = 9092
default['axonops']['kafka']['advertised_hostname'] = node['ipaddress']
default['axonops']['kafka']['rack'] = 'rack1'

# Kafka listeners
default['axonops']['kafka']['listeners'] = 'PLAINTEXT://0.0.0.0:9092'
default['axonops']['kafka']['advertised_listeners'] = "PLAINTEXT://#{node['ipaddress']}:9092"
default['axonops']['kafka']['listener_security_protocol_map'] = 'PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL'

# Kafka JVM settings
default['axonops']['kafka']['heap_size'] = '1G'
default['axonops']['kafka']['jvm_performance_opts'] = '-server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent -Djava.awt.headless=true'

# Kafka log retention
default['axonops']['kafka']['log_retention_hours'] = 168
default['axonops']['kafka']['log_segment_bytes'] = 1073741824
default['axonops']['kafka']['log_retention_check_interval_ms'] = 300000

# Kafka replication
default['axonops']['kafka']['default_replication_factor'] = 1
default['axonops']['kafka']['min_insync_replicas'] = 1
default['axonops']['kafka']['num_partitions'] = 8

# Kafka network settings
default['axonops']['kafka']['num_network_threads'] = 3
default['axonops']['kafka']['num_io_threads'] = 8
default['axonops']['kafka']['socket_send_buffer_bytes'] = 102400
default['axonops']['kafka']['socket_receive_buffer_bytes'] = 102400
default['axonops']['kafka']['socket_request_max_bytes'] = 104857600

# Kafka topic settings
default['axonops']['kafka']['auto_create_topics_enable'] = false
default['axonops']['kafka']['delete_topic_enable'] = true

# Zookeeper connection (for non-KRaft mode)
default['axonops']['kafka']['zookeeper_connect'] = 'localhost:2181'
default['axonops']['kafka']['zookeeper_connection_timeout_ms'] = 6000

# KRaft mode settings
default['axonops']['kafka']['kraft_mode'] = false
default['axonops']['kafka']['node_id'] = 1
default['axonops']['kafka']['controller_quorum_voters'] = '1@localhost:9093'
default['axonops']['kafka']['process_roles'] = 'broker,controller'

# SSL/TLS settings
default['axonops']['kafka']['ssl']['enabled'] = false
default['axonops']['kafka']['ssl']['keystore_location'] = '/opt/kafka/ssl/kafka.keystore.jks'
default['axonops']['kafka']['ssl']['keystore_password'] = nil
default['axonops']['kafka']['ssl']['key_password'] = nil
default['axonops']['kafka']['ssl']['truststore_location'] = '/opt/kafka/ssl/kafka.truststore.jks'
default['axonops']['kafka']['ssl']['truststore_password'] = nil
default['axonops']['kafka']['ssl']['client_auth'] = 'none' # none, requested, required
default['axonops']['kafka']['ssl']['enabled_protocols'] = 'TLSv1.2,TLSv1.3'
default['axonops']['kafka']['ssl']['cipher_suites'] = nil

# SASL settings
default['axonops']['kafka']['sasl']['enabled'] = false
default['axonops']['kafka']['sasl']['mechanism'] = 'PLAIN' # PLAIN, SCRAM-SHA-256, SCRAM-SHA-512
default['axonops']['kafka']['sasl']['interbroker_protocol'] = 'PLAINTEXT'

# System limits
default['axonops']['kafka']['max_open_files'] = 1048576

# Service settings
default['axonops']['kafka']['service_name'] = 'kafka'
default['axonops']['kafka']['autostart'] = true

# Kafka Connect settings (optional)
default['axonops']['kafka']['connect']['enabled'] = false
default['axonops']['kafka']['connect']['port'] = 8083
default['axonops']['kafka']['connect']['plugin_path'] = '/opt/kafka/connect-plugins'
default['axonops']['kafka']['connect']['group_id'] = 'connect-cluster'
default['axonops']['kafka']['connect']['offset_storage_topic'] = 'connect-offsets'
default['axonops']['kafka']['connect']['config_storage_topic'] = 'connect-configs'
default['axonops']['kafka']['connect']['status_storage_topic'] = 'connect-status'