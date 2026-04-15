packer {
  required_plugins {
    xenserver = {
      version = ">= 0.11.4"
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
  default     = "template-debian12-uefi_disk1"
}

variable "vm_tags" {
  type        = list(string)
  description = "The tags to apply to the VM. This will be pulled from the env var 'PKR_VAR_vm_tags'"
  default     = ["packer", "template"]
}

locals {
  timestamp      = regex_replace(timestamp(), "[- TZ:]", "")
  buildtime      = formatdate("YYYY.MM.DD", timestamp())
  vm_name        = coalesce(var.vm_name, "template-debian12-uefi_${local.timestamp}")
  vm_description = coalesce(var.vm_description, "[Template] Debian 12 UEFI built on ${local.buildtime} by Packer")
}

source "xenserver-iso" "template" {
  iso_checksum = "418540edffccff0254dc6c517ce45d1a9b5913107253cea39d6cdec0ff9c7ae47dcba985437991535b476523b12030aba0cc9c21db9e23b1cf2c998aaeea60e5"
  iso_url      = "https://cdimage.debian.org/cdimage/archive/12.13.0/amd64/iso-cd/debian-12.13.0-amd64-netinst.iso"

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
    "c",
    "linux /install.amd/vmlinuz ",
    "vga=788 ",
    "theme=dark ",
    "auto=true ",
    "priority=critical ",
    "url=http://{{.HTTPIP}}:{{.HTTPPort}}/preseed.cfg ",
    "hostname=template-debian12-uefi ",
    "--- ",
    "quiet ",
    "<enter>",
    "initrd /install.amd/initrd.gz ",
    "<enter>",
    "boot<enter>"
  ]

  clone_template  = "Debian Bookworm 12"
  vm_name         = local.vm_name
  vm_description  = local.vm_description
  vcpus_max       = 2
  vcpus_atstartup = 2
  vm_memory       = 4096
  disk_size       = 32768
  disk_name       = var.disk_name
  network_names   = var.network_names
  vm_tags         = var.vm_tags
  firmware        = "uefi"

  ssh_username           = "template"
  ssh_password           = "debian12-uefi"
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
