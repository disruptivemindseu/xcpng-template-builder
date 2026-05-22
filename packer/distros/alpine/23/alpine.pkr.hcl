packer {
  required_plugins {
    xenserver = {
      version = ">= 0.8.1"
      source  = "github.com/vatesfr/xenserver"
    }
  }
}

variable "remote_host" {
  type        = string
  description = "The ip or fqdn of your XenServer. This will be pulled from the env var 'PKR_VAR_remote_host'"
  sensitive   = true
  default     = null
}

variable "remote_username" {
  type        = string
  description = "The username used to interact with your XenServer. This will be pulled from the env var 'PKR_VAR_remote_username'"
  sensitive   = true
  default     = null
}

variable "remote_password" {
  type        = string
  description = "The password used to interact with your XenServer. This will be pulled from the env var 'PKR_VAR_remote_password'"
  sensitive   = true
  default     = null
}

variable "sr_iso_name" {
  type        = string
  description = "The name of the SR packer will use to store the installation ISO. This will be pulled from the env var 'PKR_VAR_sr_iso_name'"
  default     = null
}

variable "sr_name" {
  type        = string
  description = "The name of the SR packer will use to create the VM. This will be pulled from the env var 'PKR_VAR_sr_name'"
  default     = null
}

variable "network_names" {
  type        = list(string)
  description = "The names of the networks to attach to the VM. This will be pulled from the env var 'PKR_VAR_network_names'"
  default     = ["Network associated with eth0"]
}

variable "vm_name" {
  type        = string
  description = "The name of the VM to create. This will be pulled from the env var 'PKR_VAR_vm_name'"
  default     = null
}

variable "vm_description" {
  type        = string
  description = "The description of the VM to create. This will be pulled from the env var 'PKR_VAR_vm_description'"
  default     = null
}

variable "disk_name" {
  type        = string
  description = "The name of the disk to create for the VM. This will be pulled from the env var 'PKR_VAR_disk_name'"
  default     = "template-alpine23-uefi_disk1"
}

variable "vm_tags" {
  type        = list(string)
  description = "The tags to apply to the VM. This will be pulled from the env var 'PKR_VAR_vm_tags'"
  default     = ["packer", "template"]
}

locals {
  timestamp      = regex_replace(timestamp(), "[- TZ:]", "")
  buildtime      = formatdate("YYYY.MM.DD", timestamp())
  vm_name        = coalesce(var.vm_name, "template-alpine23-uefi_${local.timestamp}")
  vm_description = coalesce(var.vm_description, "[Template] Alpine 3.23 UEFI built on ${local.buildtime} by Packer")
}

source "xenserver-iso" "template" {
  iso_checksum = "d91fb5c7a73528c89e0a1aa9a7d959f9deb9ca3dc5211e39bd73fd7df0d9070e"
  iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-virt-3.23.3-x86_64.iso"

  sr_iso_name    = var.sr_iso_name
  sr_name        = var.sr_name
  tools_iso_name = ""

  remote_host     = var.remote_host
  remote_password = var.remote_password
  remote_username = var.remote_username

  http_directory = "http"
  ip_getter      = "tools"

  boot_wait = "15s"

  boot_command = [
    "<wait10>",
    "root<enter>",
    "<wait>",
    "ifconfig eth0 up && udhcpc -i eth0<enter>",
    "<wait5>",
    "wget http://{{ .HTTPIP }}:{{ .HTTPPort }}/answers -O answers<enter>",
    "<wait5>",
    "export ERASE_DISKS=/dev/xvda<enter>",
    "<wait5>",
    "setup-alpine -f $PWD/answers<enter>",
    "<wait5>",
    "template<enter>",
    "<wait5>",
    "template<enter>",
    "<wait60>",
    "mount /dev/xvda3 /mnt<enter><wait>",
    "chroot /mnt<enter><wait>",
    "apk add --no-cache cloud-init xe-guest-utilities openssh openssh-server-pam cloud-utils-growpart e2fsprogs e2fsprogs-extra doas<enter><wait10>",
    "rc-update add xe-guest-utilities boot<enter>",
    "setup-cloud-init<enter><wait10>",
    "echo 'datasource_list: [NoCloud, ConfigDrive]'> /etc/cloud/cloud.cfg.d/02-datasource.cfg<enter>",
    "mkdir -p /usr/lib/cloud-init<enter>",
    "ln -s /usr/libexec/cloud-init/write-ssh-key-fingerprints /usr/lib/cloud-init/write-ssh-key-fingerprints<enter>",
    "sed -i 's/^#PermitRootLogin prohibit-password$/PermitRootLogin yes/' /etc/ssh/sshd_config<enter>",
    "sed -i 's/#UsePAM no/UsePAM yes/' /etc/ssh/sshd_config<enter>", # https://git.alpinelinux.org/aports/tree/community/cloud-init/README.Alpine#n380
    "exit<enter>",
    "reboot<enter>"
  ]

  clone_template  = "Generic Linux BIOS"
  vm_name         = local.vm_name
  vm_description  = local.vm_description
  vcpus_max       = 1
  vcpus_atstartup = 1
  vm_memory       = 1024
  disk_size       = 8192
  disk_name       = var.disk_name
  network_names   = var.network_names
  vm_tags         = var.vm_tags
  firmware        = "uefi"

  ssh_username           = "root"
  ssh_password           = "template"
  ssh_wait_timeout       = "60000s"
  ssh_handshake_attempts = 10000

  output_directory     = "export"
  keep_vm              = "on_success"
  skip_set_template    = false
  format               = "none"
  export_network_names = ["Pool-wide network associated with eth0"]
}

build {
  sources = ["xenserver-iso.template"]
}
