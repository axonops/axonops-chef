# Verifies the cqlsh Python virtualenv (recipes/cqlsh_venv.rb). The bundled
# cqlsh fails on Python >= 3.12 (Ubuntu 24.04+, Debian 13); the venv wrapper
# must shadow it on PATH and run without an ImportError.

venv_path = '/opt/cassandra-cqlsh-venv'
wrapper_path = '/usr/local/bin/cqlsh'

control 'cqlsh_venv_created' do
  title 'cqlsh virtualenv exists with cqlsh installed'
  describe file("#{venv_path}/bin/pip") do
    it { should exist }
    it { should be_executable }
  end
  describe file("#{venv_path}/bin/cqlsh") do
    it { should exist }
    it { should be_executable }
  end
end

control 'cqlsh_wrapper_installed' do
  title 'cqlsh wrapper is installed on PATH and execs the venv binary'
  describe file(wrapper_path) do
    it { should exist }
    it { should be_executable }
    its('content') { should match %r{exec #{Regexp.escape(venv_path)}/bin/cqlsh} }
  end
end

control 'cqlsh_wrapper_shadows_bundled' do
  title 'plain cqlsh on PATH resolves to the venv wrapper'
  # login shell so /etc/profile.d/cassandra.sh (tar install) is sourced, proving
  # /usr/local/bin still wins over $CASSANDRA_HOME/bin.
  describe command('bash -lc "command -v cqlsh"') do
    its('stdout') { should match %r{^#{Regexp.escape(wrapper_path)}$} }
  end
end

control 'cqlsh_runs_without_importerror' do
  title 'cqlsh starts under the host Python without ImportError'
  describe command("#{wrapper_path} --version") do
    its('exit_status') { should eq 0 }
    its('stderr') { should_not match(/ImportError|ModuleNotFoundError/) }
  end
end
