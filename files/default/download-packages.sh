#!/bin/bash
#
# AxonOps offline package downloader (standalone)
#
# Chef-free replacement for `recipe[axonops::offline_download_helper]`. Selects
# which component set to download via --components and writes the packages into
# a directory ready to be copied to an airgapped target and consumed by the
# axonops cookbook's offline_install path.
#
# All download URLs/quirks were verified live against the real repos; the
# version-fallback and java-agent-package derivation logic mirrors
# libraries/cassandra_version.rb so the script produces the same artifacts the
# cookbook's offline_install path expects — without needing a Chef run.
# recipes/offline_download_helper.rb ships this exact file onto a node and logs
# a recommended command line, but the script is fully standalone.
#
# For comprehensive downloads AxonOps also publishes:
#   https://github.com/axonops/axonops-installer-packages-downloader
#

set -euo pipefail

# --------------------------------------------------------------------------
# Built-in defaults (mirror attributes/*.rb; override with flags/env vars).
# --------------------------------------------------------------------------

# Pinned known-good fallbacks for the 'latest' keyword — 'latest' is meaningful
# to a package manager but useless spliced into a download spec. Refresh by
# re-checking `dnf list --showduplicates axon-agent axon-server axon-dash`
# against packages.axonops.com.
DEFAULT_AGENT_VERSION="2.0.30"
DEFAULT_SERVER_VERSION="2.0.34"
DEFAULT_DASHBOARD_VERSION="2.0.36"

# Per-package java-agent fallbacks — every axon-cassandra*/axon-dse*-agent has
# its own release history (see the note in recipes/offline_download_helper.rb).
# Refresh with `dnf list --showduplicates <package>`.
java_agent_fallback() {
  case "$1" in
    axon-cassandra3.11-agent)       echo "1.0.14" ;;
    axon-cassandra4.1-agent)        echo "1.0.16" ;;
    axon-cassandra5.0-agent-jdk17)  echo "1.0.14" ;;
    axon-dse5.1-agent)              echo "1.0.5"  ;;
    axon-dse6.7-agent)              echo "1.0.4"  ;;
    axon-dse6.8-agent)              echo "1.0.7"  ;;
    axon-dse6.9-agent)              echo "1.0.9"  ;;
    *) return 1 ;;
  esac
}

# The default java-agent package attribute (node['axonops']['java_agent']
# ['package']); a value different from this signals an explicit user override.
DEFAULT_JAVA_AGENT_PACKAGE="axon-cassandra5.0-agent-jdk17"

REPO_URL="${AXONOPS_REPO_URL:-https://packages.axonops.com}"
AGENT_VERSION="${AXONOPS_AGENT_VERSION:-latest}"
SERVER_VERSION="${AXONOPS_SERVER_VERSION:-latest}"
DASHBOARD_VERSION="${AXONOPS_DASHBOARD_VERSION:-latest}"
JAVA_AGENT_VERSION="${AXONOPS_JAVA_AGENT_VERSION:-latest}"
JAVA_AGENT_PACKAGE="${AXONOPS_JAVA_AGENT_PACKAGE:-$DEFAULT_JAVA_AGENT_PACKAGE}"
CASSANDRA_VERSION="${AXONOPS_CASSANDRA_VERSION:-5.0.5}"
CASSANDRA_INSTALL_FORMAT="${AXONOPS_CASSANDRA_INSTALL_FORMAT:-tar}"
EDITION="${AXONOPS_EDITION:-apache}"
DSE_VERSION="${AXONOPS_DSE_VERSION:-5.1}"
OPENSEARCH_VERSION="${AXONOPS_OPENSEARCH_VERSION:-3.6.0}"
ZULU_VERSION="${AXONOPS_ZULU_VERSION:-17.0.9}"
ZULU_BUILD="${AXONOPS_ZULU_BUILD:-17.46.19-ca}"
ZULU_PKG_RPM="${AXONOPS_ZULU_PKG_RPM:-https://cdn.azul.com/zulu/bin/zulu-repo-1.0.0-1.noarch.rpm}"
REDHAT_REPO_311X="${AXONOPS_REDHAT_REPO_311X:-https://apache.jfrog.io/artifactory/cassandra-rpm/311x/}"

DOWNLOAD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENTS=""

ALL_COMPONENTS="cassandra java agent server dashboard"

usage() {
  cat <<EOF
Usage: $(basename "$0") --components <list> [options]

Download AxonOps / Cassandra / Java offline packages into a directory ready to
copy to an airgapped target for the axonops cookbook's offline_install path.

Required:
  -c, --components LIST   Comma-separated set of: ${ALL_COMPONENTS// /, }
                          Examples:
                            --components cassandra
                            --components cassandra,java
                            --components cassandra,java,agent
                            --components cassandra,java,agent,server,dashboard

Component -> artifacts:
  cassandra   Apache Cassandra tarball (install-format tar) or RPM/deb (pkg).
              Not valid for --edition dse (DSE's Cassandra is not managed here).
  java        Azul Zulu JDK tarball; plus the zulu*-headless OS package when
              --cassandra-install-format pkg (the Cassandra RPM/deb needs it).
  agent       axon-agent package + the matching axon-cassandra*/axon-dse*-agent
              java-agent package (jar extracted alongside).
  server      axon-server package + OpenSearch package.
  dashboard   axon-dash package.

Options (env var in brackets; default):
  -d, --dir PATH                    Output directory [\$AXONOPS_DOWNLOAD_DIR]  (default: script dir)
      --repo-url URL                AxonOps repo [\$AXONOPS_REPO_URL]  ($REPO_URL)
      --agent-version VER           axon-agent version  ($AGENT_VERSION)
      --server-version VER          axon-server version  ($SERVER_VERSION)
      --dashboard-version VER       axon-dash version  ($DASHBOARD_VERSION)
      --java-agent-version VER      java-agent version  ($JAVA_AGENT_VERSION)
      --java-agent-package NAME     java-agent package (auto-derived if unset)
      --cassandra-version VER       Apache Cassandra version  ($CASSANDRA_VERSION)
      --cassandra-install-format F  tar | pkg  ($CASSANDRA_INSTALL_FORMAT)
      --edition E                   apache | dse  ($EDITION)
      --dse-version VER             DSE series: 5.1|6.7|6.8|6.9  ($DSE_VERSION)
      --opensearch-version VER      OpenSearch version  ($OPENSEARCH_VERSION)
      --zulu-version VER            Zulu JDK tarball version  ($ZULU_VERSION)
      --zulu-build BUILD            Zulu JDK tarball build  ($ZULU_BUILD)
      --redhat-repo-311x URL        Cassandra 3.11 RPM mirror  ($REDHAT_REPO_311X)
  -h, --help                        Show this help.

'latest' versions resolve to pinned known-good fallbacks baked into this script.
EOF
}

# --------------------------------------------------------------------------
# Argument parsing
# --------------------------------------------------------------------------

DOWNLOAD_DIR="${AXONOPS_DOWNLOAD_DIR:-$DOWNLOAD_DIR}"

while [ $# -gt 0 ]; do
  case "$1" in
    -c|--components)              COMPONENTS="$2"; shift 2 ;;
    -d|--dir)                     DOWNLOAD_DIR="$2"; shift 2 ;;
    --repo-url)                   REPO_URL="$2"; shift 2 ;;
    --agent-version)              AGENT_VERSION="$2"; shift 2 ;;
    --server-version)             SERVER_VERSION="$2"; shift 2 ;;
    --dashboard-version)          DASHBOARD_VERSION="$2"; shift 2 ;;
    --java-agent-version)         JAVA_AGENT_VERSION="$2"; shift 2 ;;
    --java-agent-package)         JAVA_AGENT_PACKAGE="$2"; shift 2 ;;
    --cassandra-version)          CASSANDRA_VERSION="$2"; shift 2 ;;
    --cassandra-install-format)   CASSANDRA_INSTALL_FORMAT="$2"; shift 2 ;;
    --edition)                    EDITION="$2"; shift 2 ;;
    --dse-version)                DSE_VERSION="$2"; shift 2 ;;
    --opensearch-version)         OPENSEARCH_VERSION="$2"; shift 2 ;;
    --zulu-version)               ZULU_VERSION="$2"; shift 2 ;;
    --zulu-build)                 ZULU_BUILD="$2"; shift 2 ;;
    --redhat-repo-311x)           REDHAT_REPO_311X="$2"; shift 2 ;;
    -h|--help)                    usage; exit 0 ;;
    *) echo "ERROR: unknown option '$1'" >&2; echo >&2; usage >&2; exit 2 ;;
  esac
done

die() { echo "ERROR: $*" >&2; exit 1; }

[ -n "$COMPONENTS" ] || { echo "ERROR: --components is required" >&2; echo >&2; usage >&2; exit 2; }

# Normalise the requested component list and validate membership.
want_cassandra=0 want_java=0 want_agent=0 want_server=0 want_dashboard=0
IFS=',' read -ra _reqs <<< "$COMPONENTS"
for c in "${_reqs[@]}"; do
  c="$(echo "$c" | tr -d '[:space:]')"
  [ -n "$c" ] || continue
  case "$c" in
    cassandra) want_cassandra=1 ;;
    java)      want_java=1 ;;
    agent)     want_agent=1 ;;
    server)    want_server=1 ;;
    dashboard) want_dashboard=1 ;;
    *) die "unknown component '$c'. Valid: ${ALL_COMPONENTS// /, }" ;;
  esac
done

# --------------------------------------------------------------------------
# Version / package resolution (mirrors recipes/offline_download_helper.rb
# and libraries/cassandra_version.rb)
# --------------------------------------------------------------------------

resolve_package_version() {
  # $1 = requested value, $2 = fallback for 'latest'
  if [ "$1" = "latest" ]; then echo "$2"; else echo "$1"; fi
}

# Normalise a Cassandra version to its series (3.11 / 4.1 / 5.0 / 5.1=DSE).
cassandra_series() {
  local v="$1"
  case "$v" in
    3.11*) echo "3.11" ;;
    4.1*)  echo "4.1" ;;
    5.1*)  echo "5.1" ;;   # DSE 5.1 — checked before the 5.* apache match
    5.*)   echo "5.0" ;;
    *) die "Unsupported Cassandra version '$v'. Supported series: 3.11, 4.1, 5.0, 5.1." ;;
  esac
}

# Java major required by a Cassandra series.
java_major_for_series() {
  case "$1" in
    3.11) echo 8 ;;
    4.1)  echo 11 ;;
    5.0)  echo 17 ;;
    5.1)  echo 8 ;;
    *) die "No Java major mapping for series '$1'" ;;
  esac
}

# axon-cassandra*-agent package name for a Cassandra series.
java_agent_package_for_series() {
  case "$1" in
    3.11) echo "axon-cassandra3.11-agent" ;;
    4.1)  echo "axon-cassandra4.1-agent" ;;
    5.0)  echo "axon-cassandra5.0-agent-jdk17" ;;
    *) die "No java-agent package for series '$1' (DSE uses --dse-version)" ;;
  esac
}

# axon-dse<series>-agent package name for a DSE version.
dse_java_agent_package() {
  case "$1" in
    5.1) echo "axon-dse5.1-agent" ;;
    6.7) echo "axon-dse6.7-agent" ;;
    6.8) echo "axon-dse6.8-agent" ;;
    6.9) echo "axon-dse6.9-agent" ;;
    *) die "Unsupported DSE version '$1'. Supported: 5.1, 6.7, 6.8, 6.9." ;;
  esac
}

# zulu*-headless OS package name for a Java major.
zulu_headless_package() {
  case "$1" in
    8)  echo "zulu8-jdk-headless" ;;
    11) echo "zulu11-jdk-headless" ;;
    17) echo "zulu17-jdk-headless" ;;
    *) die "No zulu headless package for Java major '$1'" ;;
  esac
}

# --------------------------------------------------------------------------
# Validation of component / edition combinations
# --------------------------------------------------------------------------

case "$EDITION" in apache|dse) ;; *) die "--edition must be 'apache' or 'dse' (got '$EDITION')" ;; esac
case "$CASSANDRA_INSTALL_FORMAT" in tar|pkg) ;; *) die "--cassandra-install-format must be 'tar' or 'pkg' (got '$CASSANDRA_INSTALL_FORMAT')" ;; esac

if [ "$EDITION" = "dse" ] && [ "$want_cassandra" -eq 1 ]; then
  die "component 'cassandra' is invalid for --edition dse: this cookbook monitors DSE via the agent, it does not install/manage DSE's Cassandra. Drop 'cassandra' from --components."
fi

# Derive the java-agent package (only needed when downloading the agent).
if [ "$want_agent" -eq 1 ]; then
  if [ "$EDITION" = "dse" ]; then
    RESOLVED_JAVA_AGENT_PACKAGE="$(dse_java_agent_package "$DSE_VERSION")"
  elif [ "$JAVA_AGENT_PACKAGE" != "$DEFAULT_JAVA_AGENT_PACKAGE" ]; then
    RESOLVED_JAVA_AGENT_PACKAGE="$JAVA_AGENT_PACKAGE"   # explicit user override
  else
    RESOLVED_JAVA_AGENT_PACKAGE="$(java_agent_package_for_series "$(cassandra_series "$CASSANDRA_VERSION")")"
  fi

  if [ "$JAVA_AGENT_VERSION" = "latest" ]; then
    RESOLVED_JAVA_AGENT_VERSION="$(java_agent_fallback "$RESOLVED_JAVA_AGENT_PACKAGE")" \
      || die "no known-good version fallback for java-agent package '$RESOLVED_JAVA_AGENT_PACKAGE' — pass --java-agent-version explicitly."
  else
    RESOLVED_JAVA_AGENT_VERSION="$JAVA_AGENT_VERSION"
  fi
fi

RESOLVED_AGENT_VERSION="$(resolve_package_version "$AGENT_VERSION" "$DEFAULT_AGENT_VERSION")"
RESOLVED_SERVER_VERSION="$(resolve_package_version "$SERVER_VERSION" "$DEFAULT_SERVER_VERSION")"
RESOLVED_DASHBOARD_VERSION="$(resolve_package_version "$DASHBOARD_VERSION" "$DEFAULT_DASHBOARD_VERSION")"

# Cassandra-package-specific derivations (series/java major) only when needed.
if [ "$want_cassandra" -eq 1 ]; then
  CASSANDRA_SERIES="$(cassandra_series "$CASSANDRA_VERSION")"
  JAVA_MAJOR="$(java_major_for_series "$CASSANDRA_SERIES")"
elif [ "$want_java" -eq 1 ] && [ "$CASSANDRA_INSTALL_FORMAT" = "pkg" ]; then
  # java+pkg without a cassandra component still needs the java major to pick
  # the headless package that a Cassandra RPM/deb would depend on.
  CASSANDRA_SERIES="$(cassandra_series "$CASSANDRA_VERSION")"
  JAVA_MAJOR="$(java_major_for_series "$CASSANDRA_SERIES")"
fi

# --------------------------------------------------------------------------
# Environment detection + shared helpers (ported from the ERB template)
# --------------------------------------------------------------------------

mkdir -p "$DOWNLOAD_DIR"

echo "Downloading AxonOps packages to: $DOWNLOAD_DIR"
echo "Components: $(echo "$COMPONENTS" | tr ',' ' ')"
echo ""

if [ -f /etc/os-release ]; then
  # shellcheck source=/dev/null
  . /etc/os-release
  OS="$ID"
else
  die "cannot detect OS version (/etc/os-release missing)"
fi

UNAME_ARCH="$(uname -m)"
ARCH="$UNAME_ARCH"
if [ "$ARCH" = "x86_64" ]; then
  ARCH="amd64"
elif [ "$ARCH" = "aarch64" ]; then
  ARCH="arm64"
fi

# Extract the java-agent jar from an already-downloaded axon-cassandra*-agent
# package — there is no standalone jar download URL (verified 404). The jar
# ships inside the RPM/deb at /usr/share/axonops/<package>.jar.
extract_jar_from_rpm() {
  local rpm_file=$1
  local out_jar="$DOWNLOAD_DIR/${RESOLVED_JAVA_AGENT_PACKAGE}-${RESOLVED_JAVA_AGENT_VERSION}.jar"
  local extract_dir
  extract_dir=$(mktemp -d)
  (cd "$extract_dir" && rpm2cpio "$rpm_file" | cpio -idm --quiet)
  find "$extract_dir" -name '*.jar' -exec cp {} "$out_jar" \;
  rm -rf "$extract_dir"
}

extract_jar_from_deb() {
  local deb_file=$1
  local out_jar="$DOWNLOAD_DIR/${RESOLVED_JAVA_AGENT_PACKAGE}-${RESOLVED_JAVA_AGENT_VERSION}.jar"
  local extract_dir
  extract_dir=$(mktemp -d)
  dpkg-deb -x "$deb_file" "$extract_dir"
  find "$extract_dir" -name '*.jar' -exec cp {} "$out_jar" \;
  rm -rf "$extract_dir"
}

# Download real, static URLs (Cassandra/OpenSearch/Zulu upstream artifacts) —
# NOT AxonOps' own packages, which come from a repodata-driven repo with
# content-hashed filenames and must be fetched via the package manager.
download_package() {
  local url=$1
  local filename=$2
  echo "Downloading: $filename"
  if command -v wget > /dev/null; then
    wget -O "$DOWNLOAD_DIR/$filename" "$url"
  elif command -v curl > /dev/null; then
    curl -L -o "$DOWNLOAD_DIR/$filename" "$url"
  else
    die "neither wget nor curl found; install one."
  fi
}

# Placeholders for the final summary (only set for requested components).
AGENT_PKG_FILE=""
SERVER_PKG_FILE=""
DASHBOARD_PKG_FILE=""
JAVA_AGENT_PKG_FILE=""
CASSANDRA_TAR_FILE=""
CASSANDRA_PKG_FILE=""
JAVA_PKG_FILE=""
OPENSEARCH_PKG_FILE=""
ZULU_TARBALL_FILE=""

# --------------------------------------------------------------------------
# AxonOps repo packages (agent / server / dashboard / java-agent)
# --------------------------------------------------------------------------

need_axonops_repo=0
if [ "$want_agent" -eq 1 ] || [ "$want_server" -eq 1 ] || [ "$want_dashboard" -eq 1 ]; then
  need_axonops_repo=1
fi

case "$OS" in
  ubuntu|debian)
    if [ "$need_axonops_repo" -eq 1 ]; then
      apt-get install -y apt-transport-https ca-certificates curl gnupg apt-utils
      curl -L "${REPO_URL}/apt/repo-signing-key.gpg" | gpg --dearmor -o /usr/share/keyrings/axonops.gpg
      echo "deb [arch=arm64,amd64 trusted=yes signed-by=/usr/share/keyrings/axonops.gpg] ${REPO_URL}/apt axonops-apt main" \
        > /etc/apt/sources.list.d/axonops.list
      apt-get update

      download_deb_package() {
        local pkg_spec=$1
        echo "Downloading (apt-get download): $pkg_spec"
        (cd "$DOWNLOAD_DIR" && apt-get download "$pkg_spec")
      }

      if [ "$want_agent" -eq 1 ]; then
        download_deb_package "axon-agent=${RESOLVED_AGENT_VERSION}-1:${ARCH}"
        AGENT_PKG_FILE=$(basename "$(ls "$DOWNLOAD_DIR"/axon-agent_*.deb | head -1)")

        download_deb_package "${RESOLVED_JAVA_AGENT_PACKAGE}=${RESOLVED_JAVA_AGENT_VERSION}-1:all"
        JAVA_AGENT_PKG_FILE="${RESOLVED_JAVA_AGENT_PACKAGE}_${RESOLVED_JAVA_AGENT_VERSION}-1_all.deb"
        extract_jar_from_deb "$DOWNLOAD_DIR/$JAVA_AGENT_PKG_FILE"
      fi
      if [ "$want_server" -eq 1 ]; then
        download_deb_package "axon-server=${RESOLVED_SERVER_VERSION}-1:${ARCH}"
        SERVER_PKG_FILE=$(basename "$(ls "$DOWNLOAD_DIR"/axon-server_*.deb | head -1)")
      fi
      if [ "$want_dashboard" -eq 1 ]; then
        download_deb_package "axon-dash=${RESOLVED_DASHBOARD_VERSION}-1:${ARCH}"
        DASHBOARD_PKG_FILE=$(basename "$(ls "$DOWNLOAD_DIR"/axon-dash_*.deb | head -1)")
      fi
    fi

    if [ "$want_cassandra" -eq 1 ] && [ "$CASSANDRA_INSTALL_FORMAT" = "pkg" ]; then
      [ "$CASSANDRA_SERIES" != "3.11" ] || die "Cassandra 3.11 pkg install is not available on Debian/Ubuntu (no apt channel upstream)."
      REPO_SERIES="$(echo "$CASSANDRA_SERIES" | cut -d. -f1-2 | tr -d '.')x"
      DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates
      curl -L https://downloads.apache.org/cassandra/KEYS | gpg --dearmor -o /usr/share/keyrings/apache-cassandra.gpg
      echo "deb [signed-by=/usr/share/keyrings/apache-cassandra.gpg] https://debian.cassandra.apache.org ${REPO_SERIES} main" \
        > /etc/apt/sources.list.d/cassandra.list
      apt-get update
      (cd "$DOWNLOAD_DIR" && apt-get download "cassandra=${CASSANDRA_VERSION}")
      CASSANDRA_PKG_FILE=$(basename "$(ls "$DOWNLOAD_DIR"/cassandra_"${CASSANDRA_VERSION}"*.deb | head -1)")
    fi

    if [ "$want_java" -eq 1 ] && [ "$CASSANDRA_INSTALL_FORMAT" = "pkg" ]; then
      # The Cassandra .deb declares a real java-${JAVA_MAJOR}*-headless
      # dependency that a tarball JDK never registers with dpkg.
      local_zulu_pkg="$(zulu_headless_package "$JAVA_MAJOR")"
      curl -s https://repos.azul.com/azul-repo.key | gpg --dearmor -o /usr/share/keyrings/azul.gpg
      echo "deb [signed-by=/usr/share/keyrings/azul.gpg] https://repos.azul.com/zulu/deb stable main" \
        > /etc/apt/sources.list.d/zulu.list
      apt-get update
      # --download-only resolves the full dependency chain into apt's cache.
      apt-get install -y --download-only "$local_zulu_pkg"
      cp /var/cache/apt/archives/*.deb "$DOWNLOAD_DIR/"
      JAVA_PKG_FILE=$(basename "$(ls "$DOWNLOAD_DIR"/"${local_zulu_pkg}"_*.deb | head -1)")
    fi
    ;;

  centos|rhel|fedora|amzn|rocky|almalinux)
    if [ "$need_axonops_repo" -eq 1 ]; then
      cat > /etc/yum.repos.d/axonops.repo <<REPOEOF
[axonops]
name=AxonOps Repository
baseurl=${REPO_URL}/yum/
enabled=1
gpgcheck=0
REPOEOF
      dnf -y install 'dnf-command(download)' cpio findutils > /dev/null 2>&1 || true

      RPM_ARCH=$(uname -m)
      download_rpm_package() {
        local pkg_spec=$1
        echo "Downloading (dnf download): $pkg_spec"
        dnf download --destdir "$DOWNLOAD_DIR" "$pkg_spec"
      }

      if [ "$want_agent" -eq 1 ]; then
        download_rpm_package "axon-agent-${RESOLVED_AGENT_VERSION}-1.${RPM_ARCH}"
        AGENT_PKG_FILE=$(basename "$(ls "$DOWNLOAD_DIR"/*axon-agent-"${RESOLVED_AGENT_VERSION}"*.rpm | head -1)")

        # noarch pinned: some java-agents ship a stale x86_64 build beside the
        # fixed noarch build under the same name/version.
        download_rpm_package "${RESOLVED_JAVA_AGENT_PACKAGE}-${RESOLVED_JAVA_AGENT_VERSION}-1.noarch"
        JAVA_AGENT_RPM=$(ls "$DOWNLOAD_DIR"/*"${RESOLVED_JAVA_AGENT_PACKAGE}-${RESOLVED_JAVA_AGENT_VERSION}"*.rpm | head -1)
        JAVA_AGENT_PKG_FILE=$(basename "$JAVA_AGENT_RPM")
        extract_jar_from_rpm "$JAVA_AGENT_RPM"
      fi
      if [ "$want_server" -eq 1 ]; then
        download_rpm_package "axon-server-${RESOLVED_SERVER_VERSION}-1.${RPM_ARCH}"
        SERVER_PKG_FILE=$(basename "$(ls "$DOWNLOAD_DIR"/*axon-server-"${RESOLVED_SERVER_VERSION}"*.rpm | head -1)")
      fi
      if [ "$want_dashboard" -eq 1 ]; then
        download_rpm_package "axon-dash-${RESOLVED_DASHBOARD_VERSION}-1.${RPM_ARCH}"
        DASHBOARD_PKG_FILE=$(basename "$(ls "$DOWNLOAD_DIR"/*axon-dash-"${RESOLVED_DASHBOARD_VERSION}"*.rpm | head -1)")
      fi
    fi

    if [ "$want_cassandra" -eq 1 ] && [ "$CASSANDRA_INSTALL_FORMAT" = "pkg" ]; then
      # 3.11 comes from the JFrog mirror; 4.1/5.0 from redhat.cassandra.apache.org.
      if [ "$CASSANDRA_SERIES" = "3.11" ]; then
        CASSANDRA_RPM_BASEURL="$REDHAT_REPO_311X"
      else
        CASSANDRA_RPM_BASEURL="https://redhat.cassandra.apache.org/$(echo "$CASSANDRA_SERIES" | tr -d '.')x/noboolean/"
      fi
      download_package \
        "${CASSANDRA_RPM_BASEURL}cassandra-${CASSANDRA_VERSION}-1.noarch.rpm" \
        "cassandra-${CASSANDRA_VERSION}-1.noarch.rpm"
      CASSANDRA_PKG_FILE="cassandra-${CASSANDRA_VERSION}-1.noarch.rpm"
    fi

    if [ "$want_java" -eq 1 ] && [ "$CASSANDRA_INSTALL_FORMAT" = "pkg" ]; then
      local_zulu_pkg="$(zulu_headless_package "$JAVA_MAJOR")"
      dnf -y install "$ZULU_PKG_RPM" > /dev/null 2>&1 || true
      echo "Downloading (dnf download --resolve): ${local_zulu_pkg}.$(uname -m)"
      dnf download --resolve --destdir "$DOWNLOAD_DIR" "${local_zulu_pkg}.$(uname -m)"
      JAVA_PKG_FILE=$(basename "$(ls "$DOWNLOAD_DIR"/"${local_zulu_pkg}"-*.rpm 2>/dev/null | head -1)")
    fi
    ;;

  *)
    die "Unsupported OS: $OS"
    ;;
esac

# --------------------------------------------------------------------------
# Static-URL artifacts (Cassandra tarball, OpenSearch, Zulu tarball)
# --------------------------------------------------------------------------

if [ "$want_cassandra" -eq 1 ] && [ "$CASSANDRA_INSTALL_FORMAT" = "tar" ]; then
  download_package \
    "https://archive.apache.org/dist/cassandra/${CASSANDRA_VERSION}/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz" \
    "apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz"
  CASSANDRA_TAR_FILE="apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz"
fi

if [ "$want_server" -eq 1 ]; then
  # OpenSearch publishes direct RPM/deb release artifacts per version. Arch
  # names are OpenSearch's own: "x64"/"arm64".
  if [ "$UNAME_ARCH" = "x86_64" ]; then
    OPENSEARCH_ARCH="x64"
  else
    OPENSEARCH_ARCH="arm64"
  fi
  if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    OPENSEARCH_EXT="deb"
  else
    OPENSEARCH_EXT="rpm"
  fi
  download_package \
    "https://artifacts.opensearch.org/releases/bundle/opensearch/${OPENSEARCH_VERSION}/opensearch-${OPENSEARCH_VERSION}-linux-${OPENSEARCH_ARCH}.${OPENSEARCH_EXT}" \
    "opensearch-${OPENSEARCH_VERSION}-linux-${OPENSEARCH_ARCH}.${OPENSEARCH_EXT}"
  OPENSEARCH_PKG_FILE="opensearch-${OPENSEARCH_VERSION}-linux-${OPENSEARCH_ARCH}.${OPENSEARCH_EXT}"
fi

if [ "$want_java" -eq 1 ]; then
  # Zulu JDK tarball. Azul uses "x64" for x86_64 and uname-style "aarch64" on ARM.
  if [ "$UNAME_ARCH" = "x86_64" ]; then
    ZULU_ARCH="x64"
  else
    ZULU_ARCH="$UNAME_ARCH"
  fi
  download_package \
    "https://cdn.azul.com/zulu/bin/zulu${ZULU_BUILD}-jdk${ZULU_VERSION}-linux_${ZULU_ARCH}.tar.gz" \
    "zulu${ZULU_BUILD}-jdk${ZULU_VERSION}-linux_${ZULU_ARCH}.tar.gz"
  ZULU_TARBALL_FILE="zulu${ZULU_BUILD}-jdk${ZULU_VERSION}-linux_${ZULU_ARCH}.tar.gz"
fi

# --------------------------------------------------------------------------
# Summary — the exact attributes to set for the cookbook's offline install
# --------------------------------------------------------------------------

echo ""
echo "Download complete!"
echo ""
echo "To use these packages with Chef:"
echo "1. Copy all downloaded files to the target system at: $DOWNLOAD_DIR"
echo "2. Set the following Chef attributes (actual filenames from this run):"
echo ""
echo "  node['axonops']['offline_install'] = true"
echo "  node['axonops']['offline_packages_path'] = '$DOWNLOAD_DIR'"
[ -n "$AGENT_PKG_FILE" ]      && echo "  node['axonops']['offline_packages']['agent'] = '$AGENT_PKG_FILE'"
[ -n "$SERVER_PKG_FILE" ]     && echo "  node['axonops']['offline_packages']['server'] = '$SERVER_PKG_FILE'"
[ -n "$DASHBOARD_PKG_FILE" ]  && echo "  node['axonops']['offline_packages']['dashboard'] = '$DASHBOARD_PKG_FILE'"
[ -n "$JAVA_AGENT_PKG_FILE" ] && echo "  node['axonops']['offline_packages']['java_agent'] = '$JAVA_AGENT_PKG_FILE' # RPM/deb — recipes/agent.rb installs this, not the extracted jar"
[ -n "$CASSANDRA_TAR_FILE" ]  && echo "  node['axonops']['offline_packages']['cassandra'] = '$CASSANDRA_TAR_FILE'"
[ -n "$CASSANDRA_PKG_FILE" ]  && echo "  node['axonops']['offline_packages']['cassandra_pkg'] = '$CASSANDRA_PKG_FILE'"
[ -n "$JAVA_PKG_FILE" ]       && echo "  node['axonops']['offline_packages']['java'] = '$JAVA_PKG_FILE' # required: Cassandra's RPM/deb depends on java-${JAVA_MAJOR:-?}*-headless"
[ -n "$OPENSEARCH_PKG_FILE" ] && echo "  node['axonops']['offline_packages']['opensearch'] = '$OPENSEARCH_PKG_FILE'"
[ -n "$ZULU_TARBALL_FILE" ]   && echo "  # Java tarball: $ZULU_TARBALL_FILE (node['java']['tarball_path'] for tar install_format)"
echo ""
