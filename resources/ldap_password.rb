#
# Cookbook:: axonops
# Resource:: ldap_password
#
# Makes a DN's password match by trying a simple bind first, so a password
# that already works is never rewritten (a fresh salted hash would report a
# change on every run). On mismatch, stores an {SSHA} hash in password_attr on
# target_dn. Used by axonops::openldap for the admin (olcRootPW) and for
# seeded users (userPassword).
#
unified_mode true
provides :axonops_ldap_password

property :bind_dn, String, name_property: true
property :password, String, required: true, sensitive: true
property :target_dn, String, required: true
property :password_attr, String, default: 'userPassword'
# Rewrite only on "Invalid credentials" (:invalid_credentials) or on any bind
# failure (:any). The admin uses :invalid_credentials so a transient error
# never resets olcRootPW.
property :rewrite_on, Symbol, equal_to: [:any, :invalid_credentials], default: :any
# nil writes as root over SASL EXTERNAL.
property :manager_dn, [String, nil]
property :manager_password, [String, nil], sensitive: true

action :manage do
  status = AxonOpsOpenLDAP::Client.bind_status(new_resource.bind_dn, new_resource.password)
  rewrite = if new_resource.rewrite_on == :invalid_credentials
              status == :invalid_credentials
            else
              status != :ok
            end

  if rewrite
    converge_by("set LDAP password for #{new_resource.bind_dn}") do
      client = AxonOpsOpenLDAP::Client.new(bind_dn: new_resource.manager_dn, password: new_resource.manager_password)
      client.modify(AxonOpsOpenLDAP.replace_ldif(new_resource.target_dn,
                                                 new_resource.password_attr => AxonOpsOpenLDAP.ssha(new_resource.password)))
    end
  end
end
