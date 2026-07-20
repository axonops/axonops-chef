# Packer Example — AxonOps Agent Only (DataStax Enterprise)

Bakes an AMI that attaches AxonOps monitoring (`axonops::agent`) to an
**already-installed** DataStax Enterprise cluster. This cookbook never
installs or manages DSE itself — see [docs/DSE.md](../../../docs/DSE.md) — so
`source_ami` below must point at your own DSE image, not a stock distro AMI.

## Prerequisites

- [Packer](https://developer.hashicorp.com/packer/install) with the `amazon` plugin
- `berkshelf` gem to vendor this cookbook + its dependencies
- AWS credentials with EC2 permissions (the `amazon-ebs` builder)
- An existing AMI with DSE already installed and configured

## Build

```bash
cd examples/packer/dse-agent-only

# Vendor axonops + its dependency cookbooks (apt, yum, ...) into cookbooks/
gem install berkshelf   # once
berks vendor cookbooks --berksfile=../../../Berksfile

packer init dse-agent-only.pkr.hcl
packer build \
  -var 'source_ami=ami-0123456789abcdef0' \
  -var 'dse_version=5.1' \
  -var 'axonops_org_key=your-org-key' \
  -var 'axonops_org_name=your-org-name' \
  dse-agent-only.pkr.hcl
```

## Notable variables

| Variable | Default | Notes |
|----------|---------|-------|
| `source_ami` | *(required)* | Your DSE-installed AMI |
| `dse_version` | `5.1` | One of `5.1`, `6.7`, `6.8`, `6.9` — can't be auto-detected, see docs/DSE.md |
| `dse_env_file` | `""` (auto-detect) | Only set if your `cassandra-env.sh` isn't at the rpm/deb or tar default path — see docs/DSE.md#jvm-agent-cassandra-envsh |
| `axonops_org_key` / `axonops_org_name` | `""` | Required for SaaS mode — see docs/AGENT.md |

The run_list is `axonops::java` (installs Java 8, required by DSE 5.1) plus
`axonops::agent` only — no `axonops::cassandra`, since DSE is already there
and this cookbook must not touch it.
