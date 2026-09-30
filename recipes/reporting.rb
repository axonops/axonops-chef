#
# Cookbook:: axonops
# Recipe:: reporting
#
# Reports v2 (ASB-4652): installs and runs axon-reporting, which replaces the
# deprecated axon-dash-pdf / axon-dash-pdf2 packages. It must run on the same
# host as axon-dash, so axonops::dashboard includes this recipe when
# node['axonops']['dashboard']['reporting']['enabled'] is true.
#
# Existing axon-dash-pdf / axon-dash-pdf2 packages are left in place; remove
# them manually once Reports v2 is confirmed working.
#

reporting = node['axonops']['reporting']
state = reporting['state'].to_s

unless %w(present absent).include?(state)
  raise "axonops.reporting.state must be 'present' or 'absent', got '#{state}'"
end

if state == 'absent'
  service 'axon-reporting' do
    action [:stop, :disable]
    only_if { ::File.exist?('/usr/lib/systemd/system/axon-reporting.service') || ::File.exist?('/lib/systemd/system/axon-reporting.service') }
  end

  package reporting['package'] do
    action :remove
  end

  return
end

if node['axonops']['offline_install']
  offline_file = node['axonops']['offline_packages']['reporting']

  if offline_file.nil? || offline_file.to_s.empty?
    # Mirrors the Ansible dash role: no staged package means no offline install.
    log 'axon-reporting-offline-skipped' do
      message 'Offline install: axonops.offline_packages.reporting is not set, skipping axon-reporting. ' \
              'Reports will not work until axon-reporting is installed.'
      level :warn
    end
    return
  end

  package_path = AxonOpsOffline.resolve(self, offline_file)

  case node['platform_family']
  when 'debian'
    dpkg_package reporting['package'] do
      source package_path
      action :install
      notifies :restart, 'service[axon-reporting]', :delayed
    end
  when 'rhel', 'fedora', 'amazon'
    rpm_package reporting['package'] do
      source package_path
      action :install
      notifies :restart, 'service[axon-reporting]', :delayed
    end
  else
    AxonOpsOffline.unsupported_platform!(node, 'axon-reporting')
  end
else
  include_recipe 'axonops::repo'

  package reporting['package'] do
    version AxonOpsReporting.package_version(reporting['version']) if AxonOpsReporting.package_version(reporting['version'])
    action :install
    notifies :restart, 'service[axon-reporting]', :delayed
  end
end

service 'axon-reporting' do
  supports status: true, restart: true
  action reporting['start_at_boot'] ? [:enable, :start] : [:nothing]
end
