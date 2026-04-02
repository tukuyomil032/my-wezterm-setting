local wezterm = require("wezterm")

-- Show which key table is active in the status area
wezterm.on("update-right-status", function(window, pane)
  local name = window:active_key_table()
  if name then
    name = "TABLE: " .. name
  end
  window:set_right_status(name or "")
end)

return {
  keys = require("src.keybinds.keys"),
  -- https://wezfurlong.org/wezterm/config/key-tables.html
  key_tables = require("src.keybinds.key_tables"),
}
