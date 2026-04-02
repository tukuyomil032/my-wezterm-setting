# WezTerm Dynamic Background Config

Modular WezTerm configuration for macOS with random media slideshow, adaptive readability overlay, and runtime source switching.

![Platform](https://img.shields.io/badge/platform-macOS-1f6feb)
![WezTerm](https://img.shields.io/badge/wezterm-Lua%20Config-0b7a75)
![Layout](https://img.shields.io/badge/structure-src%20modular-5b21b6)
![Status](https://img.shields.io/badge/status-active-16a34a)

## Features

- random slideshow from media directories (`png`, `jpg`, `jpeg`, `mp4`, `mov`)
- video background playback for `mp4/mov` (play from first frame to last frame)
- adaptive gradient readability layer based on image colors
- runtime source switching from command palette or shell script
- periodic source re-scan for media added after startup
- modular source layout under `src/` for easier maintenance
- fallback flow (`preset -> legacy background-img -> optional fallback image`)

## Table Of Contents

- [Project Layout](#project-layout)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Commands](#commands)
- [Documentation](#documentation)
- [Troubleshooting](#troubleshooting)

## Project Layout

- `wezterm.lua`: compatibility entrypoint (loads `src/wezterm.lua`)
- `keybinds.lua`: compatibility entrypoint (loads `src/keybinds.lua`)
- `background.lua`: compatibility entrypoint (loads `src/background.lua`)
- `src/wezterm.lua`: composition root for wezterm setup
- `src/wezterm/base_config.lua`: static UI/font/color/window settings
- `src/wezterm/tab_title.lua`: tab title formatter event
- `src/wezterm/background_events.lua`: command palette + update-status hooks
- `src/keybinds.lua`: keybind aggregate module
- `src/keybinds/keys.lua`: key mappings
- `src/keybinds/key_tables.lua`: key table definitions
- `src/background.lua`: slideshow and runtime background control API
- `src/background/source_manager.lua`: source selection and file scanning
- `src/background/gradient_manager.lua`: adaptive gradient extraction and blending
- `src/background/video_manager.lua`: `mp4/mov` frame extraction and playback cache
- `src/background/layers.lua`: background layer construction/easing
- `src/background/utils.lua`: shared utility functions
- `scripts/switch-background-preset.sh`: CLI helper for source switching
- `scripts/configure-background-video.sh`: interactive editor for video FPS/quality presets
- `docs/background-animation-research.md`: detailed Japanese guide

## Requirements

- macOS (current setup target)
- WezTerm
- ffmpeg (required for `mp4/mov` playback)
- Optional: ImageMagick (`magick`) for color extraction fallback

## Quick Start

### 1) Prepare source folders

Create image folders under your WezTerm config directory (default: `~/.config/wezterm`).

```bash
mkdir -p ~/.config/wezterm/preset-1
mkdir -p ~/.config/wezterm/preset-2
```

Then place `png/jpg/jpeg/mp4/mov` files in those folders.

### 2) Select active source

Use the helper script:

```bash
~/.config/wezterm/scripts/switch-background-preset.sh preset-1
```

Or set an absolute path:

```bash
~/.config/wezterm/scripts/switch-background-preset.sh /Users/you/Pictures/wallpapers
```

Usage for videos is the same: place `mp4/mov` files in the selected source folder.

### 3) (Optional) Set video FPS/quality interactively

```bash
~/.config/wezterm/scripts/configure-background-video.sh
```

### 4) Reload config (if needed)

- key binding: `Ctrl+Shift+R`
- command palette: `Cmd+P` or `Ctrl+Shift+P`

## Configuration

Main tunables are in `src/background.lua` (`M.settings`).

| Key | Default | Description |
| --- | --- | --- |
| `default_preset` | `preset-1` | default source if selector file does not exist |
| `presets_root_dir` | `wezterm.config_dir` | root directory where `preset-*` folders are discovered |
| `preset_selector_file` | `.wezterm-background-preset` | selector file that stores current source token |
| `legacy_image_dir` | `background-img` | fallback source if selected source has no media |
| `slideshow_interval_seconds` | `18` | hold time before next image |
| `rescan_interval_seconds` | `5` | source rescan interval |
| `tick_interval_ms` | `16` | update tick granularity |
| `transition_duration_ms` | `1800` | fade duration when crossfade is enabled |
| `enable_crossfade` | `false` | immediate switch if false |
| `image_opacity` | `0.22` | image layer opacity |
| `enable_video_playback` | `true` | enable `mp4/mov` playback |
| `video_extract_fps` | `30` | extraction/playback fps for video frames |
| `video_max_width` | `1920` | frame extraction max width (`-2` keeps ratio) |
| `video_cache_dir` | `.video-frame-cache` | extracted frame cache directory |
| `adaptive_gradient` | `true` | enable adaptive gradient |
| `adaptive_tint_strength` | `0.18` | gradient tint intensity |
| `fallback_image` | `nil` | optional file path if no source media is found |

## Commands

### Command Palette (recommended)

Search with `Background:` and use:

- `Background: Use <source>`
- `Background: Enter source name or absolute path`
- `Background: Force source rescan now`

### Script command

```bash
~/.config/wezterm/scripts/switch-background-preset.sh <preset-name|absolute-directory>
```

Examples:

```bash
~/.config/wezterm/scripts/switch-background-preset.sh preset-2
~/.config/wezterm/scripts/switch-background-preset.sh background-img
```

### Interactive video preset command

```bash
~/.config/wezterm/scripts/configure-background-video.sh
```

This script updates `~/.config/wezterm/.wezterm-video-settings` with preset choices:

- FPS: `30` or `60`
- Quality: `Original`, `1440p`, `1080p`, `720p`

## Documentation

- Detailed guide (Japanese): `docs/background-animation-research.md`

## Troubleshooting

- Source not changing:
  - run `Background: Force source rescan now`
  - verify selected source directory exists and has valid media extensions
- mp4/mov is skipped:
  - make sure `ffmpeg` is installed and available in `PATH`
- Colors feel too strong:
  - reduce `adaptive_tint_strength`
  - reduce `image_opacity`
- No media is shown:
  - verify selected source folder path
  - check fallback flow (`preset -> background-img -> fallback_image`)

## Notes

- The root files (`wezterm.lua`, `keybinds.lua`, `background.lua`) are intentionally thin wrappers for compatibility.
- Active implementation is maintained in `src/`.
