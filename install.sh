#!/usr/bin/env bash
# ==============================================================================
# Vimoji - Installation Script for Omarchy / Hyprland
# ==============================================================================
set -e

PLUGIN_DIR="${HOME}/.config/omarchy/plugins/zezenta.vimoji"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing Vimoji plugin to ${PLUGIN_DIR}..."
mkdir -p "${PLUGIN_DIR}"

cp -f "${SCRIPT_DIR}/manifest.json" "${PLUGIN_DIR}/"
cp -f "${SCRIPT_DIR}/Emojis.qml" "${PLUGIN_DIR}/"
cp -f "${SCRIPT_DIR}/EmojiData.js" "${PLUGIN_DIR}/"
cp -f "${SCRIPT_DIR}/multi-paste.sh" "${PLUGIN_DIR}/"
chmod +x "${PLUGIN_DIR}/multi-paste.sh"

echo "==> Refreshing Omarchy shell plugins..."
omarchy-shell shell rescanPlugins 2>/dev/null || true

echo ""
echo "✨ Vimoji installed successfully!"
echo "To bind Vimoji to SUPER + . in ~/.config/hypr/bindings.conf:"
echo '  bindd = SUPER, period, Emoji picker, exec, omarchy-shell shell toggle zezenta.vimoji'
echo ""
