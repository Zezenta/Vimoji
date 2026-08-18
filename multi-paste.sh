#!/bin/bash
emoji="$1"
target_addr="$2"

[[ -n "$emoji" ]] || exit 0

# Copy to clipboard
printf '%s' "$emoji" | wl-copy --type text/plain --sensitive

# If target_addr not provided, find it live
if [[ -z "$target_addr" || "$target_addr" == "null" ]]; then
  target_addr=$(hyprctl activewindow -j 2>/dev/null | grep -o '"address": "[^"]*"' | head -1 | cut -d'"' -f4)
fi

if [[ -n "$target_addr" && "$target_addr" != "null" ]]; then
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$target_addr\" })" >/dev/null 2>&1
  sleep 0.04
  wtype "$emoji" 2>/dev/null || true
else
  wtype "$emoji" 2>/dev/null || true
fi
