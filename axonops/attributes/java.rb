#
# Cookbook:: axonops
# Attributes:: java
#
# Java/JDK installation attributes
#

# Java Configuration
default['java']['install'] = true
default['java']['jdk_version'] = '17'

# Zulu JDK Configuration
default['java']['zulu']['version'] = '17.0.9'
default['java']['zulu']['build'] = '17.46.19-ca'
default['java']['zulu']['install_dir'] = '/opt/zulu-jdk'
default['java']['zulu']['tarball_url'] = nil # Auto-generated based on version and arch
default['java']['zulu']['tarball_checksum'] = nil

# Package names for offline installation
default['axonops']['packages']['agent'] = nil
default['axonops']['packages']['server'] = nil
default['axonops']['packages']['dashboard'] = nil
default['axonops']['packages']['java_agent'] = nil
default['axonops']['packages']['cassandra_tarball'] = nil
default['axonops']['packages']['elasticsearch_tarball'] = nil
default['axonops']['packages']['zulu_jdk_tarball'] = nil
