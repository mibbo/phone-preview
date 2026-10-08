#!/bin/bash
# Installs the user-side parts of phone-preview (no sudo needed):
#   - ~/.local/bin/phone-preview -> this repo's bin/phone-preview
#   - the Super+Shift+Ctrl+P arm/disarm hotkey in ~/.config/hypr/bindings.lua
#
#   ./install-user.sh
set -euo pipefail
repo=$(cd "$(dirname "$0")" && pwd)
bindings=$HOME/.config/hypr/bindings.lua

[[ $EUID -ne 0 ]] || { echo "run as yourself, not with sudo" >&2; exit 1; }

echo "1/3  Command: ~/.local/bin/phone-preview"
mkdir -p "$HOME/.local/bin"
ln -sfn "$repo/bin/phone-preview" "$HOME/.local/bin/phone-preview"

echo "2/3  Hotkey: Super+Shift+Ctrl+P"
if [[ ! -f $bindings ]]; then
  echo "     $bindings not found (not Omarchy?); skipped. Bind 'phone-preview --toggle' yourself."
elif grep -q 'phone-preview --toggle' "$bindings"; then
  echo "     already in $bindings"
else
  cp "$bindings" "$bindings.bak.$(date +%s)"
  cat >>"$bindings" <<'EOF'

-- Phone preview: arm (fingerprint) / disarm opening dev servers to the phone
-- on the same Wi-Fi, until reboot. See the phone-preview repo README.
o.bind("SUPER + SHIFT + CTRL + P", "Phone preview arm/disarm",
  os.getenv("HOME") .. "/.local/bin/phone-preview --toggle")
EOF
  hyprctl reload >/dev/null 2>&1 && hyprctl configerrors || true
  echo "     added (backup saved next to it)"
fi

echo "3/3  Dependencies"
missing=()
for c in ufw python3 qrencode notify-send pkexec systemd-run; do
  command -v "$c" >/dev/null || missing+=("$c")
done
if (( ${#missing[@]} )); then
  echo "     missing: ${missing[*]} (qrencode: omarchy pkg add qrencode)"
else
  echo "     all present"
fi

[[ -x /usr/local/sbin/phone-preview-fw ]] || echo -e "\nNext: sudo ./install.sh   (root parts; read it first)"
