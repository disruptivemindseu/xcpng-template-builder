# XCP-ng Template Builder

Packer templates for building VM templates on XCP-ng/Xenserver.

## Supported Distributions

- **Alpine 23**
- **AlmaLinux 10**: UEFI, UEFI/LVM
- **CentOS 10**: UEFI, UEFI/LVM
- **Debian 12**: UEFI, UEFI/LVM
- **Debian 13**: UEFI, UEFI/LVM
- **RHEL 10**: UEFI, UEFI/LVM
- **Rocky 10**: UEFI, UEFI/LVM

## Work in progress
- **Ubuntu**
- **Windows Server 2025**

Linux templates include cloud-init, SSH, and Xen Guest Agent pre-configured.

## Prerequisites

- Packer with [XenServer plugin](https://github.com/vatesfr/packer-plugin-xenserver/)
- Access to XCP-ng/Xenserver host
- Network access to download ISOs (Or ISO already in ISO SR)

## Quick Start

### 1. Create Variables File

Create `.env`:

```env
PKR_VAR_remote_host="192.168.1.10"
PKR_VAR_remote_username="root"
PKR_VAR_remote_password="your-password"
PKR_VAR_sr_iso_name="ISOs"
PKR_VAR_sr_name="Local storage"
PKR_VAR_network_names='["Pool-wide network associated with eth0"]'
```

Load it in your shell:

```bash
source .env
```

### 2. Build Template

```bash
cd packer/distros/debian/13/uefi
packer build debian13-uefi.pkr.hcl
```

## Customization

- **Preseed (Debian)**: Edit `http/preseed.cfg`
- **Kickstart (RHEL)**: Edit `http/ks.cfg`
- **Template Config**: Edit `.pkr.hcl` files for VM resources, boot settings, etc.

## Post-Build

### Default Behavior (Templates Stay on XCP-ng Host)

By default, templates remain on the XCP-ng host as templates:

```hcl
output_directory     = "export"
keep_vm              = "on_success"
skip_set_template    = false
format               = "none"
```

Templates are available directly in XCP-ng/Xenserver for immediate use. No files are downloaded locally.

### Export as XVA Files

To download templates as compressed XVA files, modify the `.pkr.hcl` files:

```hcl
output_directory     = "export"
keep_vm              = "never"
skip_set_template    = true
format               = "xva_compressed"
```

Templates are exported to the `export/` directory as compressed XVA files. Import them into XCP-ng when needed, then convert to templates in XCP-ng Center or XOA.

## Debugging

Enable verbose output:

```bash
PACKER_LOG=1 packer build debian13-uefi.pkr.hcl
```
