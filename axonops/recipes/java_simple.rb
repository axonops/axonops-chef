#
# Cookbook:: axonops
# Recipe:: java_simple
#
# Simple Java installation for testing
#

package 'openjdk-11-jre-headless' do
  action :install
end

# Set JAVA_HOME
file '/etc/profile.d/java.sh' do
  content <<-EOH
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-#{node['kernel']['machine']}
export PATH=$JAVA_HOME/bin:$PATH
EOH
  mode '0644'
end