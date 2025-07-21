default["java"]["skip_install"] = false
default["java"]["offline_install"] = false

# Java attributes
default["java"]["install_from_package"] = true
default["java"]["tarball_path"] = nil
default["java"]["zulu"] = true
# For Offline installations, set the RPM or DEB package path
default["java"]["package"] = nil

# Default paths for different Java installations
default["java"]["zulu_home"] = "/usr/lib/jvm/zulu17"
default["java"]["openjdk_home"] = "/usr/lib/jvm/jre"
default["java"]["java_home"] = "/usr/lib/jvm/jre"  # Default JAVA_HOME

# Package names
default["java"]["zulu_pkg"] = "zulu17-jdk"
default["java"]["openjdk_pkg"] = "java-17-openjdk-headless"
default["java"]["java_pkg"] = "java-17-openjdk-headless"  # Generic fallback

default["java"]["zulu_pkg_rpm"] = "https://cdn.azul.com/zulu/bin/zulu-repo-1.0.0-1.noarch.rpm"
