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

# Rocky Linux 9 base — swap source_ami_filter for your distro of choice.
# Anything supported by axonops::cassandra's install_format (tar or pkg) works.
variable "source_ami_filter" {
  type    = string
  default = "Rocky-9-EC2-Base-9*.x86_64"
}

variable "instance_type" {
  type    = string
  default = "t3.large"
}

variable "cassandra_version" {
  type    = string
  default = "5.0.5"
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

source "amazon-ebs" "cassandra_agent" {
  region        = var.region
  instance_type = var.instance_type
  ssh_username  = "rocky"
  ami_name      = "axonops-cassandra-agent-{{timestamp}}"

  source_ami_filter {
    filters = {
      name                = var.source_ami_filter
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["792107900819"] # Rocky Linux
    most_recent = true
  }
}

build {
  name    = "axonops-cassandra-agent"
  sources = ["source.amazon-ebs.cassandra_agent"]

  # Chef needs a client (chef-solo ships inside chef-workstation/chef-client)
  # on the machine baking the image, before the chef-solo provisioner runs.
  provisioner "shell" {
    inline = [
      "curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chef-workstation -c stable",
    ]
  }

  # Bakes in a fresh Apache Cassandra install (axonops::cassandra) plus the
  # AxonOps agent monitoring it (axonops::agent) — see README.md in this
  # directory for how `cookbooks/` here is populated (`berks vendor`).
  provisioner "chef-solo" {
    cookbook_paths = ["cookbooks"]
    run_list = [
      "recipe[axonops::java]",
      "recipe[axonops::cassandra]",
      "recipe[axonops::agent]",
    ]
    json = {
      axonops = {
        cassandra = {
          version      = var.cassandra_version
          cluster_name = "Packer Image"
          # Chef doesn't start Cassandra during the bake — the AMI boots
          # clean and each launched instance forms/joins the cluster on its
          # own first real start.
          start_on_install = false
          start_on_boot    = true
        }
        agent = {
          org_key  = var.axonops_org_key
          org_name = var.axonops_org_name
        }
      }
    }
  }
}
