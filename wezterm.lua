local wezterm = require("wezterm")
local background = require "background"
local config = wezterm.config_builder()
local act = wezterm.action
local mux = wezterm.mux

-- Color
local purple = '#9c7af2'
local blue = '#6EADD8'
local light_green = "#7dcd5d"
local orange = "#e19500"
local red = "#E50000"
local yellow = "#D7650C"

-- General
config.automatically_reload_config = true
config.window_close_confirmation = "NeverPrompt"
config.default_cursor_style = "BlinkingBar"

-- Font
config.font = wezterm.font("JetBrains Mono", { weight = "Bold" })
config.font_size = 15

-- Key Bindings
config.disable_default_key_bindings = true
config.keys = require("keybinds").keys
config.key_tables = require("keybinds").key_tables

config.background = background.get_initial_background()
config.status_update_interval = background.settings.tick_interval_ms or 1000

-- Keep global opacity/blur disabled because layering is controlled in background.lua.
config.window_background_opacity = 1.0
config.macos_window_background_blur = 0
config.window_background_gradient = nil

-- Window
config.window_decorations = "RESIZE"

-- Tab Bar
config.show_new_tab_button_in_tab_bar = false
config.tab_bar_at_bottom = true
config.tab_max_width = 5
config.show_close_tab_button_in_tabs = false

-- Window Frame
config.window_frame = {
  inactive_titlebar_bg = "none",
  active_titlebar_bg = "none",
}

-- Colors
config.colors = {
  foreground = 'silver',
  selection_fg = 'red',
  cursor_bg = blue,
  cursor_fg = "white",
  cursor_border = purple,
  tab_bar = {
    inactive_tab_edge = "none",
  },
  ansi = {
    'black', red, purple, light_green, blue, yellow, 'teal', 'silver',
  },
  brights = {
    'grey', 'red', 'lime', 'yellow', 'blue', 'fuchsia', 'aqua', 'white',
  },
}

-- Tab Title Format
local SOLID_LEFT_ARROW = wezterm.nerdfonts.pl_right_hard_divider
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.pl_left_hard_divider

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local foreground = "#FFFFFF"
  local edge_background = "none"
  local bg = "#000000"

  if tab.is_active then
    bg = "#9c7af2"
  end

  local edge_foreground = bg
  local title = tab.active_pane.title

  local function get_last_n_chars(str, n)
    if #str <= n then
      return str
    else
      return "…" .. string.sub(str, -n + 1)
    end
  end

  local function get_process_name(pane)
    local process_name = pane.foreground_process_name
    return process_name:match("([^/]+)$") or ""
  end

  local function get_custom_title(pane)
    local process_name = get_process_name(pane)
    if process_name ~= "zsh" then
      return process_name
    else
      return get_last_n_chars(title, 23)
    end
  end

  local custom_title = get_custom_title(tab.active_pane)

  return {
    { Background = { Color = edge_background } },
    { Foreground = { Color = edge_foreground } },
    { Text = SOLID_LEFT_ARROW },
    { Background = { Color = bg } },
    { Foreground = { Color = foreground } },
    { Text = " " .. (tab.tab_index + 1) .. ": " .. custom_title .. " " },
    { Background = { Color = edge_background } },
    { Foreground = { Color = edge_foreground } },
    { Text = SOLID_RIGHT_ARROW },
  }
end)

wezterm.on("update-status", function(window, pane)
  background.tick(window)
end)

return config
