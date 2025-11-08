# XCP-ng Template Builder

A collection of Packer templates for building VM templates on XCP-ng/Xenserver infrastructure.

## Overview

This project provides automated VM template creation using HashiCorp Packer with the XenServer plugin. The templates are designed to create standardized, cloud-init enabled virtual machines that can be easily deployed and configured.

## Supported Distributions

### Debian 13 (Trixie)

The project includes two Debian 13 variants:
- **UEFI**: Standard UEFI boot with regular partitioning
- **UEFI/LVM**: UEFI boot with LVM-based storage for advanced disk management

#### Features

- **Automated Installation**: Fully automated installation using preseed configuration
- **UEFI Boot**: Modern UEFI firmware support
- **Cloud-init Ready**: Pre-configured cloud-init for easy customization
- **SSH Access**: SSH server enabled by default
- **Xen Guest Agent**: Pre-installed for better XCP-ng integration
- **Secure Defaults**: Non-root user account with sudo access

#### Template Specifications

| Component | UEFI | UEFI-LVM |
|-----------|------|----------|
| **Firmware** | UEFI | UEFI |
| **vCPUs** | 2 | 2 |
| **Memory** | 4GB | 4GB |
| **Disk Size** | 32GB | 32GB |
| **Partitioning** | Regular | LVM |
| **Default User** | template | template |
| **Password** | debian13-uefi | debian13-uefi-lvm |

### RHEL 10

The project includes two RHEL 10 variants:
- **UEFI**: Standard UEFI boot with regular partitioning
- **UEFI/LVM**: UEFI boot with LVM-based storage for advanced disk management

Note: These templates use the XCP Packer plugin (source "github.com/disruptivemindseu/xcp") and expect the RHEL 10 DVD ISO `rhel-10.0-x86_64-dvd.iso`.

#### Features

- **Automated Installation**: Fully automated installation using Kickstart (ks.cfg)
- **UEFI Boot**: Modern UEFI firmware support
- **SSH Access**: SSH server enabled by default
- **Xen Guest Agent**: Installed and enabled for better XCP-ng integration
- **Secure Defaults**: Root account locked; non-root user with sudo access

#### Template Specifications

| Component | UEFI | UEFI-LVM |
|-----------|------|----------|
| **Firmware** | UEFI | UEFI |
| **vCPUs** | 2 | 2 |
| **Memory** | 4GB | 4GB |
| **Disk Size** | 32GB | 32GB |
| **Partitioning** | Regular | LVM |
| **Default User** | template | template |
| **Password** | rhel10-uefi | rhel10-uefi-lvm |

## Usage

### Prerequisites

1. **Packer**: Install HashiCorp Packer (version compatible with XenServer plugin)
2. **XenServer Plugin**: The templates use the XenServer plugin v0.8.1+ ([GitHub repository](https://github.com/vatesfr/packer-plugin-xenserver/))
3. **XCP-ng/Xenserver**: Access to an XCP-ng or Xenserver host
4. **Network Access**: The build host must reach the XCP-ng host and download ISOs

### Creating a Variables File

Create a variables file to customize your build. You can use environment variables or a `.pkrvars.hcl` file.

#### Method 1: Environment Variables

You can set environment variables directly in your shell, or create a `.env` file with the following content:

```env
PKR_VAR_remote_host="192.168.1.10"
PKR_VAR_remote_username="root"
PKR_VAR_remote_password="your-password"
PKR_VAR_sr_iso_name="ISOs"
PKR_VAR_sr_name="Local storage"
PKR_VAR_network_names='["Pool-wide network associated with eth0"]'
```

Then load them in your shell before running Packer:

```bash
set -a
source .env
set +a
```


#### Method 2: Variables File

Create a file named `debian13.pkrvars.hcl`:

```hcl
# XCP-ng/Xenserver Connection
remote_host     = "192.168.1.10"
remote_username = "root"
remote_password = "your-xenserver-password"

# Storage Configuration
sr_iso_name = "ISOs"  # Storage Repository for ISOs
sr_name     = "Local storage"  # Storage Repository for VM disks

# Network Configuration
network_names = ["Pool-wide network associated with eth0"]

# VM Configuration (optional - will use defaults if not specified)
vm_name        = "debian13-template"
vm_description = "Custom Debian 13 Template"
disk_name      = "debian13-custom-disk"
vm_tags        = ["production", "debian", "template"]
```

#### Variables Reference

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `remote_host` | Yes | XCP-ng/Xenserver pool master IP or FQDN | - |
| `remote_username` | Yes | Username for XCP-ng authentication | - |
| `remote_password` | Yes | Password for XCP-ng authentication | - |
| `sr_iso_name` | Yes | Storage Repository name for ISOs | - |
| `sr_name` | Yes | Storage Repository name for VM disks | - |
| `network_names` | No | List of networks to attach to VM | `["Network associated with eth0"]` |
| `vm_name` | No | Custom VM name | `template-debian13-uefi_timestamp` |
| `vm_description` | No | VM description | Auto-generated with build date |
| `disk_name` | No | Custom disk name | `template-debian13-uefi_disk1` |
| `vm_tags` | No | List of tags to apply to VM | `["packer", "template"]` |

### Building Templates

#### Debian 13 UEFI (Regular Partitioning)

```bash
# Navigate to the template directory
cd packer/distros/debian/13/uefi

# Build with environment variables
packer build debian13-uefi.pkr.hcl

# Build with variables file
packer build -var-file="../../../../debian13.pkrvars.hcl" debian13-uefi.pkr.hcl
```

#### Debian 13 UEFI-LVM

```bash
# Navigate to the template directory
cd packer/distros/debian/13/uefi-lvm

# Build with environment variables
packer build debian13-uefi-lvm.pkr.hcl

# Build with variables file
packer build -var-file="../../../../debian13.pkrvars.hcl" debian13-uefi-lvm.pkr.hcl
```

#### RHEL 10 UEFI (Regular Partitioning)

```bash
# Navigate to the template directory
cd packer/distros/rhel/10/uefi

# Build with environment variables
packer build rhel10-uefi.pkr.hcl

# Build with variables file
packer build -var-file="../../../../rhel10.pkrvars.hcl" rhel10-uefi.pkr.hcl
```

#### RHEL 10 UEFI-LVM

```bash
# Navigate to the template directory
cd packer/distros/rhel/10/uefi-lvm

# Build with environment variables
packer build rhel10-uefi-lvm.pkr.hcl

# Build with variables file
packer build -var-file="../../../../rhel10.pkrvars.hcl" rhel10-uefi-lvm.pkr.hcl
```

### Post-Build

After successful build completion, the behavior depends on the export configuration in the `.pkr.hcl` files:

#### Default Behavior (Templates Stay on Build Host)

By default, templates remain on the build host as templates with the following settings:

```hcl
output_directory     = "export"
keep_vm              = "on_success"
skip_set_template    = false
format               = "none"
export_network_names = ["Pool-wide network associated with eth0"]
```

In this mode:
1. **VM Status**: The VM is kept on the XCP-ng host and converted to a template
2. **Access**: Templates are available directly in XCP-ng/Xenserver for immediate use
3. **No Download**: No files are downloaded to the local machine

#### Download Mode (Export as XVA Files)

If you want to download the templates as compressed XVA files, modify the export settings in the `.pkr.hcl` files:

```hcl
output_directory     = "export"
keep_vm              = "never"
skip_set_template    = true
format               = "xva_compressed"
export_network_names = ["Pool-wide network associated with eth0"]
```

In this mode:
1. **Export Location**: Templates are exported to the `export/` directory as compressed XVA files
2. **Import to XCP-ng**: Import the XVA file into your XCP-ng pool when needed
3. **Template Conversion**: Convert the imported VM to a template in XCP-ng Center or XOA

### Customization

#### Preseed Configuration

The Debian installation is automated using preseed files located in the `http/` directories:
- `packer/distros/debian/13/uefi/http/preseed.cfg` - UEFI variant
- `packer/distros/debian/13/uefi-lvm/http/preseed.cfg` - UEFI-LVM variant

You can modify these files to:
- Change disk partitioning schemes
- Add additional packages
- Modify user accounts
- Configure network settings

#### Kickstart Configuration (RHEL 10)

RHEL installations are automated using kickstart files located in the `http/` directories:
- `packer/distros/rhel/10/uefi/http/ks.cfg` - UEFI variant
- `packer/distros/rhel/10/uefi-lvm/http/ks.cfg` - UEFI-LVM variant

You can modify these files to:
- Switch between regular and LVM partitioning
- Add packages (e.g., cloud-init)
- Adjust user accounts and passwords
- Configure network settings and hostname

#### Template Configuration

Modify the `.pkr.hcl` files to adjust:
- VM resources (CPU, memory, disk)
- Boot commands
- SSH credentials
- Post-installation scripts

### RHEL 10 Variables File Example

Create a file named `rhel10.pkrvars.hcl`:

```hcl
# XCP-ng/Xenserver Connection
remote_host     = "192.168.1.10"
remote_username = "root"
remote_password = "your-xenserver-password"

# Storage Configuration
sr_iso_name = "ISOs"          # Storage Repository for ISOs
sr_name     = "Local storage" # Storage Repository for VM disks

# Network Configuration
network_names = ["Pool-wide network associated with eth0"]

# VM Configuration (optional - will use defaults if not specified)
vm_name        = "rhel10-template"
vm_description = "Custom RHEL 10 Template"
disk_name      = "rhel10-custom-disk"
vm_tags        = ["production", "rhel", "template"]
```

## Troubleshooting

### Common Issues

1. **Connection Timeout**: Verify XCP-ng host accessibility and credentials
2. **ISO Download**: Ensure internet connectivity for Debian ISO download
3. **Storage Repository**: Verify SR names exist and have sufficient space
4. **Network Configuration**: Ensure specified networks exist in XCP-ng

### Build Logs

Packer provides detailed logs. Enable debug logging:

```bash
PACKER_LOG=1 packer build debian13-uefi.pkr.hcl
```

## Security Notes

- Default passwords are used for automation - change them after template creation
- Templates include cloud-init for secure initial configuration
- SSH key injection is recommended over password authentication
- Consider using Vault or environment variables for sensitive credentials

## Contributing

When adding new distributions or variants:
1. Follow the existing directory structure
2. Include appropriate preseed files
3. Update this README with new template documentation
4. Test builds before submitting pull requests