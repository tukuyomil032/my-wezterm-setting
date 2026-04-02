local wezterm = require("wezterm")
local act = wezterm.action

return {
  {
    -- switch workspace
    key = "w",
    mods = "LEADER",
    action = act.ShowLauncherArgs({ flags = "WORKSPACES", title = "Select workspace" }),
  },
  {
    -- rename workspace
    key = "$",
    mods = "LEADER",
    action = act.PromptInputLine({
      description = "(wezterm) Set workspace title:",
      action = wezterm.action_callback(function(win, pane, line)
        if line then
          wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
        end
      end),
    }),
  },
  {
    key = "W",
    mods = "LEADER|SHIFT",
    action = act.PromptInputLine({
      description = "(wezterm) Create new workspace:",
      action = wezterm.action_callback(function(window, pane, line)
        if line then
          window:perform_action(
            act.SwitchToWorkspace({
              name = line,
            }),
            pane
          )
        end
      end),
    }),
  },
  -- Show command palette
  { key = "p", mods = "SUPER", action = act.ActivateCommandPalette },
  -- Switch tab
  { key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
  { key = "Tab", mods = "SHIFT|CTRL", action = act.ActivateTabRelative(-1) },
  -- Move tab
  { key = "{", mods = "LEADER", action = act({ MoveTabRelative = -1 }) },
  -- Create new tab
  { key = "t", mods = "SUPER", action = act({ SpawnTab = "CurrentPaneDomain" }) },
  -- Close tab
  { key = "w", mods = "SUPER", action = act({ CloseCurrentTab = { confirm = true } }) },
  { key = "}", mods = "LEADER", action = act({ MoveTabRelative = 1 }) },

  -- Toggle full screen
  { key = "Enter", mods = "ALT", action = act.ToggleFullScreen },
  -- Alt + backslash: send a literal backslash
  { key = "raw:93", mods = "ALT", action = act.SendString("\\") },

  -- Copy mode
  -- { key = 'X', mods = 'LEADER', action = act.ActivateKeyTable{ name = 'copy_mode', one_shot =false }, },
  { key = "[", mods = "LEADER", action = act.ActivateCopyMode },
  -- Copy
  { key = "c", mods = "SUPER", action = act.CopyTo("Clipboard") },
  -- Paste
  { key = "v", mods = "SUPER", action = act.PasteFrom("Clipboard") },

  -- Create pane leader + r or d
  { key = "d", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "r", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  -- Close pane leader + x
  { key = "x", mods = "LEADER", action = act({ CloseCurrentPane = { confirm = true } }) },
  -- Move pane leader + hlkj
  { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
  { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
  { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
  { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
  -- Select pane
  { key = "[", mods = "CTRL|SHIFT", action = act.PaneSelect },
  -- Show only the selected pane
  { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },

  -- Change font size
  { key = "+", mods = "CTRL", action = act.IncreaseFontSize },
  { key = "-", mods = "CTRL", action = act.DecreaseFontSize },
  -- Reset font size
  { key = "0", mods = "CTRL", action = act.ResetFontSize },

  -- Switch tab Cmd + number
  { key = "1", mods = "SUPER", action = act.ActivateTab(0) },
  { key = "2", mods = "SUPER", action = act.ActivateTab(1) },
  { key = "3", mods = "SUPER", action = act.ActivateTab(2) },
  { key = "4", mods = "SUPER", action = act.ActivateTab(3) },
  { key = "5", mods = "SUPER", action = act.ActivateTab(4) },
  { key = "6", mods = "SUPER", action = act.ActivateTab(5) },
  { key = "7", mods = "SUPER", action = act.ActivateTab(6) },
  { key = "8", mods = "SUPER", action = act.ActivateTab(7) },
  { key = "9", mods = "SUPER", action = act.ActivateTab(-1) },

  -- Show command palette
  { key = "p", mods = "SHIFT|CTRL", action = act.ActivateCommandPalette },
  -- Reload configuration
  { key = "r", mods = "SHIFT|CTRL", action = act.ReloadConfiguration },
  -- For key tables
  { key = "s", mods = "LEADER", action = act.ActivateKeyTable({ name = "resize_pane", one_shot = false }) },
  {
    key = "a",
    mods = "LEADER",
    action = act.ActivateKeyTable({ name = "activate_pane", timeout_milliseconds = 1000 }),
  },
}
