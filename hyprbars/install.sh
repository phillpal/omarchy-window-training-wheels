#!/bin/bash
# One-shot setup for the optional Windows-style titlebar (hyprbars).
#
# Run AFTER installing the shell plugin:
#   omarchy plugin add https://github.com/phillpal/omarchy-window-training-wheels.git --enable
#   bash ~/.config/omarchy/plugins/teknobu.minimize/hyprbars/install.sh
#
# This installs the hyprbars Hyprland plugin (needs sudo for the AUR build),
# drops in the titlebar config, and wires the SUPER+H / SUPER+W keybindings.
# It is idempotent — safe to re-run.

set -euo pipefail

HYPR_CFG="$HOME/.config/hypr"
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== teknobu.minimize titlebar setup =="

# 1. hyprbars Hyprland plugin (compiled C++, version-locked to Hyprland).
if [[ ! -f /usr/lib/libhyprbars.so ]]; then
  echo "→ Installing hyprland-plugin-hyprbars (AUR build may prompt for sudo)..."
  omarchy pkg aur add hyprland-plugin-hyprbars
else
  echo "✓ hyprbars already installed"
fi

mkdir -p "$HYPR_CFG"

# 2. Titlebar config (back up any existing one first).
if [[ -f "$HYPR_CFG/hyprbars.lua" ]] && ! grep -q "teknobu.minimize" "$HYPR_CFG/hyprbars.lua"; then
  cp "$HYPR_CFG/hyprbars.lua" "$HYPR_CFG/hyprbars.lua.bak.$(date +%s)"
  echo "✓ backed up existing hyprbars.lua"
fi
cp "$THIS_DIR/hyprbars.lua" "$HYPR_CFG/hyprbars.lua"
echo "✓ hyprbars.lua → $HYPR_CFG/hyprbars.lua"

# 3. Ensure the titlebar module is required by hyprland.lua.
if [[ ! -f "$HYPR_CFG/hyprland.lua" ]]; then
  echo "⚠ $HYPR_CFG/hyprland.lua not found — is this an Omarchy install?" >&2
  exit 1
fi
if ! grep -q 'require("hypr.hyprbars")' "$HYPR_CFG/hyprland.lua"; then
  printf '\nrequire("hypr.hyprbars")\n' >> "$HYPR_CFG/hyprland.lua"
  echo "✓ added require(\"hypr.hyprbars\") to hyprland.lua"
else
  echo "✓ hyprland.lua already requires hypr.hyprbars"
fi

# 4. Keybindings (minimise + close confirmation).
if grep -q 'prompt-close-active' "$HYPR_CFG/bindings.lua" 2>/dev/null; then
  echo "✓ bindings already present"
else
  cat >> "$HYPR_CFG/bindings.lua" <<'EOF'

-- teknobu.minimize: minimise/restore + close confirmation.
o.bind("SUPER + H", "Minimize window", "python3 $HOME/.config/omarchy/plugins/teknobu.minimize/scripts/minimize.py toggle-active")
hl.unbind("SUPER + W")
o.bind("SUPER + W", "Close window (confirm)", "python3 $HOME/.config/omarchy/plugins/teknobu.minimize/scripts/minimize.py prompt-close-active")
EOF
  echo "✓ added SUPER+H (minimise) and SUPER+W (close with confirmation)"
fi

# 5. Reload Hyprland and check for config errors.
hyprctl reload
if hyprctl configerrors 2>/dev/null | grep -q .; then
  echo "⚠ Hyprland reported config errors — run 'hyprctl configerrors' to inspect."
  exit 1
fi
echo "✓ Hyprland reloaded, no config errors."
echo "Done — titlebar buttons and keybindings are live."
