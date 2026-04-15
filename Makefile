.PHONY: help update-xenserver-version clean-xenserver-plugin download-xenserver-plugin sync-xenserver-plugin

# Variables
XENSERVER_VERSION ?= 0.8.1
XENSERVER_PLUGIN_SOURCE := github.com/vatesfr/xenserver
XENSERVER_GITHUB_REPO := vatesfr/xenserver

help:
	@echo "Packer Xenserver Plugin Management"
	@echo "===================================="
	@echo ""
	@echo "Available targets:"
	@echo "  make clean-xenserver-plugin              - Remove installed Xenserver plugin"
	@echo "  make download-xenserver-plugin           - Download and install latest Xenserver plugin"
	@echo "  make update-xenserver-version VERSION=X  - Update pkr.hcl files with specific version"
	@echo "  make sync-xenserver-plugin               - Full sync: remove old, install latest, update all pkr files"
	@echo ""
	@echo "Current Xenserver version in pkr files: $(XENSERVER_VERSION)"

clean-xenserver-plugin:
	@echo "Removing Xenserver plugin..."
	@packer plugins remove $(XENSERVER_PLUGIN_SOURCE) && echo "✓ Plugin removed" || echo "ℹ Plugin not installed"

download-xenserver-plugin: clean-xenserver-plugin
	@echo "Installing latest Xenserver plugin..."
	@packer plugins install -force $(XENSERVER_PLUGIN_SOURCE)

update-xenserver-version:
	@if [ -z "$(XENSERVER_VERSION)" ]; then \
		echo "✗ VERSION not set. Usage: make update-xenserver-version VERSION=0.12"; exit 1; \
	fi
	@echo "Updating Xenserver plugin version to $(XENSERVER_VERSION) in all pkr.hcl files..."
	@find packer/distros -name "*.pkr.hcl" -exec sed -i 's/\s*xcp = {/    xenserver = {/' {} \;
	@find packer/distros -name "*.pkr.hcl" -exec sed -i 's/version = ">= >*[0-9.]*"/version = ">= $(XENSERVER_VERSION)"/' {} \;
	@find packer/distros -name "*.pkr.hcl" -exec sed -i 's|source  = "github.com/disruptivemindseu/xcp"|source  = "github.com/vatesfr/xenserver"|g' {} \;
	@find packer/distros -name "*.pkr.hcl" -exec sed -i 's/source "xcp-iso"/source "xenserver-iso"/' {} \;
	@find packer/distros -name "*.pkr.hcl" -exec sed -i 's/xcp-iso\.template/xenserver-iso.template/' {} \;
	@echo "✓ pkr files updated with version $(XENSERVER_VERSION)"

sync-xenserver-plugin: download-xenserver-plugin
	@echo "Detecting installed version..."
	@INSTALLED_VERSION=$$(ls -1 ~/.config/packer/plugins/$(XENSERVER_PLUGIN_SOURCE)/ 2>/dev/null | grep -oP 'packer-plugin-xenserver_v\K[^_]*' | head -1); \
	if [ -z "$$INSTALLED_VERSION" ]; then \
		echo "✗ Failed to detect installed version"; exit 1; \
	fi; \
	echo "✓ Installed version: $$INSTALLED_VERSION"; \
	$(MAKE) update-xenserver-version XENSERVER_VERSION=$$INSTALLED_VERSION; \
	echo "✓ Sync complete!"
