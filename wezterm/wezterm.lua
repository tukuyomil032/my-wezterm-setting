local wezterm = require("wezterm")
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

-- Font Config
config.font = wezterm.font("JetBrains Mono", { weight = "Bold" })
config.font_size = 15


-- Key Bindings
config.disable_default_key_bindings = true
config.keys = require ("keybinds").keys
config.key_tables = require ("keybinds").key_tables

-- Window Config
config.window_decorations = "RESIZE"
config.window_background_opacity = 0.75
config.macos_window_background_blur = 10
config.window_background_gradient = {
    colors = { "#000000" },
}

-- Tab Bar Config
config.show_new_tab_button_in_tab_bar = false
config.tab_bar_at_bottom = true
config.tab_max_width = 5
config.show_close_tab_button_in_tabs = false

-- Window Frame Config
config.window_frame = {
    inactive_titlebar_bg = "none",
    active_titlebar_bg = "none",
}

-- Color Config
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

-- Event Handlers
wezterm.on("gui-startup", function()
    local _, _, window = mux.spawn_window({})
    window:gui_window():maximize()
end)

-- Tab Title Format
local SOLID_LEFT_ARROW = wezterm.nerdfonts.pl_right_hard_divider
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.pl_left_hard_divider

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
	local background = "#5c6d74"
	local foreground = "#FFFFFF"
	local edge_background = "none"
 
	if tab.is_active then
	  background = "#9c7af2"
	  foreground = "#FFFFFF"
	end
	
	local edge_foreground = background
	local title = tab.active_pane.title

	-- If the title is too long, truncate it
	local function get_last_n_chars(str, n)
        if #str <= n then
            return str
        else
            return "…" .. string.sub(str, -n + 1)
        end
    end

	-- Get the title based on the process name (e.g., node, make)
    local function get_process_name(pane)
        local process_name = pane.foreground_process_name
	
    	return process_name:match("([^/]+)$") or ""

    end
	
    -- Get the custom title
    local function get_custom_title(pane)
        local process_name = get_process_name(pane)
		
    	-- if process_name == "make" then
		-- wezterm.log_info(process_name)
    	--    return "make"
	 	-- elseif process_name == "node" then
		-- 	return "node"
		if process_name ~= "zsh" then
			return process_name
        else
             return get_last_n_chars(title, 23)
         end

		return process_name
    end

    -- Get the custom title
    local custom_title = get_custom_title(tab.active_pane)
	
	return {
		{ Background = { Color = edge_background } },
		{ Foreground = { Color = edge_foreground } },
		{ Text = SOLID_LEFT_ARROW },
	  { Background = { Color = background } },
	  { Foreground = { Color = foreground } },
	  { Text = " " .. (tab.tab_index + 1) .. ": " .. custom_title .. " " },
	  { Background = { Color = edge_background } },
	  { Foreground = { Color = edge_foreground } },
	  { Text = SOLID_RIGHT_ARROW },
	}
end)

return config

