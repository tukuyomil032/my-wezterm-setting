local M = {}

function M.register(wezterm)
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
end

return M
