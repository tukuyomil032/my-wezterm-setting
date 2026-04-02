#!/usr/bin/env bash

set -euo pipefail

CONFIG_DIR="${WEZTERM_CONFIG_DIR:-$HOME/.config/wezterm}"
SETTINGS_FILE="$CONFIG_DIR/.wezterm-video-settings"

DEFAULT_FPS=30
DEFAULT_MAX_WIDTH=1920

print_help() {
  cat <<'EOF'
Interactive video settings editor for WezTerm background playback.

This script updates:
  ~/.config/wezterm/.wezterm-video-settings

It lets you choose:
  - FPS preset (30 or 60)
  - quality preset (Original / 1440p / 1080p / 720p)
EOF
}

quality_label() {
  case "$1" in
    0) echo "Original (no resize)" ;;
    2560) echo "1440p" ;;
    1920) echo "1080p" ;;
    1280) echo "720p" ;;
    *) echo "${1}px" ;;
  esac
}

current_fps="$DEFAULT_FPS"
current_max_width="$DEFAULT_MAX_WIDTH"

if [[ -f "$SETTINGS_FILE" ]]; then
  while IFS='=' read -r raw_key raw_value; do
    key="$(echo "$raw_key" | tr -d '[:space:]')"
    value="$(echo "$raw_value" | tr -d '[:space:]')"

    case "$key" in
      video_extract_fps)
        if [[ "$value" == "30" || "$value" == "60" ]]; then
          current_fps="$value"
        fi
        ;;
      video_max_width)
        if [[ "$value" =~ ^[0-9]+$ ]]; then
          current_max_width="$value"
        fi
        ;;
    esac
  done < "$SETTINGS_FILE"
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_help
  exit 0
fi

echo "Current video settings"
echo "- FPS: $current_fps"
echo "- Quality: $(quality_label "$current_max_width")"
echo

choose_fps() {
  while true; do
    echo "Select FPS preset:"
    echo "  [A] 30 FPS (balanced)"
    echo "  [B] 60 FPS (smooth)"
    read -r -n1 -p "Choose A/B: " fps_choice
    echo

    case "${fps_choice^^}" in
      A) echo "30"; return ;;
      B) echo "60"; return ;;
      *) echo "Invalid choice. Please press A or B." ;;
    esac
    echo
  done
}

choose_quality() {
  while true; do
    echo "Select quality preset:"
    echo "  [A] Original (no resize)"
    echo "  [B] 1440p"
    echo "  [C] 1080p"
    echo "  [D] 720p"
    read -r -n1 -p "Choose A/B/C/D: " quality_choice
    echo

    case "${quality_choice^^}" in
      A) echo "0"; return ;;
      B) echo "2560"; return ;;
      C) echo "1920"; return ;;
      D) echo "1280"; return ;;
      *) echo "Invalid choice. Please press A, B, C, or D." ;;
    esac
    echo
  done
}

next_fps="$(choose_fps)"
echo
next_max_width="$(choose_quality)"
echo

echo "New video settings"
echo "- FPS: $next_fps"
echo "- Quality: $(quality_label "$next_max_width")"
echo

while true; do
  read -r -n1 -p "Save these settings? [Y/N]: " confirm_choice
  echo
  case "${confirm_choice^^}" in
    Y)
      mkdir -p "$CONFIG_DIR"
      cat > "$SETTINGS_FILE" <<EOF
video_extract_fps=$next_fps
video_max_width=$next_max_width
EOF
      echo "Saved: $SETTINGS_FILE"
      echo "Apply now: open command palette and run 'Background: Force source rescan now'"
      echo "Or reload config with Ctrl+Shift+R."
      exit 0
      ;;
    N)
      echo "Canceled. No changes were written."
      exit 0
      ;;
    *)
      echo "Invalid choice. Please press Y or N."
      ;;
  esac
done
