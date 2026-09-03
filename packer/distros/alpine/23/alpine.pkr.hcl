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
  # "http" rather than "tools": packer takes the address from the source of the guest's request
  # to its own HTTP server, so it needs no guest agent to find the VM. With "tools" it reads
  # xenstore, which only an agent populates, and this template installs its agent from the
  # provisioner, which cannot run before packer has an address to SSH to.
  ip_getter = "http"

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
    "apk add --no-cache cloud-init openssh openssh-server-pam cloud-utils-growpart e2fsprogs e2fsprogs-extra doas<enter><wait10>",
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

  # xen-guest-agent replaces xe-guest-utilities on this template. The Go tools report their own
  # version to XO as unsubstituted placeholders — PV-drivers-version comes back as
  # "major: @PRODUCT_MAJOR_VERSION@; minor: @PRODUCT_MINOR_VERSION@; ..." — which is aports issue
  # 13506, open since 2022, and xenserver/xe-guest-utilities#167 upstream. The two issues point at
  # each other and neither has moved. Switching agent sidesteps it entirely: measured on a guest
  # built from this template, the same VM reports real values once xen-guest-agent is running.
  #
  # It is built from source here because there is no other way to get it onto Alpine. It is not in
  # any distribution: not Alpine, not Debian, not Fedora. Upstream publishes a "Linux x86 64bit
  # executable", but that binary is glibc — it needs libc.so.6 and libpthread.so.0 — so it cannot
  # run on musl. Upstream's package registry holds deb builds only.
  #
  # Replace all of this with `apk add xen-guest-agent` the day it reaches aports, and drop the
  # files/ directory with it.
  provisioner "file" {
    source      = "files/xen-guest-agent.initd"
    destination = "/tmp/xen-guest-agent.initd"
  }

  provisioner "shell" {
    inline = [
      "set -eu",
      # Pinned to a commit rather than a branch: building a template from a moving ref makes the
      # image unreproducible. 0.4.0 is not usable — its Cargo.lock pins time 0.3.31, which no
      # longer compiles on current rustc — so this tracks main until a release ships that lock.
      # Swap this for the tag when one exists.
      "XGA_REF=6acc719051364b0d34bde3c06ecc4baf5983a41e",
      # xen-libs is installed separately and deliberately not in the virtual package: the agent
      # dlopen()s libxenstore at runtime, so removing it with the build deps leaves a binary that
      # builds, installs, and then fails to start.
      "apk add --no-cache xen-libs",
      "apk add --no-cache --virtual .xga-build cargo clang-dev xen-dev curl",
      "curl -sfL --retry 5 --retry-delay 5 --retry-all-errors --max-time 300 -o /tmp/xga.tar.gz \"https://gitlab.com/xen-project/xen-guest-agent/-/archive/$XGA_REF/xen-guest-agent-$XGA_REF.tar.gz\"",
      "mkdir -p /tmp/xga && tar xf /tmp/xga.tar.gz -C /tmp/xga --strip-components=1",
      "cd /tmp/xga && cargo fetch --locked && cargo build --release --frozen",
      "install -Dm755 target/release/xen-guest-agent /usr/sbin/xen-guest-agent",
      "install -Dm755 /tmp/xen-guest-agent.initd /etc/init.d/xen-guest-agent",
      "rc-update add xen-guest-agent boot",
      # Start it here rather than leaving it to first boot. It costs nothing and it means a
      # template can never be sealed around an agent that does not run: if the binary is
      # missing a library or the init script is wrong, the build fails here instead of
      # producing an image whose breakage only shows up in XO.
      "rc-service xen-guest-agent start",
      "pgrep -a xen-guest-agent",
      # The toolchain and the cargo caches are several hundred MB and have no business in a
      # template. Removing them here rather than trusting a later cleanup step.
      "apk del .xga-build",
      "rm -rf /tmp/xga /tmp/xga.tar.gz /tmp/xen-guest-agent.initd /root/.cargo",
    ]
  }
}
