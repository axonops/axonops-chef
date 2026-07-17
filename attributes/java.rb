default['java']['skip_install'] = false
default['java']['offline_install'] = false

# Java attributes
default['java']['install_from_package'] = true
default['java']['tarball_path'] = nil
default['java']['zulu'] = true
# For Offline installations, set the RPM or DEB package path
default['java']['package'] = nil

# Java major version to install: 8, 11 or 17.
# The Cassandra recipe overrides this based on the Cassandra version
# (3.11 -> 8, 4.1 -> 11, 5.0 -> 17). Defaults to 17 for standalone use.
default['java']['version'] = 17

# Per-major Azul Zulu package names. The same names apply on Debian (zulu apt
# repo) and RHEL (zulu yum repo).
default['java']['zulu_packages'] = {
  8 => 'zulu8-jdk',
  11 => 'zulu11-jdk',
  17 => 'zulu17-jdk',
}

# Per-major Azul Zulu JAVA_HOME paths.
default['java']['zulu_homes'] = {
  8 => '/usr/lib/jvm/zulu8',
  11 => '/usr/lib/jvm/zulu11',
  17 => '/usr/lib/jvm/zulu17',
}

# Per-major OpenJDK package names by platform family (used when zulu is false).
default['java']['openjdk_packages'] = {
  'debian' => {
    8 => 'openjdk-8-jdk-headless',
    11 => 'openjdk-11-jdk-headless',
    17 => 'openjdk-17-jdk-headless',
  },
  'rhel' => {
    8 => 'java-1.8.0-openjdk-headless',
    11 => 'java-11-openjdk-headless',
    17 => 'java-17-openjdk-headless',
  },
  'amazon' => {
    8 => 'java-1.8.0-openjdk-headless',
    11 => 'java-11-openjdk-headless',
    17 => 'java-17-openjdk-headless',
  },
}

# Default paths for different Java installations. These are resolved from the
# version maps above in recipes/java.rb but remain overridable for backwards
# compatibility and offline installs.
default['java']['zulu_home'] = '/usr/lib/jvm/zulu17'
default['java']['openjdk_home'] = '/usr/lib/jvm/jre'
default['java']['java_home'] = '/usr/lib/jvm/jre' # Default JAVA_HOME

# Package names (resolved from the version maps in recipes/java.rb; kept for
# backwards compatibility and explicit overrides).
default['java']['zulu_pkg'] = 'zulu17-jdk'
default['java']['openjdk_pkg'] = 'java-17-openjdk-headless'
default['java']['java_pkg'] = 'java-17-openjdk-headless' # Generic fallback

default['java']['zulu_pkg_rpm'] = 'https://cdn.azul.com/zulu/bin/zulu-repo-1.0.0-1.noarch.rpm'
