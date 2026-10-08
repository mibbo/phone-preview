#!/bin/bash
# Installs the root-owned parts of phone-preview. Read it before running:
#
#   sudo ./install.sh
#
# Copies (never symlinks) the helpers into /usr/local/sbin owned by root, so
# your user cannot edit what sudo runs without a password.
set -euo pipefail
cd "$(dirname "$0")"

[[ $EUID -eq 0 ]] || { echo "run with sudo: sudo ./install.sh" >&2; exit 1; }
user=${SUDO_USER:?run via sudo from your own account}
[[ $user =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "unexpected user name: $user" >&2; exit 1; }

echo "1/4  Helpers -> /usr/local/sbin (root:root, 0755)"
install -o root -g root -m 0755 sbin/phone-preview-fw sbin/phone-preview-arm /usr/local/sbin/

echo "2/4  Polkit action (fingerprint/password popup for arming)"
install -o root -g root -m 0644 system/local.phone-preview.policy /usr/share/polkit-1/actions/

echo "3/4  Sudoers: $user may run ONLY /usr/local/sbin/phone-preview-fw without a password"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
echo "$user ALL=(root) NOPASSWD: /usr/local/sbin/phone-preview-fw" >"$tmp"
visudo -cqf "$tmp" || { echo "sudoers syntax check failed; nothing installed for sudoers" >&2; exit 1; }
install -o root -g root -m 0440 "$tmp" /etc/sudoers.d/phone-preview

echo "4/4  Boot cleanup service (deletes leftover rules at every boot)"
install -o root -g root -m 0644 system/phone-preview-cleanup.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable phone-preview-cleanup.service

echo
echo "Done. Check with: phone-preview --status"
