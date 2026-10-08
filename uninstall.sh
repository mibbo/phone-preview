#!/bin/bash
# Removes everything install.sh added, after closing any open phone-preview ports.
#
#   sudo ./uninstall.sh
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run with sudo: sudo ./uninstall.sh" >&2; exit 1; }

[[ -x /usr/local/sbin/phone-preview-fw ]] && /usr/local/sbin/phone-preview-fw disarm || true
systemctl disable phone-preview-cleanup.service 2>/dev/null || true
rm -f /etc/systemd/system/phone-preview-cleanup.service \
      /etc/sudoers.d/phone-preview \
      /usr/share/polkit-1/actions/local.phone-preview.policy \
      /usr/local/sbin/phone-preview-fw \
      /usr/local/sbin/phone-preview-arm
systemctl daemon-reload
echo "Uninstalled. Remove ~/.local/bin/phone-preview and the hotkey yourself if you want."
