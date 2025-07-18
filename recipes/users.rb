# Create system users first
user 'axonops' do
  system true
  shell '/bin/bash'
  home '/var/lib/axonops'
  manage_home true
end

user node['axonops']['cassandra']['user'] do
  system true
  shell '/bin/false'
  home '/var/lib/cassandra'
  manage_home true
end

# Now define groups with proper members
group 'axonops' do
  members [node['axonops']['cassandra']['user']]
  append true
  system true
end

group node['axonops']['cassandra']['group'] do
  members ['axonops']
  append true
  system true
end
