#
# Cookbook:: axonops
# Recipe:: cqlsh_venv
#
# Provisions cqlsh inside a dedicated Python virtualenv.
#
# The cqlsh shipped inside the Cassandra tarball (and the distro package) relies
# on a Python driver that imports stdlib modules removed in Python 3.12+
# (asyncore, imp). On hosts whose system Python is >= 3.12 (Ubuntu 24.04+,
# Debian 13) the bundled cqlsh aborts at startup with an ImportError. We install
# the maintained standalone `cqlsh` PyPI package — which supports modern Python
# and pulls in a compatible driver transitively — into an isolated venv and
# expose it through a wrapper on PATH, leaving the system Python and the bundled
# cqlsh untouched. Mirrors the axonops-ansible-collection cassandra role
# (roles/cassandra/tasks/cqlsh-venv.yml).
#

return unless node['axonops']['cassandra']['cqlsh_venv']['enabled']

venv_path = node['axonops']['cassandra']['cqlsh_venv']['path']
wrapper_path = node['axonops']['cassandra']['cqlsh_venv']['wrapper_path']
python_bin = node['axonops']['cassandra']['cqlsh_venv']['python']
packages = node['axonops']['cassandra']['cqlsh_venv']['packages']

# pip installs the standalone cqlsh package from PyPI, which needs network
# access. Airgapped hosts have no PyPI, so skip provisioning there (leaving the
# bundled cqlsh in place) rather than failing the whole converge for a
# diagnostic client. Disable the feature entirely to silence this warning.
if node['axonops']['offline_install']
  log 'cqlsh-venv-offline-skip' do
    message 'axonops::cqlsh_venv skipped: offline_install is set and pip cannot reach PyPI. ' \
            "Set node['axonops']['cassandra']['cqlsh_venv']['enabled'] = false to silence this, " \
            'or provision cqlsh manually on airgapped hosts.'
    level :warn
  end
  return
end

# Python venv/pip build prerequisites (platform-aware). cqlsh is an add-on, so
# an unrecognised platform_family skips provisioning with a warning rather than
# aborting the whole Cassandra converge.
case node['platform_family']
when 'debian'
  package %w(python3-venv python3-pip)
when 'rhel', 'amazon', 'fedora'
  package %w(python3 python3-pip)
else
  log 'cqlsh-venv-unsupported-platform-skip' do
    message 'axonops::cqlsh_venv skipped: no Python venv prerequisites defined for ' \
            "platform_family '#{node['platform_family']}'. Provision cqlsh manually or set " \
            "node['axonops']['cassandra']['cqlsh_venv']['enabled'] = false to silence this."
    level :warn
  end
  return
end

# Create the virtualenv using the host's own python3 (the standalone cqlsh
# package supports modern Python).
execute 'create-cqlsh-venv' do
  command "#{python_bin} -m venv #{venv_path}"
  creates "#{venv_path}/bin/pip"
end

# Install cqlsh (and any extra requested packages) into the venv. `creates`
# keeps this idempotent; run pip install --upgrade manually if a newer cqlsh is
# needed later.
execute 'install-cqlsh' do
  command "#{venv_path}/bin/pip install --no-cache-dir #{packages.join(' ')}"
  creates "#{venv_path}/bin/cqlsh"
end

# Wrapper that execs cqlsh from the venv. Default /usr/local/bin/cqlsh precedes
# both $CASSANDRA_HOME/bin (tar install) and /usr/bin (pkg install) on PATH, so
# a plain `cqlsh` call transparently uses the venv version. This also fixes the
# cqlsh-based health probe in attributes/alerts.rb on Python 3.12+ hosts.
file wrapper_path do
  content "#!/bin/sh\n" \
          "# Managed by Chef (axonops::cqlsh_venv). Runs cqlsh from the dedicated\n" \
          "# virtualenv so it works on hosts whose system Python is >= 3.12.\n" \
          "exec #{venv_path}/bin/cqlsh \"$@\"\n"
  owner 'root'
  group 'root'
  mode '0755'
end
