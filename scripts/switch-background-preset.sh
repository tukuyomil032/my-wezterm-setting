#!/usr/bin/env bash

set -euo pipefail

CONFIG_DIR="${WEZTERM_CONFIG_DIR:-$HOME/.config/wezterm}"
SELECTOR_FILE="$CONFIG_DIR/.wezterm-background-preset"

usage() {
  cat <<'EOF'
Usage:
  switch-background-preset.sh [<preset-name|absolute-directory>]

  If no argument is provided, interactive mode is activated.

Examples:
  switch-background-preset.sh                # Interactive mode
  switch-background-preset.sh preset-1       # Direct mode
  switch-background-preset.sh preset-2
  switch-background-preset.sh background-img
  switch-background-preset.sh /Users/you/Pictures/wallpapers/anime
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# Interactive mode when no argument is provided
if [[ $# -eq 0 ]]; then
  echo "=== WezTerm Background Preset Selector ==="
  echo ""
  
  # Find all preset-* directories
  PRESETS=()
  while IFS= read -r -d '' preset_dir; do
    preset_name=$(basename "$preset_dir")
    PRESETS+=("$preset_name")
  done < <(find "$CONFIG_DIR" -maxdepth 1 -type d -name "preset-*" -print0 | sort -z)
  
  # Also add background-img if it exists
  if [[ -d "$CONFIG_DIR/background-img" ]]; then
    PRESETS+=("background-img")
  fi
  
  if [[ ${#PRESETS[@]} -eq 0 ]]; then
    echo "Error: No preset directories found (preset-* or background-img)" >&2
    echo "Hint: Create preset directories first (e.g., preset-1, preset-2)" >&2
    exit 1
  fi
  
  # Display available presets
  echo "Available presets:"
  for i in "${!PRESETS[@]}"; do
    printf "  %d) %s\n" $((i + 1)) "${PRESETS[$i]}"
  done
  echo ""
  
  # Read user selection
  read -rp "Select preset number (1-${#PRESETS[@]}): " selection
  
  # Validate selection
  if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid input. Please enter a number." >&2
    exit 1
  fi
  
  if [[ $selection -lt 1 || $selection -gt ${#PRESETS[@]} ]]; then
    echo "Error: Selection out of range. Please enter a number between 1 and ${#PRESETS[@]}." >&2
    exit 1
  fi
  
  # Get selected preset
  TARGET_INPUT="${PRESETS[$((selection - 1))]}"
  TARGET_DIR="$CONFIG_DIR/$TARGET_INPUT"
  TARGET_TOKEN="$TARGET_INPUT"
  
  echo ""
else
  # Direct mode with argument
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
fi

printf '%s\n' "$TARGET_TOKEN" > "$SELECTOR_FILE"
echo "✓ Background preset switched to: $TARGET_TOKEN"
echo "✓ Selector file updated: $SELECTOR_FILE"
echo ""
echo "Hint: Reload WezTerm configuration to apply changes."
