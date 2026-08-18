#!/usr/bin/env bash
# ==============================================================================
# Vimoji - Uninstallation Script for Omarchy / Hyprland
# ==============================================================================
set -e

PLUGIN_DIR="${HOME}/.config/omarchy/plugins/zezenta.vimoji"

if [ -d "${PLUGIN_DIR}" ]; then
  echo "==> Removing Vimoji plugin from ${PLUGIN_DIR}..."
  rm -rf "${PLUGIN_DIR}"
  echo "==> Refreshing Omarchy shell plugins..."
  omarchy-shell shell rescanPlugins 2>/dev/null || true
  echo "✓ Vimoji uninstalled successfully."
else
  echo "Vimoji is not installed in ${PLUGIN_DIR}."
fi
