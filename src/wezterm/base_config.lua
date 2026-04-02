local M = {}

function M.apply(config, wezterm, background, keybinds)
  -- Color
  local purple = '#9c7af2'
  local blue = '#6EADD8'
  local light_green = "#7dcd5d"
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
  config.keys = keybinds.keys
  config.key_tables = keybinds.key_tables

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
end

return M
