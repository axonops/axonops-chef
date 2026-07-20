#!/usr/bin/env python3
"""
Download script for AxonOps Chef cookbook offline installation packages.
Downloads AxonOps packages, Apache Cassandra tarballs, Azul JDK, and Elasticsearch.

Usage:
    # Interactive mode
    ./download_offline_packages.py

    # Non-interactive mode
    ./download_offline_packages.py --all
    ./download_offline_packages.py --axonops --package-type deb
    ./download_offline_packages.py --cassandra --version 5.0
    ./download_offline_packages.py --elasticsearch --version 7.17
    ./download_offline_packages.py --java
"""

import os
import sys
import urllib.request
import urllib.error
import hashlib
import json
import argparse
import re
import gzip
import shutil
import fnmatch
import xml.etree.ElementTree as ET
import time
from pathlib import Path
from urllib.parse import urljoin
from html.parser import HTMLParser

# Configuration
SCRIPT_DIR = Path(__file__).parent
DOWNLOAD_DIR = SCRIPT_DIR.parent / "offline_packages"
USER_AGENT = "AxonOps-Chef-Downloader/1.0"

# Cassandra versions to offer
CASSANDRA_VERSIONS = {
    "5.0": ["5.0.4", "5.0.3", "5.0.2", "5.0.1", "5.0.0"],
    "4.1": ["4.1.7", "4.1.6", "4.1.5", "4.1.4"],
    "4.0": ["4.0.14", "4.0.13", "4.0.12", "4.0.11"],
    "3.11": ["3.11.16", "3.11.15", "3.11.14"],
    "3.0": ["3.0.30", "3.0.29", "3.0.28"]
}

# Elasticsearch versions to offer - Only support version 7
ELASTICSEARCH_VERSIONS = {
    "7": ["7.17.26", "7.17.25", "7.17.24", "7.17.23"]
}

# Java distributions
JAVA_DISTRIBUTIONS = {
    "azul_17": {
        "name": "Azul Zulu JDK 17",
        "platforms": {
            "linux_x64": "https://cdn.azul.com/zulu/bin/zulu17.54.21-ca-jdk17.0.13-linux_x64.tar.gz",
            "linux_aarch64": "https://cdn.azul.com/zulu/bin/zulu17.54.21-ca-jdk17.0.13-linux_aarch64.tar.gz",
            "macosx_x64": "https://cdn.azul.com/zulu/bin/zulu17.54.21-ca-jdk17.0.13-macosx_x64.tar.gz",
            "macosx_aarch64": "https://cdn.azul.com/zulu/bin/zulu17.54.21-ca-jdk17.0.13-macosx_aarch64.tar.gz"
        }
    }
}

# AxonOps package selection.
#
# The exact package names drift (dotted series, JDK-variant suffixes, new
# editions such as DSE and Kafka), so instead of hardcoding a list that goes
# stale we discover every package whose name starts with this prefix directly
# from the repository metadata (apt Packages / yum primary.xml) and download
# the latest version of each. "axon-" cleanly matches the agent/server/dash/
# cassandra/dse/kafka packages while excluding axonops-workbench,
# axonops-schema-registry, cqlai, etc.
AXONOPS_PACKAGE_PREFIX = "axon-"

# apt repository layout (verified against packages.axonops.com/apt):
#   suite/codename: axonops-apt   component: main   architectures: all amd64 arm64
# The per-arch index is served as a plain (uncompressed) "Packages" file — there
# is no "Packages.gz".
AXONOPS_APT_SUITE = "axonops-apt"
AXONOPS_APT_COMPONENT = "main"
AXONOPS_APT_ARCHITECTURES = ["all", "amd64", "arm64"]

class PackageDownloader:
    def __init__(self, download_dir=DOWNLOAD_DIR):
        self.download_dir = Path(download_dir)
        self.download_dir.mkdir(parents=True, exist_ok=True)
        self.version_cache_file = self.download_dir.parent / 'scripts' / 'version_cache.json'
        self.cache_ttl = 3600  # 1 hour

    def get_cached_version(self, key):
        """Get cached version info if not expired."""
        if not self.version_cache_file.exists():
            return None

        try:
            with open(self.version_cache_file, 'r') as f:
                cache = json.load(f)

            if key in cache:
                cached_time = cache[key].get('timestamp', 0)
                if time.time() - cached_time < self.cache_ttl:
                    return cache[key]['data']
        except:
            pass

        return None

    def set_cached_version(self, key, data):
        """Cache version info."""
        cache = {}
        if self.version_cache_file.exists():
            try:
                with open(self.version_cache_file, 'r') as f:
                    cache = json.load(f)
            except:
                pass

        cache[key] = {
            'timestamp': time.time(),
            'data': data
        }

        # Ensure scripts directory exists
        self.version_cache_file.parent.mkdir(parents=True, exist_ok=True)

        with open(self.version_cache_file, 'w') as f:
            json.dump(cache, f, indent=2)

    def get_latest_zulu_java_17_url(self, arch='x64'):
        """Get the latest Azul Zulu JDK 17 download URL."""
        cache_key = f'zulu_java_17_{arch}'
        cached = self.get_cached_version(cache_key)
        if cached:
            return cached

        # Map our arch names to Azul's naming
        arch_map = {
            'x64': 'x64',
            'aarch64': 'aarch64'
        }
        azul_arch = arch_map.get(arch, 'x64')

        api_url = f"https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?jdk_version=17&os=linux&arch={azul_arch}&hw_bitness=64&bundle_type=jdk&javafx=false&ext=tar.gz"

        try:
            print(f"Fetching latest Zulu JDK 17 version for {arch}...")
            with urllib.request.urlopen(api_url) as response:
                data = json.loads(response.read())
                url = data['url']
                self.set_cached_version(cache_key, url)
                return url
        except Exception as e:
            print(f"Warning: Could not fetch latest Zulu version: {e}")
            # Fallback to hardcoded URL
            fallback_urls = {
                'x64': 'https://cdn.azul.com/zulu/bin/zulu17.54.21-ca-jdk17.0.13-linux_x64.tar.gz',
                'aarch64': 'https://cdn.azul.com/zulu/bin/zulu17.54.21-ca-jdk17.0.13-linux_aarch64.tar.gz'
            }
            return fallback_urls.get(arch, fallback_urls['x64'])

    def get_latest_cassandra_versions(self):
        """Get the latest versions of each Cassandra major release."""
        cache_key = 'cassandra_versions'
        cached = self.get_cached_version(cache_key)
        if cached:
            return cached

        versions = {}
        base_url = "https://archive.apache.org/dist/cassandra/"

        class CassandraHTMLParser(HTMLParser):
            def __init__(self):
                super().__init__()
                self.versions = []

            def handle_starttag(self, tag, attrs):
                if tag == 'a':
                    for attr, value in attrs:
                        if attr == 'href' and value.endswith('/') and not value.startswith('/'):
                            version = value.rstrip('/')
                            if re.match(r'^\d+\.\d+(\.\d+)?$', version):
                                self.versions.append(version)

        try:
            print("Fetching latest Cassandra versions...")
            with urllib.request.urlopen(base_url) as response:
                parser = CassandraHTMLParser()
                parser.feed(response.read().decode('utf-8'))

                # Group by major version
                for version in sorted(parser.versions, reverse=True):
                    major = '.'.join(version.split('.')[:2])
                    if major not in versions:
                        versions[major] = []
                    if len(versions[major]) < 5:  # Keep top 5 versions per major
                        versions[major].append(version)

                self.set_cached_version(cache_key, versions)
                return versions
        except Exception as e:
            print(f"Warning: Could not fetch latest Cassandra versions: {e}")
            # Return hardcoded fallback
            return CASSANDRA_VERSIONS

    def get_latest_elasticsearch_versions(self):
        """Get the latest versions of Elasticsearch."""
        cache_key = 'elasticsearch_versions'
        cached = self.get_cached_version(cache_key)
        if cached:
            return cached

        # Only support Elasticsearch 7
        versions = {'7': []}

        try:
            print("Fetching latest Elasticsearch 7 versions...")
            # Use GitHub API to get releases
            api_url = "https://api.github.com/repos/elastic/elasticsearch/releases?per_page=50"
            headers = {"User-Agent": USER_AGENT}
            request = urllib.request.Request(api_url, headers=headers)

            with urllib.request.urlopen(request) as response:
                releases = json.loads(response.read())

                for release in releases:
                    tag = release.get('tag_name', '').lstrip('v')
                    if re.match(r'^7\.\d+\.\d+$', tag):  # Only match 7.x.x versions
                        if len(versions['7']) < 5:
                            versions['7'].append(tag)

                # Remove empty version groups
                versions = {k: v for k, v in versions.items() if v}

                self.set_cached_version(cache_key, versions)
                return versions
        except Exception as e:
            print(f"Warning: Could not fetch latest Elasticsearch versions: {e}")
            # Return hardcoded fallback
            return ELASTICSEARCH_VERSIONS

    def download_file(self, url, dest_path=None, expected_checksum=None, max_retries=3):
        """Download a file with progress indication.

        The CDN in front of packages.axonops.com occasionally drops the
        connection mid-transfer (urllib raises http.client.IncompleteRead, or
        the socket simply returns short). A naive read loop treats the short
        read as EOF and writes a truncated file, which then fails checksum
        verification (or, for unchecked files, is silently corrupt). We guard
        against that by comparing the bytes written to the advertised
        Content-Length and retrying the whole download on any failure.
        """
        if dest_path is None:
            dest_path = self.download_dir / os.path.basename(url)

        # Skip if already exists and checksum matches
        if dest_path.exists() and expected_checksum:
            actual_checksum = self.calculate_checksum(dest_path)
            if actual_checksum == expected_checksum:
                print(f"✓ {dest_path.name} already downloaded and verified")
                return dest_path

        print(f"Downloading {url}")
        print(f"  → {dest_path}")

        headers = {"User-Agent": USER_AGENT}

        last_error = None
        for attempt in range(1, max_retries + 1):
            request = urllib.request.Request(url, headers=headers)
            try:
                with urllib.request.urlopen(request) as response:
                    total_size = int(response.headers.get('Content-Length', 0))
                    downloaded = 0
                    block_size = 8192

                    with open(dest_path, 'wb') as f:
                        while True:
                            buffer = response.read(block_size)
                            if not buffer:
                                break
                            downloaded += len(buffer)
                            f.write(buffer)

                            if total_size > 0:
                                percent = (downloaded / total_size) * 100
                                bars = int(percent / 2)
                                print(f"\r  Progress: [{'=' * bars}{' ' * (50-bars)}] {percent:.1f}%", end='', flush=True)
                    print()  # New line after progress

                # Detect a truncated transfer: fewer bytes than advertised.
                if total_size > 0 and downloaded != total_size:
                    raise IOError(
                        f"Incomplete download: got {downloaded} of {total_size} bytes"
                    )

                # Verify checksum if provided
                if expected_checksum:
                    print("  Verifying checksum...")
                    actual_checksum = self.calculate_checksum(dest_path)
                    if actual_checksum.lower() != expected_checksum.lower():
                        raise ValueError(
                            f"Checksum mismatch! Expected: {expected_checksum}, Got: {actual_checksum}"
                        )
                    print("  ✓ Checksum verified")

                return dest_path

            except urllib.error.HTTPError as e:
                # HTTP errors (404 etc.) will not fix themselves on retry.
                print(f"  ✗ HTTP Error {e.code}: {e.reason}")
                if dest_path.exists():
                    os.remove(dest_path)
                raise
            except Exception as e:
                last_error = e
                if dest_path.exists():
                    os.remove(dest_path)
                if attempt < max_retries:
                    print(f"  ⚠ Attempt {attempt}/{max_retries} failed: {e} — retrying...")
                    time.sleep(2 * attempt)
                else:
                    print(f"  ✗ Error after {max_retries} attempts: {e}")

        raise last_error

    def calculate_checksum(self, file_path, algorithm='sha256'):
        """Calculate checksum of a file."""
        hash_algo = hashlib.new(algorithm)
        with open(file_path, "rb") as f:
            for byte_block in iter(lambda: f.read(4096), b""):
                hash_algo.update(byte_block)
        return hash_algo.hexdigest()

    def download_with_checksum(self, base_url, filename, checksum_extensions=['.sha256', '.sha512', '.sha1']):
        """Download a file and its checksum, then verify."""
        file_url = urljoin(base_url, filename)
        file_path = self.download_dir / filename

        # Try to find and download checksum
        checksum_value = None
        checksum_algo = None

        for ext in checksum_extensions:
            checksum_url = file_url + ext
            try:
                print(f"  Fetching checksum from {checksum_url}")
                with urllib.request.urlopen(checksum_url) as response:
                    checksum_content = response.read().decode('utf-8').strip()
                    # Extract checksum (might be in format "checksum filename" or just "checksum")
                    checksum_value = checksum_content.split()[0]
                    checksum_algo = ext[1:]  # Remove the dot
                    print(f"  Found {checksum_algo} checksum: {checksum_value}")
                    break
            except:
                continue

        # Download the file
        if checksum_value and checksum_algo == 'sha256':
            self.download_file(file_url, file_path, checksum_value)
        else:
            # Download without verification if no sha256 found
            self.download_file(file_url, file_path)
            if checksum_value and checksum_algo:
                # Verify with other algorithm
                actual = self.calculate_checksum(file_path, checksum_algo)
                if actual.lower() != checksum_value.lower():
                    print(f"  ✗ {checksum_algo} checksum mismatch!")
                    os.remove(file_path)
                    raise ValueError("Checksum verification failed")
                print(f"  ✓ {checksum_algo} checksum verified")

    def download_cassandra(self, version=None, non_interactive=False):
        """Download Apache Cassandra tarballs."""
        print("\n=== Apache Cassandra Downloads ===")

        # Get latest versions
        cassandra_versions = self.get_latest_cassandra_versions()

        if version:
            # Download specific version
            versions_to_download = [version]
        elif non_interactive:
            # In non-interactive mode, download latest of each major version
            versions_to_download = [versions[0] for versions in cassandra_versions.values() if versions]
        else:
            # Interactive selection
            print("\nAvailable Cassandra versions:")
            all_versions = []
            for major, versions in sorted(cassandra_versions.items(), reverse=True):
                if versions:
                    print(f"\n{major}.x series:")
                    for v in versions:
                        all_versions.append(v)
                        print(f"  {len(all_versions)}. {v}")

            print("\nSelect versions to download (comma-separated numbers, or 'latest' for latest of each major):")
            choice = input("> ").strip()

            if choice.lower() == 'latest':
                versions_to_download = [versions[0] for versions in cassandra_versions.values() if versions]
            else:
                indices = [int(x.strip())-1 for x in choice.split(',')]
                versions_to_download = [all_versions[i] for i in indices]

        for version in versions_to_download:
            print(f"\nDownloading Cassandra {version}...")
            base_url = f"https://archive.apache.org/dist/cassandra/{version}/"
            filename = f"apache-cassandra-{version}-bin.tar.gz"
            self.download_with_checksum(base_url, filename)

    def download_elasticsearch(self, version=None, non_interactive=False):
        """Download Elasticsearch tarballs."""
        print("\n=== Elasticsearch Downloads ===")

        # Get latest versions
        elasticsearch_versions = self.get_latest_elasticsearch_versions()

        platforms = {
            "1": ("linux-x86_64", "Linux x64"),
            "2": ("linux-aarch64", "Linux ARM64"),
            "3": ("darwin-x86_64", "macOS x64"),
            "4": ("darwin-aarch64", "macOS ARM64")
        }

        # Select platform
        if non_interactive:
            platform, platform_name = platforms["1"]  # Default to Linux x64
        else:
            print("\nSelect platform:")
            for key, (_, name) in platforms.items():
                print(f"  {key}. {name}")
            platform_choice = input("Platform (default: 1): ").strip() or "1"
            platform, platform_name = platforms.get(platform_choice, platforms["1"])

        if version:
            # Download specific version
            versions_to_download = [version]
        elif non_interactive:
            # In non-interactive mode, download latest of each major version
            versions_to_download = [versions[0] for versions in elasticsearch_versions.values() if versions]
        else:
            # Interactive selection
            print("\nAvailable Elasticsearch versions:")
            all_versions = []
            for major, versions in sorted(elasticsearch_versions.items(), reverse=True):
                if versions:
                    print(f"\n{major}.x series:")
                    for v in versions:
                        all_versions.append(v)
                        print(f"  {len(all_versions)}. {v}")

            print("\nSelect versions to download (comma-separated numbers, or 'latest' for latest of each major):")
            choice = input("> ").strip()

            if choice.lower() == 'latest':
                versions_to_download = [versions[0] for versions in elasticsearch_versions.values() if versions]
            else:
                indices = [int(x.strip())-1 for x in choice.split(',')]
                versions_to_download = [all_versions[i] for i in indices]

        for version in versions_to_download:
            print(f"\nDownloading Elasticsearch {version} for {platform_name}...")
            base_url = "https://artifacts.elastic.co/downloads/elasticsearch/"
            filename = f"elasticsearch-{version}-{platform}.tar.gz"
            self.download_with_checksum(base_url, filename, ['.sha512'])

    def download_java(self, arch='x64'):
        """Download Java distributions."""
        print("\n=== Java Downloads ===")

        print(f"\nDownloading Azul Zulu JDK 17 for Linux {arch}...")
        url = self.get_latest_zulu_java_17_url(arch)
        filename = os.path.basename(url)
        print(f"\n  URL: {url}")
        self.download_file(url, self.download_dir / filename)

    def _match_filter(self, name, patterns):
        """Decide whether ``name`` is wanted and which version is pinned.

        ``patterns`` is an optional list of ``(glob, version_or_None)`` tuples,
        where ``glob`` is a shell-style pattern matched against the full package
        name (e.g. ``axon-cassandra3.11-agent`` or ``axon-cassandra5*``) and the
        optional pinned version restricts which version is downloaded. When
        ``patterns`` is empty/None, every ``axon-*`` package is selected at its
        latest version.

        Returns ``(matched, pinned_version)``.
        """
        if not name.startswith(AXONOPS_PACKAGE_PREFIX):
            return (False, None)
        if not patterns:
            return (True, None)
        for glob, pinned in patterns:
            if fnmatch.fnmatch(name, glob):
                return (True, pinned)
        return (False, None)

    def _version_matches(self, actual, pinned):
        """Return True if ``actual`` satisfies the ``pinned`` version.

        Accepts an exact match, or matches the upstream version portion of an
        RPM ``ver-rel`` string (so ``--packages axon-agent=2.0.30`` matches the
        ``2.0.30-1`` RPM as well as the ``2.0.30`` DEB).
        """
        if pinned is None:
            return True
        if actual == pinned:
            return True
        if actual.split('-', 1)[0] == pinned:
            return True
        return False

    def download_axonops(self, package_type=None, package_filter=None):
        """Download AxonOps packages.

        ``package_filter`` optionally restricts which ``axon-*`` packages are
        fetched (list of shell-style globs). Regardless of the filter, only the
        latest version of each matching package is downloaded.
        """
        print("\n=== AxonOps Downloads ===")

        if not package_type:
            print("\nSelect package type:")
            print("  1. DEB (Debian/Ubuntu)")
            print("  2. RPM (RHEL/CentOS)")
            print("  3. Both")
            choice = input("Choice (default: 3): ").strip() or "3"

            if choice == "1":
                package_types = ["deb"]
            elif choice == "2":
                package_types = ["rpm"]
            else:
                package_types = ["deb", "rpm"]
        else:
            package_types = [package_type]

        for pkg_type in package_types:
            if pkg_type == "deb":
                self._download_axonops_deb(package_filter)
            elif pkg_type == "rpm":
                self._download_axonops_rpm(package_filter)

    def _download_axonops_deb(self, package_filter=None):
        """Download AxonOps Debian packages.

        Discovers every ``axon-*`` package present in the apt repository (across
        the ``all``, ``amd64`` and ``arm64`` binary indexes) and downloads the
        latest version of each, optionally restricted by ``package_filter``
        (list of shell-style globs). The apt index is a plain, uncompressed
        ``Packages`` file — there is no ``Packages.gz``.
        """
        print("\nDownloading AxonOps DEB packages...")
        base_url = "https://packages.axonops.com/apt"

        # package_name -> (version, filename, sha256) for the newest version seen
        latest = {}

        for arch in AXONOPS_APT_ARCHITECTURES:
            packages_url = (
                f"{base_url}/dists/{AXONOPS_APT_SUITE}/{AXONOPS_APT_COMPONENT}"
                f"/binary-{arch}/Packages"
            )
            packages_path = self.download_dir / f"Packages_{arch}"

            try:
                self.download_file(packages_url, packages_path)

                with open(packages_path, 'r') as f:
                    stanzas = f.read().split('\n\n')

                for pkg in stanzas:
                    name_match = re.search(r'^Package: (.+)$', pkg, re.MULTILINE)
                    if not name_match:
                        continue
                    package_name = name_match.group(1).strip()
                    matched, pinned = self._match_filter(package_name, package_filter)
                    if not matched:
                        continue

                    version_match = re.search(r'^Version: (.+)$', pkg, re.MULTILINE)
                    filename_match = re.search(r'^Filename: (.+)$', pkg, re.MULTILINE)
                    sha256_match = re.search(r'^SHA256: (.+)$', pkg, re.MULTILINE)
                    if not (version_match and filename_match):
                        continue

                    version = version_match.group(1).strip()
                    if not self._version_matches(version, pinned):
                        continue
                    filename = filename_match.group(1).strip()
                    sha256 = sha256_match.group(1).strip() if sha256_match else None

                    current = latest.get(package_name)
                    if current is None or self._compare_versions(version, current[0]) > 0:
                        latest[package_name] = (version, filename, sha256)

                os.remove(packages_path)

            except Exception as e:
                print(f"  ✗ Error reading apt index for {arch}: {e}")

        if not latest:
            if package_filter:
                print(f"  ✗ No packages matched {package_filter} in the apt repository")
            else:
                print("  ✗ No axon-* packages found in the apt repository")
            return

        for package_name in sorted(latest):
            version, filename, sha256 = latest[package_name]
            try:
                package_url = f"{base_url}/{filename}"
                package_file = self.download_dir / os.path.basename(filename)
                self.download_file(package_url, package_file, sha256)
                print(f"  ✓ Downloaded {package_name} {version}")
            except Exception as e:
                print(f"  ✗ Error downloading {package_name} {version}: {e}")

    def _download_axonops_rpm(self, package_filter=None):
        """Download AxonOps RPM packages.

        Discovers every ``axon-*`` package in the yum repository and downloads
        the latest version of each (per architecture), optionally restricted by
        ``package_filter`` (list of shell-style globs).
        """
        print("\nDownloading AxonOps RPM packages...")
        base_url = "https://packages.axonops.com/yum"

        # Download repomd.xml
        repomd_url = f"{base_url}/repodata/repomd.xml"
        repomd_path = self.download_dir / "repomd.xml"

        try:
            self.download_file(repomd_url, repomd_path)

            # Parse repomd.xml to find primary.xml location
            tree = ET.parse(repomd_path)
            root = tree.getroot()
            ns = {'repo': 'http://linux.duke.edu/metadata/repo'}

            primary_location = None
            for data in root.findall('repo:data', ns):
                if data.get('type') == 'primary':
                    location = data.find('repo:location', ns)
                    if location is not None:
                        primary_location = location.get('href')
                        break

            if not primary_location:
                raise ValueError("Could not find primary.xml location in repomd.xml")

            # Download primary.xml
            primary_url = f"{base_url}/{primary_location}"
            primary_gz_path = self.download_dir / "primary.xml.gz"
            primary_path = self.download_dir / "primary.xml"

            self.download_file(primary_url, primary_gz_path)

            # Extract primary.xml.gz
            with gzip.open(primary_gz_path, 'rb') as f_in:
                with open(primary_path, 'wb') as f_out:
                    shutil.copyfileobj(f_in, f_out)

            # Parse primary.xml for packages
            tree = ET.parse(primary_path)
            root = tree.getroot()
            ns = {'common': 'http://linux.duke.edu/metadata/common'}

            # Discover the newest version of every axon-* package, keyed by
            # (name, arch) so x86_64 and aarch64 builds are both kept.
            latest = {}

            for package in root.findall('common:package', ns):
                name_elem = package.find('common:name', ns)
                if name_elem is None or name_elem.text is None:
                    continue
                package_name = name_elem.text
                matched, pinned = self._match_filter(package_name, package_filter)
                if not matched:
                    continue

                arch_elem = package.find('common:arch', ns)
                version_elem = package.find('common:version', ns)
                location_elem = package.find('common:location', ns)
                checksum_elem = package.find('common:checksum', ns)

                if version_elem is None or location_elem is None:
                    continue

                arch = arch_elem.text if arch_elem is not None else 'noarch'
                version = f"{version_elem.get('ver')}-{version_elem.get('rel')}"
                if not self._version_matches(version, pinned):
                    continue
                location = location_elem.get('href')
                checksum = (
                    checksum_elem.text
                    if checksum_elem is not None and checksum_elem.get('type') == 'sha256'
                    else None
                )

                key = (package_name, arch)
                current = latest.get(key)
                if current is None or self._compare_versions(version, current[0]) > 0:
                    latest[key] = (version, location, checksum)

            # The Cassandra/DSE/Kafka java-agent packages are now shipped as
            # `noarch` but the repo still carries obsolete `x86_64` builds of
            # older versions. When a `noarch` build exists for a package, drop
            # its arch-specific builds so we fetch a single current artifact.
            # Packages that only exist per-arch (axon-agent, axon-server,
            # axon-dash) are unaffected and keep every architecture.
            names_with_noarch = {n for (n, a) in latest if a == 'noarch'}
            latest = {
                (n, a): v for (n, a), v in latest.items()
                if a == 'noarch' or n not in names_with_noarch
            }

            # Cleanup metadata before downloading packages so a package-download
            # failure doesn't leave metadata behind.
            os.remove(repomd_path)
            os.remove(primary_gz_path)
            os.remove(primary_path)

            if not latest:
                if package_filter:
                    print(f"  ✗ No packages matched {package_filter} in the yum repository")
                else:
                    print("  ✗ No axon-* packages found in the yum repository")
                return

            for (package_name, arch) in sorted(latest):
                version, location, checksum = latest[(package_name, arch)]
                try:
                    package_url = f"{base_url}/{location}"
                    package_file = self.download_dir / os.path.basename(location)
                    self.download_file(package_url, package_file, checksum)
                    print(f"  ✓ Downloaded {package_name} {version} ({arch})")
                except Exception as e:
                    print(f"  ✗ Error downloading {package_name} {version} ({arch}): {e}")

        except Exception as e:
            print(f"  ✗ Error downloading RPM packages: {e}")

    def _compare_versions(self, version1, version2):
        """Compare two version strings."""
        def version_key(version):
            parts = []
            for part in re.split(r'[\.-]', version):
                if part.isdigit():
                    parts.append(int(part))
                else:
                    parts.append(part)
            return parts

        v1_parts = version_key(version1)
        v2_parts = version_key(version2)

        for i in range(max(len(v1_parts), len(v2_parts))):
            v1_part = v1_parts[i] if i < len(v1_parts) else 0
            v2_part = v2_parts[i] if i < len(v2_parts) else 0

            if v1_part < v2_part:
                return -1
            elif v1_part > v2_part:
                return 1

        return 0

    def create_manifest(self):
        """Create a manifest of downloaded files."""
        manifest = {
            "download_date": str(Path(__file__).stat().st_mtime),
            "files": []
        }

        for file in sorted(self.download_dir.glob("*")):
            if file.is_file() and file.name not in ["manifest.json", "Packages_amd64", "Packages_arm64", "Packages_all"]:
                manifest["files"].append({
                    "name": file.name,
                    "size": file.stat().st_size,
                    "sha256": self.calculate_checksum(file)
                })

        manifest_path = self.download_dir / "manifest.json"
        with open(manifest_path, "w") as f:
            json.dump(manifest, f, indent=2)

        print(f"\n✓ Manifest created: {manifest_path}")

def main():
    parser = argparse.ArgumentParser(description="Download offline packages for AxonOps Chef cookbook")
    parser.add_argument("--all", action="store_true", help="Download all packages (non-interactive)")
    parser.add_argument("--axonops", action="store_true", help="Download AxonOps packages")
    parser.add_argument("--cassandra", action="store_true", help="Download Cassandra tarballs")
    parser.add_argument("--elasticsearch", action="store_true", help="Download Elasticsearch tarballs")
    parser.add_argument("--java", action="store_true", help="Download Java distributions")
    parser.add_argument("--package-type", choices=["deb", "rpm"], help="Package type for AxonOps")
    parser.add_argument("--packages", help="Comma-separated list of AxonOps packages to "
                        "download (shell-style globs allowed, e.g. "
                        "'axon-cassandra3.11-agent' or 'axon-cassandra5*,axon-agent'). "
                        "Pin a version per package with 'name=version', e.g. "
                        "'axon-agent=2.0.30,axon-server=2.0.34'; unpinned entries fetch "
                        "the latest. Default: all axon-* packages at latest.")
    parser.add_argument("--version", help="Specific version to download (for Cassandra/Elasticsearch)")
    parser.add_argument("--output-dir", default=DOWNLOAD_DIR, help="Output directory")
    parser.add_argument("--java-arch", choices=["x64", "aarch64"], default="x64", help="Java architecture (default: x64)")
    parser.add_argument("--components", nargs="+", choices=["java", "cassandra", "elasticsearch", "axonops"], help="Components to download")
    parser.add_argument("--non-interactive", action="store_true", help="Run in non-interactive mode")

    args = parser.parse_args()

    package_filter = None
    if args.packages:
        package_filter = []
        for entry in args.packages.split(','):
            entry = entry.strip()
            if not entry:
                continue
            if '=' in entry:
                name, version = entry.split('=', 1)
                package_filter.append((name.strip(), version.strip() or None))
            else:
                package_filter.append((entry, None))

    downloader = PackageDownloader(args.output_dir)

    print("AxonOps Chef Cookbook Offline Package Downloader")
    print("=" * 50)
    print(f"Download directory: {downloader.download_dir}")

    try:
        if args.all:
            # Download everything. Honour --package-type when given so
            # `--all --package-type rpm` mirrors only RPMs; default is both.
            if args.package_type:
                downloader.download_axonops(args.package_type, package_filter)
            else:
                downloader.download_axonops("deb", package_filter)
                downloader.download_axonops("rpm", package_filter)
            downloader.download_cassandra(non_interactive=True)
            downloader.download_elasticsearch(non_interactive=True)
            downloader.download_java(args.java_arch)
        elif args.components:
            # Download specified components
            for component in args.components:
                if component == 'axonops':
                    downloader.download_axonops(args.package_type, package_filter)
                elif component == 'cassandra':
                    downloader.download_cassandra(args.version, non_interactive=args.non_interactive)
                elif component == 'elasticsearch':
                    downloader.download_elasticsearch(args.version, non_interactive=args.non_interactive)
                elif component == 'java':
                    downloader.download_java(args.java_arch)
        elif args.axonops or args.cassandra or args.elasticsearch or args.java:
            # Legacy argument support
            if args.axonops:
                downloader.download_axonops(args.package_type, package_filter)
            if args.cassandra:
                downloader.download_cassandra(args.version, non_interactive=args.non_interactive)
            if args.elasticsearch:
                downloader.download_elasticsearch(args.version, non_interactive=args.non_interactive)
            if args.java:
                downloader.download_java(args.java_arch)
        else:
            # Interactive mode
            print("\nWhat would you like to download?")
            print("  1. AxonOps packages")
            print("  2. Apache Cassandra")
            print("  3. Elasticsearch")
            print("  4. Java (Azul JDK)")
            print("  5. All of the above")

            choice = input("\nSelect components (comma-separated, e.g., 1,2,3): ").strip()
            choices = [c.strip() for c in choice.split(',')]

            if '5' in choices or not choices:
                choices = ['1', '2', '3', '4']

            if '1' in choices:
                downloader.download_axonops()
            if '2' in choices:
                downloader.download_cassandra()
            if '3' in choices:
                downloader.download_elasticsearch()
            if '4' in choices:
                # Ask for architecture
                print("\nSelect Java architecture:")
                print("  1. x64 (Intel/AMD)")
                print("  2. aarch64 (ARM64)")
                arch_choice = input("Architecture (default: 1): ").strip() or "1"
                arch = "aarch64" if arch_choice == "2" else "x64"
                downloader.download_java(arch)

        # Create manifest
        downloader.create_manifest()

        print("\n✅ Download complete!")
        print(f"All packages downloaded to: {downloader.download_dir}")

    except KeyboardInterrupt:
        print("\n\n⚠️  Download interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
