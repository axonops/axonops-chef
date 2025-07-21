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

# AxonOps packages
AXONOPS_PACKAGES = {
    "deb": {
        "axon-server": ["amd64", "arm64"],
        "axon-agent": ["amd64", "arm64"],
        "axon-dash": ["amd64", "arm64"],
        "axon-cassandra3-agent": ["all"],
        "axon-cassandra311-agent": ["all"],
        "axon-cassandra4-agent": ["all"],
        "axon-cassandra40-agent": ["all"],
        "axon-cassandra41-agent": ["all"],
        "axon-cassandra5-agent": ["all"],
        "axon-cassandra50-agent": ["all"],
    },
    "rpm": {
        "axon-server": ["noarch"],
        "axon-agent": ["x86_64", "aarch64"],
        "axon-dash": ["noarch"],
        "axon-cassandra3-agent": ["noarch"],
        "axon-cassandra311-agent": ["noarch"],
        "axon-cassandra4-agent": ["noarch"],
        "axon-cassandra40-agent": ["noarch"],
        "axon-cassandra41-agent": ["noarch"],
        "axon-cassandra5-agent": ["noarch"],
        "axon-cassandra50-agent": ["noarch"],
    }
}

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
        
    def download_file(self, url, dest_path=None, expected_checksum=None):
        """Download a file with progress indication."""
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
                
                # Verify checksum if provided
                if expected_checksum:
                    print("  Verifying checksum...")
                    actual_checksum = self.calculate_checksum(dest_path)
                    if actual_checksum.lower() != expected_checksum.lower():
                        os.remove(dest_path)
                        raise ValueError(f"Checksum mismatch! Expected: {expected_checksum}, Got: {actual_checksum}")
                    print("  ✓ Checksum verified")
                    
        except urllib.error.HTTPError as e:
            print(f"  ✗ HTTP Error {e.code}: {e.reason}")
            raise
        except Exception as e:
            print(f"  ✗ Error: {e}")
            raise
            
        return dest_path
    
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
    
    def download_axonops(self, package_type=None):
        """Download AxonOps packages."""
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
                self._download_axonops_deb()
            elif pkg_type == "rpm":
                self._download_axonops_rpm()
    
    def _download_axonops_deb(self):
        """Download AxonOps Debian packages."""
        print("\nDownloading AxonOps DEB packages...")
        base_url = "https://packages.axonops.com/apt"
        
        for package_name, architectures in AXONOPS_PACKAGES["deb"].items():
            for arch in architectures:
                # Download Packages.gz
                packages_url = f"{base_url}/dists/axonops/main/binary-{arch}/Packages.gz"
                packages_gz_path = self.download_dir / f"Packages_{arch}.gz"
                packages_path = self.download_dir / f"Packages_{arch}"
                
                try:
                    self.download_file(packages_url, packages_gz_path)
                    
                    # Extract Packages.gz
                    with gzip.open(packages_gz_path, 'rb') as f_in:
                        with open(packages_path, 'wb') as f_out:
                            shutil.copyfileobj(f_in, f_out)
                    
                    # Parse packages and find latest version
                    with open(packages_path, 'r') as f:
                        content = f.read()
                        packages = content.split('\n\n')
                        
                        latest_version = None
                        latest_filename = None
                        latest_sha256 = None
                        
                        for pkg in packages:
                            if f"Package: {package_name}\n" in pkg:
                                version_match = re.search(r'Version: (.+)', pkg)
                                filename_match = re.search(r'Filename: (.+)', pkg)
                                sha256_match = re.search(r'SHA256: (.+)', pkg)
                                
                                if version_match and filename_match:
                                    version = version_match.group(1)
                                    filename = filename_match.group(1)
                                    sha256 = sha256_match.group(1) if sha256_match else None
                                    
                                    if not latest_version or self._compare_versions(version, latest_version) > 0:
                                        latest_version = version
                                        latest_filename = filename
                                        latest_sha256 = sha256
                        
                        if latest_filename:
                            # Download the package
                            package_url = f"{base_url}/{latest_filename}"
                            package_file = self.download_dir / os.path.basename(latest_filename)
                            self.download_file(package_url, package_file, latest_sha256)
                            print(f"  ✓ Downloaded {package_name} {latest_version} for {arch}")
                    
                    # Cleanup
                    os.remove(packages_gz_path)
                    os.remove(packages_path)
                    
                except Exception as e:
                    print(f"  ✗ Error downloading {package_name} for {arch}: {e}")
    
    def _download_axonops_rpm(self):
        """Download AxonOps RPM packages."""
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
            
            for package_name, architectures in AXONOPS_PACKAGES["rpm"].items():
                latest_version = None
                latest_location = None
                latest_checksum = None
                
                for package in root.findall('common:package', ns):
                    name_elem = package.find('common:name', ns)
                    if name_elem is not None and name_elem.text == package_name:
                        arch_elem = package.find('common:arch', ns)
                        if arch_elem is not None and arch_elem.text in architectures:
                            version_elem = package.find('common:version', ns)
                            location_elem = package.find('common:location', ns)
                            checksum_elem = package.find('common:checksum', ns)
                            
                            if version_elem is not None and location_elem is not None:
                                version = f"{version_elem.get('ver')}-{version_elem.get('rel')}"
                                location = location_elem.get('href')
                                checksum = checksum_elem.text if checksum_elem is not None and checksum_elem.get('type') == 'sha256' else None
                                
                                if not latest_version or self._compare_versions(version, latest_version) > 0:
                                    latest_version = version
                                    latest_location = location
                                    latest_checksum = checksum
                
                if latest_location:
                    # Download the package
                    package_url = f"{base_url}/{latest_location}"
                    package_file = self.download_dir / os.path.basename(latest_location)
                    self.download_file(package_url, package_file, latest_checksum)
                    print(f"  ✓ Downloaded {package_name} {latest_version}")
            
            # Cleanup
            os.remove(repomd_path)
            os.remove(primary_gz_path)
            os.remove(primary_path)
            
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
    parser.add_argument("--version", help="Specific version to download (for Cassandra/Elasticsearch)")
    parser.add_argument("--output-dir", default=DOWNLOAD_DIR, help="Output directory")
    parser.add_argument("--java-arch", choices=["x64", "aarch64"], default="x64", help="Java architecture (default: x64)")
    parser.add_argument("--components", nargs="+", choices=["java", "cassandra", "elasticsearch", "axonops"], help="Components to download")
    parser.add_argument("--non-interactive", action="store_true", help="Run in non-interactive mode")
    
    args = parser.parse_args()
    
    downloader = PackageDownloader(args.output_dir)
    
    print("AxonOps Chef Cookbook Offline Package Downloader")
    print("=" * 50)
    print(f"Download directory: {downloader.download_dir}")
    
    try:
        if args.all:
            # Download everything
            downloader.download_axonops("deb")
            downloader.download_axonops("rpm")
            downloader.download_cassandra(non_interactive=True)
            downloader.download_elasticsearch(non_interactive=True)
            downloader.download_java(args.java_arch)
        elif args.components:
            # Download specified components
            for component in args.components:
                if component == 'axonops':
                    downloader.download_axonops(args.package_type)
                elif component == 'cassandra':
                    downloader.download_cassandra(args.version, non_interactive=args.non_interactive)
                elif component == 'elasticsearch':
                    downloader.download_elasticsearch(args.version, non_interactive=args.non_interactive)
                elif component == 'java':
                    downloader.download_java(args.java_arch)
        elif args.axonops or args.cassandra or args.elasticsearch or args.java:
            # Legacy argument support
            if args.axonops:
                downloader.download_axonops(args.package_type)
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