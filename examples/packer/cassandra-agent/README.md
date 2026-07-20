# Packer Example — Cassandra + AxonOps Agent

Bakes an AMI with a fresh Apache Cassandra install (`axonops::cassandra`) and
the AxonOps agent monitoring it (`axonops::agent`), via Packer's built-in
[`chef-solo` provisioner](https://developer.hashicorp.com/packer/docs/provisioners/chef-solo).

## Prerequisites

- [Packer](https://developer.hashicorp.com/packer/install) with the `amazon` plugin
- `berkshelf` gem to vendor this cookbook + its dependencies
- AWS credentials with EC2 permissions (the `amazon-ebs` builder)

## Build

```bash
cd examples/packer/cassandra-agent

# Vendor axonops + its dependency cookbooks (apt, yum, ...) into cookbooks/
gem install berkshelf   # once
berks vendor cookbooks --berksfile=../../../Berksfile

packer init cassandra-agent.pkr.hcl
packer build \
  -var 'axonops_org_key=your-org-key' \
  -var 'axonops_org_name=your-org-name' \
  cassandra-agent.pkr.hcl
```

## Notable variables

| Variable | Default | Notes |
|----------|---------|-------|
| `region` | `eu-west-1` | AWS region to build in |
| `source_ami_filter` | `Rocky-9-EC2-Base-9*.x86_64` | Base image; swap for your distro |
| `cassandra_version` | `5.0.5` | See README.md's Cassandra version matrix |
| `axonops_org_key` / `axonops_org_name` | `""` | Required for SaaS mode — see docs/AGENT.md |

`start_on_install = false` / `start_on_boot = true` in the template: Chef
doesn't start Cassandra while baking the image, but the systemd unit is
enabled so each launched instance starts fresh on first real boot — bake
once, boot many, no shared bootstrap state trapped in the image.

See the main [README.md](../../../README.md) and [docs/CASSANDRA.md](../../../docs/CASSANDRA.md)
for all `axonops::cassandra` attributes (heap size, GC type, cluster name, etc.).
