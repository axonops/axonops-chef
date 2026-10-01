#
# Cookbook:: axonops
# Resource:: ldap_entry
#
# Idempotently manages one entry in the local OpenLDAP directory over
# ldapi:///. Creates the entry when missing; otherwise replaces only the
# attributes in ldap_attrs whose values differ. create_attrs are set only when
# the entry is created. Used by axonops::openldap.
#
unified_mode true
provides :axonops_ldap_entry

property :dn, String, name_property: true
property :object_classes, Array, default: []
# Attributes kept exactly at these values ({ attr => value or [values] }).
property :ldap_attrs, Hash, default: {}
# Attributes set only when the entry is created.
property :create_attrs, Hash, default: {}
# Attributes whose value order matters (slapd "{n}"-indexed, e.g. olcAccess).
property :ordered, Array, default: []
# nil binds as root over SASL EXTERNAL.
property :bind_dn, [String, nil]
property :bind_password, [String, nil], sensitive: true

action :manage do
  client = AxonOpsOpenLDAP::Client.new(bind_dn: new_resource.bind_dn, password: new_resource.bind_password)
  desired = AxonOpsOpenLDAP.normalize_attrs(new_resource.ldap_attrs)
  current = client.read(new_resource.dn, desired.keys)

  if current.nil?
    converge_by("create LDAP entry #{new_resource.dn}") do
      client.add(AxonOpsOpenLDAP.add_ldif(new_resource.dn, new_resource.object_classes,
                                          new_resource.create_attrs.merge(new_resource.ldap_attrs)))
    end
  else
    changes = AxonOpsOpenLDAP.changed_attrs(current, desired, ordered: new_resource.ordered)
    unless changes.empty?
      converge_by("update #{changes.keys.join(', ')} on #{new_resource.dn}") do
        client.modify(AxonOpsOpenLDAP.replace_ldif(new_resource.dn, changes))
      end
    end
  end
end
