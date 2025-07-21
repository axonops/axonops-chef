#!/bin/bash
# Create mock AxonOps packages that work on any architecture

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="${SCRIPT_DIR}/../offline_packages"

echo "Creating architecture-independent mock AxonOps packages..."

# Create temporary directory for package building
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Function to create a mock debian package
create_mock_deb() {
    local name=$1
    local version=$2
    local arch=$3
    local description=$4
    
    local pkg_dir="${TEMP_DIR}/${name}_${version}_${arch}"
    mkdir -p "${pkg_dir}/DEBIAN"
    mkdir -p "${pkg_dir}/usr/bin"
    mkdir -p "${pkg_dir}/etc/axonops"
    mkdir -p "${pkg_dir}/lib/systemd/system"
    
    # Create control file
    cat > "${pkg_dir}/DEBIAN/control" <<EOF
Package: ${name}
Version: ${version}
Architecture: ${arch}
Maintainer: AxonOps Team <support@axonops.com>
Description: ${description}
Depends: adduser, procps
EOF

    # Create postinst script
    cat > "${pkg_dir}/DEBIAN/postinst" <<'EOF'
#!/bin/bash
set -e

# Create axonops user if it doesn't exist
if ! getent passwd axonops >/dev/null; then
    adduser --system --group --home /var/lib/axonops --shell /bin/false axonops
fi

# Create directories
mkdir -p /var/log/axonops /var/lib/axonops /etc/axonops
chown -R axonops:axonops /var/log/axonops /var/lib/axonops /etc/axonops

exit 0
EOF
    chmod 755 "${pkg_dir}/DEBIAN/postinst"
    
    # Create a mock binary
    cat > "${pkg_dir}/usr/bin/${name}" <<'EOF'
#!/bin/bash
echo "Mock ${name} version ${version}"
echo "This is a mock package for testing purposes"
exit 0
EOF
    chmod 755 "${pkg_dir}/usr/bin/${name}"
    
    # Create systemd service
    cat > "${pkg_dir}/lib/systemd/system/${name}.service" <<EOF
[Unit]
Description=Mock ${description}
After=network.target

[Service]
Type=simple
User=axonops
Group=axonops
ExecStart=/usr/bin/${name}
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
    
    # Build the package
    dpkg-deb --build "${pkg_dir}" "${PACKAGES_DIR}/${name}_${version}_${arch}.deb"
    echo "Created: ${PACKAGES_DIR}/${name}_${version}_${arch}.deb"
}

# Create mock packages for all architectures
for arch in all amd64 arm64; do
    create_mock_deb "axon-server" "2.0.3" "$arch" "AxonOps Server"
    create_mock_deb "axon-dash" "2.0.7" "$arch" "AxonOps Dashboard"
    create_mock_deb "axon-agent" "1.0.50" "$arch" "AxonOps Agent"
done

# Create mock Java agent JARs
for agent in axon-cassandra5.0-agent axon-cassandra5.0-agent-jdk17; do
    touch "${PACKAGES_DIR}/${agent}_1.0.10_all.jar"
    echo "Created: ${PACKAGES_DIR}/${agent}_1.0.10_all.jar"
done

echo "Mock packages created successfully!"