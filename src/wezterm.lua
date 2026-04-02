local wezterm = require("wezterm")
local act = wezterm.action
local background = require("src.background")
local keybinds = require("src.keybinds")
local base_config = require("src.wezterm.base_config")
local tab_title = require("src.wezterm.tab_title")
local background_events = require("src.wezterm.background_events")

local config = wezterm.config_builder()

base_config.apply(config, wezterm, background, keybinds)
tab_title.register(wezterm)
background_events.register(wezterm, act, background)

return config
