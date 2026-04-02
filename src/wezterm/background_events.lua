local M = {}

local function trim_text(value)
  if not value then
    return ""
  end
  return (tostring(value):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function notify_background(window, message)
  window:toast_notification("Background", message, nil, 3200)
end

local function switch_background_source(window, background, source_name)
  local normalized = trim_text(source_name)
  if normalized == "" then
    notify_background(window, "Source name is empty")
    return
  end

  local ok, err = background.set_selected_source(normalized)
  if not ok then
    notify_background(window, "Switch failed: " .. (err or "unknown error"))
    return
  end

  background.tick(window)
  notify_background(window, "Switched source: " .. normalized)
end

function M.register(wezterm, act, background)
  wezterm.on("augment-command-palette", function(window, pane)
    local commands = {
      {
        brief = "Background: Enter source name or absolute path",
        action = act.PromptInputLine({
          description = "Background source (preset-1 or /absolute/path)",
          action = wezterm.action_callback(function(win, _, line)
            local input = trim_text(line)
            if input == "" then
              notify_background(win, "No source entered")
              return
            end
            switch_background_source(win, background, input)
          end),
        }),
      },
      {
        brief = "Background: Force source rescan now",
        action = wezterm.action_callback(function(win, _)
          background.force_rescan()
          background.tick(win)
          notify_background(win, "Background source rescan completed")
        end),
      },
    }

    for _, source in ipairs(background.list_available_sources()) do
      local source_name = source
      table.insert(commands, {
        brief = "Background: Use " .. source_name,
        action = wezterm.action_callback(function(win, _)
          switch_background_source(win, background, source_name)
        end),
      })
    end

    return commands
  end)

  wezterm.on("update-status", function(window, pane)
    background.tick(window)
  end)
end

return M
