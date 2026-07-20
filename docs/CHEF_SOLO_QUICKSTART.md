# Chef Solo Quickstart for Beginners

This guide walks through installing AxonOps with this cookbook using **chef-solo**
— no Chef Server, no Chef account, nothing to sign up for. It assumes no prior Chef
experience.

You will learn how to:

1. [Install the tools](#1-install-the-tools)
2. [Get the cookbook onto the target machine](#2-get-the-cookbook-onto-the-target-machine)
3. [Understand the two files chef-solo needs](#3-understand-the-two-files-chef-solo-needs)
4. Run three real scenarios:
   - [Scenario A — Install Apache Cassandra only](#scenario-a--install-apache-cassandra-only)
   - [Scenario B — Install Cassandra + the AxonOps agent](#scenario-b--install-cassandra--the-axonops-agent)
   - [Scenario C — Agent only, monitoring an existing Cassandra or DSE cluster](#scenario-c--agent-only-monitoring-an-existing-cassandra-or-dse-cluster)
5. [Common mistakes and their exact error messages](#common-mistakes-and-their-exact-error-messages)
6. [Going further](#going-further)

Every command and JSON file below was run for real against Amazon Linux 2023 and
Rocky Linux 9 while writing this cookbook — not hypothetical.

## 1. Install the tools

`chef-solo` ships inside **Chef Workstation** (or the lighter-weight **Chef Infra
Client** package — either works). On the machine you're installing AxonOps on:

```bash
curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chef-workstation -c stable
```

Confirm it worked:

```bash
chef-solo --version
```

## 2. Get the cookbook onto the target machine

chef-solo needs the `axonops` cookbook **and** its dependency cookbooks
(`apt`, `yum`, and whatever those in turn depend on — declared in
`Berksfile`) sitting in a single directory it can find. The easiest way to get
everything in one shot is `berks vendor`, run from a machine with internet access
(it doesn't have to be the target machine):

```bash
git clone https://github.com/axonops/axonops-chef.git
cd axonops-chef
gem install berkshelf   # only needed once
berks vendor /tmp/cookbooks
```

`/tmp/cookbooks` now contains `axonops/` plus every cookbook it depends on —
copy (`scp`/`rsync`) that whole directory to the target machine, e.g. to
`/opt/chef/cookbooks`.

## 3. Understand the two files chef-solo needs

**`solo.rb`** — tells chef-solo where the cookbooks are. Same for every scenario
below:

```ruby
# solo.rb
file_cache_path "/var/chef/cache"
cookbook_path   ["/opt/chef/cookbooks"]
```

**`node.json`** — describes *what to do*: which recipes to run (`run_list`) and
what attributes to configure. This is the file that changes per scenario — the rest
of this guide is really just different versions of this file.

You run chef-solo the same way every time:

```bash
sudo chef-solo -j node.json -c solo.rb
```

- `-j node.json` — your attributes + run_list
- `-c solo.rb` — the cookbook_path config from above

## Scenario A — Install Apache Cassandra only

No AxonOps agent, no monitoring — just a working Cassandra node. Good for trying
the cookbook out, or as a base you'll attach monitoring to later (Scenario C).

```json
{
  "name": "cassandra-node-01",
  "axonops": {
    "cassandra": {
      "version": "5.0.5",
      "install_format": "tar",
      "start_on_install": true
    }
  },
  "run_list": [
    "recipe[axonops::cassandra]"
  ]
}
```

```bash
sudo chef-solo -j node.json -c solo.rb
```

That's it. `axonops::cassandra` installs Java automatically (the right major
version for whichever Cassandra `version` you chose — 8 for 3.11, 11 for 4.1, 17
for 5.0) and does the OS tuning Cassandra needs (`vm.max_map_count`, file limits,
etc.).

**`start_on_install: true`** is required to actually start the service — by
default Chef only *installs and configures* Cassandra without starting/restarting
it, so repeated converges (e.g. re-running to change a setting) never interrupt an
already-running cluster by surprise. Leave it `false` (the default) if you're
provisioning several nodes and want to start them together yourself, e.g. for a
controlled multi-node bootstrap.

**Want an RPM/deb install instead of a tarball?** Set
`"install_format": "pkg"` instead of `"tar"`. See
[docs/CASSANDRA.md](CASSANDRA.md) for the full attribute reference (heap sizing,
cluster name, seeds, TLS, and more).

## Scenario B — Install Cassandra + the AxonOps agent

Same as Scenario A, but AxonOps monitors the Cassandra node it just installed. Add
`axonops::agent` to the run_list and your AxonOps org credentials — that's the only
difference:

```json
{
  "name": "cassandra-node-01",
  "axonops": {
    "cassandra": {
      "version": "5.0.5",
      "install_format": "tar",
      "start_on_install": true
    },
    "agent": {
      "org_key": "your-org-key-here",
      "org_name": "your-org-name-here"
    }
  },
  "run_list": [
    "recipe[axonops::cassandra]",
    "recipe[axonops::agent]"
  ]
}
```

```bash
sudo chef-solo -j node.json -c solo.rb
```

**Order matters**: `axonops::cassandra` must come before `axonops::agent` in the
`run_list`, so the agent has a real Cassandra install to detect and attach to.

By default the agent reports to **AxonOps SaaS**
(`agents.axonops.cloud`) using `org_key`/`org_name` from your AxonOps account. To
report to a self-hosted AxonOps server instead, see
[docs/AGENT.md](AGENT.md#self-hosted-mode).

## Scenario C — Agent only, monitoring an existing Cassandra or DSE cluster

This is for a Cassandra (or DataStax Enterprise) cluster that's **already
running**, installed some other way — this cookbook never touches it, it only
attaches monitoring. Just run `axonops::agent` on its own:

**Existing Apache Cassandra:**

```json
{
  "name": "existing-cassandra-node",
  "axonops": {
    "agent": {
      "org_key": "your-org-key-here",
      "org_name": "your-org-name-here"
    }
  },
  "run_list": [
    "recipe[axonops::agent]"
  ]
}
```

The agent auto-detects Cassandra by checking common install paths
(`/etc/cassandra/cassandra.yaml`, `/usr/bin/cassandra`, `/opt/cassandra`, etc.) — no
extra configuration needed for a standard install.

**Existing DataStax Enterprise (DSE):** DSE isn't auto-detectable as reliably as
Apache Cassandra (no single standard binary/path across DSE 5.1 vs 6.7/6.8/6.9), so
tell the agent which DSE series you're running:

```json
{
  "name": "existing-dse-node",
  "axonops": {
    "cassandra": {
      "edition": "dse",
      "dse_version": "6.8"
    },
    "agent": {
      "org_key": "your-org-key-here",
      "org_name": "your-org-name-here"
    }
  },
  "run_list": [
    "recipe[axonops::agent]"
  ]
}
```

`dse_version` must be one of `5.1`, `6.7`, `6.8`, `6.9` (default `5.1` if omitted
— set it explicitly for anything else). See [docs/DSE.md](DSE.md) for the full
picture, including offline installs.

```bash
sudo chef-solo -j node.json -c solo.rb
```

## Common mistakes and their exact error messages

These are real errors people hit, verbatim, and what actually caused them.

### `Offline package not found: /opt/.../cassandra-5.0.5-1.noarch.rpm`

You're doing an [offline/airgapped install](CASSANDRA.md#offline-airgapped-install)
and a filename under `node['axonops']['offline_packages']` doesn't match a real
file on disk — usually because the attribute was nested wrong. It must be:

```json
"axonops": {
  "offline_packages": {
    "cassandra_pkg": "cassandra-3.11.19-1.noarch.rpm"
  }
}
```

not directly under `"axonops"`. Use the *exact* filenames the download script
(`axonops::offline_download_helper`) printed at the end of its own run — don't
guess or retype them.

### `An error occurred while installing json (2.21.1), and Bundler cannot continue`

You're running `bundle install`/`berks vendor` on Ubuntu without a C compiler or
Ruby headers — the `json` gem has a native extension that needs to build. Install
the build toolchain first, then retry:

```bash
sudo apt-get update
sudo apt-get install -y build-essential ruby-dev
bundle install
```

If it still fails, run `gem install json -v 2.21.1 --verbose` to see the real
underlying error, and check `ruby -v` — recent `json` releases need Ruby ≥ 3.1.

### `nothing provides java-1.8.0-headless needed by cassandra-...`

You're installing Cassandra via `install_format: "pkg"` (RPM/deb), but Java was
installed from a tarball. A Cassandra package has a real OS-level dependency on a
`java-X.Y.Z-headless` package — a tarball-extracted JDK is invisible to
rpm/dnf/dpkg's dependency resolver, even though `java` itself works fine on the
command line. Setting `install_format: "pkg"` on the `cassandra` recipe already
handles this automatically as of this cookbook — make sure you're on a current
version.

### `Could not detect Cassandra or Kafka`

You ran `recipe[axonops::agent]` on its own (Scenario C) but there's no real
Cassandra/DSE/Kafka on the box for it to find, and you didn't force an edition. If
you're monitoring DSE, set `"cassandra": {"edition": "dse"}` explicitly — DSE
detection isn't as reliable as Apache Cassandra's.

### `error: /opt/.../axon-cassandra3.11-agent-1.0.14.jar: not an rpm package`

You set `offline_packages['java_agent']` to the `.jar` filename instead of the
`.rpm`/`.deb` package filename. The offline agent install always installs the
actual package (`rpm -Uvh`/`dpkg -i`) — the jar is extracted from it separately and
automatically, you never reference it directly.

## Going further

- [docs/CASSANDRA.md](CASSANDRA.md) — full Cassandra attribute reference,
  including offline/airgapped installs
- [docs/AGENT.md](AGENT.md) — full agent configuration reference: self-hosted
  mode, TLS/mTLS, Kafka monitoring, offline installs
- [docs/DSE.md](DSE.md) — DataStax Enterprise monitoring in depth
- [docs/SERVER.md](SERVER.md) — deploying a self-hosted AxonOps server instead of
  using SaaS
- [README.md](../README.md#chef-server-deployment) — once you're comfortable with
  chef-solo, the README covers deploying via a real Chef Server with Berkshelf
  instead
