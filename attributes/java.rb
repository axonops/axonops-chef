default['java']['skip_install'] = false
default['java']['offline_install'] = false

# Java attributes
default['java']['install_from_package'] = true
default['java']['tarball_path'] = nil
default['java']['zulu'] = true
# Offline-install toggle: true forces recipes/java.rb's package-based (RPM/
# deb) install path instead of the tarball path, even when offline_install
# is set. The actual file is resolved via offline_packages['java'] if set,
# otherwise globbed by major from zulu_headless_packages below. Required —
# not just preferred — whenever install_format is 'pkg', since a Cassandra
# package's real `java-X.Y.Z-headless` dependency can only be satisfied by
# an actually-installed OS package (recipes/cassandra.rb sets this
# automatically in that case).
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

# Per-major Azul Zulu *headless* package names — distinct from zulu_packages
# above. A Cassandra RPM/deb package (install_format 'pkg') depends on a real
# `java-X.Y.Z-headless` capability, which only an actually-installed OS
# package registers with rpm/dnf/dpkg — a tarball-extracted JDK is invisible
# to dependency resolution even though `java` itself works fine via
# alternatives. recipes/cassandra.rb forces java to install from one of
# these (not the tarball) whenever install_format == 'pkg', offline or
# online (confirmed via `dnf repoquery --provides`: `zulu8-jdk-headless`
# provides `java-1.8.0-headless`, etc.).
default['java']['zulu_headless_packages'] = {
  8 => 'zulu8-jdk-headless',
  11 => 'zulu11-jdk-headless',
  17 => 'zulu17-jdk-headless',
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

# Azul Zulu tarball version/build used only by
# recipes/offline_download_helper.rb's sample download script (which fetches
# a raw tarball from cdn.azul.com, unrelated to the zulu_packages/zulu_pkg_rpm
# repo-based install path recipes/java.rb actually uses).
default['java']['zulu_tarball_version'] = '17.0.9'
default['java']['zulu_tarball_build'] = '17.46.19-ca'
