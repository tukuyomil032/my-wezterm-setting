# WezTerm Dynamic Background Config

Modular WezTerm configuration for macOS with random wallpaper slideshow, adaptive readability overlay, and runtime source switching.

![Platform](https://img.shields.io/badge/platform-macOS-1f6feb)
![WezTerm](https://img.shields.io/badge/wezterm-Lua%20Config-0b7a75)
![Layout](https://img.shields.io/badge/structure-src%20modular-5b21b6)
![Status](https://img.shields.io/badge/status-active-16a34a)

## Features

- random slideshow from image directories (`png`, `jpg`, `jpeg`)
- adaptive gradient readability layer based on image colors
- runtime source switching from command palette or shell script
- periodic source re-scan for images added after startup
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
- `src/background/layers.lua`: background layer construction/easing
- `src/background/utils.lua`: shared utility functions
- `scripts/switch-background-preset.sh`: CLI helper for source switching
- `docs/background-animation-research.md`: detailed Japanese guide

## Requirements

- macOS (current setup target)
- WezTerm
- Optional: ImageMagick (`magick`) for color extraction fallback

## Quick Start

### 1) Prepare source folders

Create image folders under your WezTerm config directory (default: `~/.config/wezterm`).

```bash
mkdir -p ~/.config/wezterm/preset-1
mkdir -p ~/.config/wezterm/preset-2
```

Then place `png/jpg/jpeg` files in those folders.

### 2) Select active source

Use the helper script:

```bash
~/.config/wezterm/scripts/switch-background-preset.sh preset-1
```

Or set an absolute path:

```bash
~/.config/wezterm/scripts/switch-background-preset.sh /Users/you/Pictures/wallpapers
```

### 3) Reload config (if needed)

- key binding: `Ctrl+Shift+R`
- command palette: `Cmd+P` or `Ctrl+Shift+P`

## Configuration

Main tunables are in `src/background.lua` (`M.settings`).

| Key | Default | Description |
| --- | --- | --- |
| `default_preset` | `preset-1` | default source if selector file does not exist |
| `presets_root_dir` | `wezterm.config_dir` | root directory where `preset-*` folders are discovered |
| `preset_selector_file` | `.wezterm-background-preset` | selector file that stores current source token |
| `legacy_image_dir` | `background-img` | fallback source if selected source has no images |
| `slideshow_interval_seconds` | `18` | hold time before next image |
| `rescan_interval_seconds` | `5` | source rescan interval |
| `tick_interval_ms` | `16` | update tick granularity |
| `transition_duration_ms` | `1800` | fade duration when crossfade is enabled |
| `enable_crossfade` | `false` | immediate switch if false |
| `image_opacity` | `0.22` | image layer opacity |
| `adaptive_gradient` | `true` | enable adaptive gradient |
| `adaptive_tint_strength` | `0.18` | gradient tint intensity |
| `fallback_image` | `nil` | optional file path if no source images are found |

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

## Documentation

- Detailed guide (Japanese): `docs/background-animation-research.md`

## Troubleshooting

- Source not changing:
  - run `Background: Force source rescan now`
  - verify selected source directory exists and has valid image extensions
- Colors feel too strong:
  - reduce `adaptive_tint_strength`
  - reduce `image_opacity`
- No images are shown:
  - verify selected source folder path
  - check fallback flow (`preset -> background-img -> fallback_image`)

## Notes

- The root files (`wezterm.lua`, `keybinds.lua`, `background.lua`) are intentionally thin wrappers for compatibility.
- Active implementation is maintained in `src/`.
