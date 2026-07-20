packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

# This cookbook never installs or manages DSE (see docs/DSE.md) — it only
# attaches monitoring. Point this at your own AMI with DSE already installed,
# there is no sensible default.
variable "source_ami" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.large"
}

variable "ssh_username" {
  type    = string
  default = "ec2-user"
}

variable "dse_version" {
  type    = string
  default = "5.1"
}

# Only needed if neither of the two auto-detected cassandra-env.sh paths
# match your DSE install — see docs/DSE.md#jvm-agent-cassandra-envsh.
variable "dse_env_file" {
  type    = string
  default = ""
}

variable "axonops_org_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "axonops_org_name" {
  type    = string
  default = ""
}

source "amazon-ebs" "dse_agent_only" {
  region        = var.region
  instance_type = var.instance_type
  ssh_username  = var.ssh_username
  source_ami    = var.source_ami
  ami_name      = "axonops-dse-agent-{{timestamp}}"
}

build {
  name    = "axonops-dse-agent-only"
  sources = ["source.amazon-ebs.dse_agent_only"]

  provisioner "shell" {
    inline = [
      "curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chef-workstation -c stable",
    ]
  }

  # DSE 5.1 needs Java 8 (docs/DSE.md#java) — axonops::java only auto-derives
  # this from node['axonops']['cassandra']['version'] via axonops::cassandra,
  # which never runs here (this cookbook doesn't manage DSE), so it's set
  # explicitly below via node['java']['version'].
  #
  # No axonops::cassandra in the run_list: DSE is already installed on the
  # base image (source_ami above) — axonops::agent only auto-detects it
  # (edition forced here in case detection misses a non-standard layout)
  # and attaches monitoring.
  provisioner "chef-solo" {
    cookbook_paths = ["cookbooks"]
    run_list = [
      "recipe[axonops::java]",
      "recipe[axonops::agent]",
    ]
    json = {
      java = {
        version = 8
      }
      axonops = {
        cassandra = {
          edition      = "dse"
          dse_version  = var.dse_version
          dse_env_file = var.dse_env_file == "" ? nil : var.dse_env_file
        }
        agent = {
          org_key  = var.axonops_org_key
          org_name = var.axonops_org_name
        }
      }
    }
  }
}
