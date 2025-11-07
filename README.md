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

## Usage

### Prerequisites

1. **Packer**: Install HashiCorp Packer (version compatible with XenServer plugin)
2. **XenServer Plugin**: The templates use the XenServer plugin v0.8.1+ ([GitHub repository](https://github.com/vatesfr/packer-plugin-xenserver/))
3. **XCP-ng/Xenserver**: Access to an XCP-ng or Xenserver host
4. **Network Access**: The build host must reach the XCP-ng host and download ISOs

### Creating a Variables File

Create a variables file to customize your build. You can use environment variables or a `.pkrvars.hcl` file.

#### Method 1: Environment Variables

```bash
export PKR_VAR_remote_host="192.168.1.10"
export PKR_VAR_remote_username="root"
export PKR_VAR_remote_password="your-password"
export PKR_VAR_sr_iso_name="Local storage"
export PKR_VAR_sr_name="Local storage"
export PKR_VAR_network_names='["Pool-wide network associated with eth0"]'
```

#### Method 2: Variables File

Create a file named `debian13.pkrvars.hcl`:

```hcl
# XCP-ng/Xenserver Connection
remote_host     = "192.168.1.10"
remote_username = "root"
remote_password = "your-xenserver-password"

# Storage Configuration
sr_iso_name = "Local storage"  # Storage Repository for ISOs
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
| `remote_host` | Yes | XCP-ng/Xenserver host IP or FQDN | - |
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

### Post-Build

After successful build completion:

1. **Export Location**: Templates are exported to the `export/` directory as compressed XVA files
2. **Import to XCP-ng**: Import the XVA file into your XCP-ng pool
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

#### Template Configuration

Modify the `.pkr.hcl` files to adjust:
- VM resources (CPU, memory, disk)
- Boot commands
- SSH credentials
- Post-installation scripts

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