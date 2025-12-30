local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.disable_default_key_bindings = true
config.keys = require ("keybinds").keys
config.key_tables = require ("keybinds").key_tables
config.leader = { key = "q", mods = "CTRL", timeout_milliseconds = 2000 }

config.automatically_reload_config = true
config.font_size = 12.0
config.use_ime = true
config.window_background_opacity = 0.75
config.macos_window_background_blur = 15
config.window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = true
config.show_new_tab_button_in_tab_bar = false
config.show_close_tab_button_in_tabs = false
config.animation_fps = 5
config.cursor_blink_rate = 300
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

config.colors = {
    tab_bar = {
        inactive_tab_edge = "none",
    },
}
local SOLID_LEFT_ARROW = wezterm.nerdfonts.ple_lower_right_triangle
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.ple_upper_left_triangle

config.window_frame = {
    inactive_titlebar_bg = "none",
    active_titlebar_bg = "none",
}
  config.window_background_gradient = {
    orientation = "Vertical",
    colors = {
        "#0f0c29",
        "#38309aff",
        "#24243e",
    },

    interpolation = "Linear",
    blend = "Rgb",
  }

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local background = "#5c6d74"
  local foreground = "#FFFFFF"
    local edge_background = "none"

  if tab.is_active then
    background = "#ae8b2d"
    foreground = "#FFFFFF"
  end
    local edge_foreground = background

  local title = "  ".. wezterm.truncate_right(tab.active_pane.title, max_width - 1).. "  "
    return {
        { Background = { Color = edge_background } },
        { Foreground = { Color = edge_foreground } },
        { Text = SOLID_LEFT_ARROW },
        { Background = { Color = background } },
        { Foreground = { Color = foreground } },
        { Text = title },
        { Background = { Color = edge_background } },
        { Foreground = { Color = edge_foreground } },
        { Text = SOLID_RIGHT_ARROW },
    }
end)

return config