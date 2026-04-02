#!/usr/bin/env bash

set -euo pipefail

CONFIG_DIR="${WEZTERM_CONFIG_DIR:-$HOME/.config/wezterm}"
SELECTOR_FILE="$CONFIG_DIR/.wezterm-background-preset"

usage() {
  cat <<'EOF'
Usage:
  switch-background-preset.sh <preset-name|absolute-directory>

Examples:
  switch-background-preset.sh preset-1
  switch-background-preset.sh preset-2
  switch-background-preset.sh background-img
  switch-background-preset.sh /Users/you/Pictures/wallpapers/anime
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

TARGET_INPUT="$1"

if [[ "$TARGET_INPUT" = /* ]]; then
  TARGET_DIR="$TARGET_INPUT"
  TARGET_TOKEN="$TARGET_INPUT"
else
  TARGET_DIR="$CONFIG_DIR/$TARGET_INPUT"
  TARGET_TOKEN="$TARGET_INPUT"
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: directory not found: $TARGET_DIR" >&2
  echo "Hint: create the folder first, then run this command again." >&2
  exit 1
fi

printf '%s\n' "$TARGET_TOKEN" > "$SELECTOR_FILE"
echo "Background preset switched to: $TARGET_TOKEN"
echo "Selector file updated: $SELECTOR_FILE"
