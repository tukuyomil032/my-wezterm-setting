local utils = require("src.background.utils")

local M = {}

local IMAGE_EXTENSIONS = {
  png = true,
  jpg = true,
  jpeg = true,
}

local VIDEO_EXTENSIONS = {
  mp4 = true,
  mov = true,
}

function M.new(wezterm, settings)
  local self = {
    media_items = {},
    media_item_lookup = {},
    last_scan_epoch = 0,
    warned_no_media = false,
    active_source_name = "",
    active_media_dir = "",
    active_source_label = "",
  }

  local function read_selected_source()
    local selector_path = settings.preset_selector_file
    if not utils.file_exists(selector_path) then
      return settings.default_preset
    end

    local handle = io.open(selector_path, "r")
    if not handle then
      return settings.default_preset
    end

    local line = utils.trim(handle:read("*l"))
    handle:close()

    if line == "" then
      return settings.default_preset
    end

    return line
  end

  local function resolve_source_path(source_name)
    local normalized = utils.trim(source_name)
    if normalized:sub(1, 1) == "/" then
      return normalized, normalized
    end

    return normalized, settings.presets_root_dir .. "/" .. normalized
  end

  local function collect_named_presets()
    local command = "find "
      .. utils.shell_quote(settings.presets_root_dir)
      .. " -maxdepth 1 -mindepth 1 -type d -name 'preset-*' -print 2>/dev/null"

    local pipe = io.popen(command)
    local names = {}
    local seen = {}

    if not pipe then
      return names
    end

    for entry in pipe:lines() do
      local name = utils.basename(utils.trim(entry))
      if name ~= "" and not seen[name] then
        seen[name] = true
        table.insert(names, name)
      end
    end

    pipe:close()
    table.sort(names)
    return names
  end

  local function classify_media(path)
    local ext = path:match("%.([^.]+)$")
    if not ext then
      return nil
    end

    local lower_ext = ext:lower()
    if IMAGE_EXTENSIONS[lower_ext] then
      return {
        kind = "image",
        path = path,
        key = "image:" .. path,
      }
    end

    if settings.enable_video_playback and VIDEO_EXTENSIONS[lower_ext] then
      return {
        kind = "video",
        path = path,
        key = "video:" .. path,
      }
    end

    return nil
  end

  local function collect_media_items(media_dir)
    local items = {}
    if not media_dir or media_dir == "" then
      return items
    end

    local command = "find "
      .. utils.shell_quote(media_dir)
      .. " -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.mp4' -o -iname '*.mov' \\) -print 2>/dev/null"

    local pipe = io.popen(command)
    local seen = {}

    if not pipe then
      wezterm.log_warn("Failed to scan media directory: " .. media_dir)
      return items
    end

    for file in pipe:lines() do
      local normalized = utils.trim(file)
      local media = classify_media(normalized)
      if media and not seen[media.key] then
        seen[media.key] = true
        table.insert(items, media)
      end
    end

    pipe:close()
    table.sort(items, function(a, b)
      return a.path < b.path
    end)
    return items
  end

  local function rebuild_media_lookup(items)
    self.media_item_lookup = {}
    for _, item in ipairs(items) do
      self.media_item_lookup[item.key] = true
    end
  end

  function self:list_available_sources()
    local sources = collect_named_presets()
    local seen = {}
    local merged = {}

    local function add_source(name)
      if name and name ~= "" and not seen[name] then
        seen[name] = true
        table.insert(merged, name)
      end
    end

    for _, source in ipairs(sources) do
      add_source(source)
    end

    add_source(settings.default_preset)

    local selected = read_selected_source()
    add_source(selected)

    if utils.directory_exists(settings.legacy_image_dir) then
      add_source(utils.basename(settings.legacy_image_dir))
    end

    table.sort(merged)
    return merged
  end

  function self:set_selected_source(source_name)
    local normalized = utils.trim(source_name)
    if normalized == "" then
      return false, "Preset name is empty"
    end

    local _, source_path = resolve_source_path(normalized)
    if not utils.directory_exists(source_path) then
      return false, "Directory not found: " .. source_path
    end

    local handle, err = io.open(settings.preset_selector_file, "w")
    if not handle then
      return false, err or "Failed to open selector file"
    end

    handle:write(normalized, "\n")
    handle:close()

    self.last_scan_epoch = 0
    self:refresh(true)

    return true, nil
  end

  function self:refresh(force)
    local now = os.time()
    if not force and (now - self.last_scan_epoch) < settings.rescan_interval_seconds then
      return false
    end

    local requested_source = read_selected_source()
    local source_label, source_dir = resolve_source_path(requested_source)
    local items = collect_media_items(source_dir)

    local resolved_label = source_label
    local resolved_dir = source_dir

    if #items == 0 and settings.legacy_image_dir and settings.legacy_image_dir ~= source_dir then
      local legacy_items = collect_media_items(settings.legacy_image_dir)
      if #legacy_items > 0 then
        items = legacy_items
        resolved_label = "legacy:background-img"
        resolved_dir = settings.legacy_image_dir
      end
    end

    if #items == 0 and utils.file_exists(settings.fallback_image) then
      table.insert(items, {
        kind = "image",
        path = settings.fallback_image,
        key = "image:" .. settings.fallback_image,
      })
    end

    local source_changed = (resolved_dir ~= self.active_media_dir) or (requested_source ~= self.active_source_name)

    self.active_source_name = requested_source
    self.active_source_label = resolved_label
    self.active_media_dir = resolved_dir
    self.media_items = items
    rebuild_media_lookup(self.media_items)
    self.last_scan_epoch = now

    if source_changed then
      wezterm.log_info("Background source switched to: " .. self.active_source_label)
    end

    if #self.media_items == 0 and not self.warned_no_media then
      self.warned_no_media = true
      wezterm.log_warn("No background media found in source: " .. self.active_source_label)
    elseif #self.media_items > 0 then
      self.warned_no_media = false
    end

    return source_changed
  end

  function self:pick_random_item(previous)
    self:refresh(false)

    if #self.media_items == 0 then
      return nil
    end

    local previous_key = nil
    if type(previous) == "table" then
      previous_key = previous.key
    elseif type(previous) == "string" then
      previous_key = previous
    end

    if #self.media_items == 1 then
      return self.media_items[1]
    end

    local picked = self.media_items[math.random(#self.media_items)]
    while picked.key == previous_key do
      picked = self.media_items[math.random(#self.media_items)]
    end

    return picked
  end

  function self:contains_item(item)
    if not item then
      return false
    end

    local key = item
    if type(item) == "table" then
      key = item.key
    end

    return self.media_item_lookup[key] == true
  end

  function self:item_count()
    return #self.media_items
  end

  self:refresh(true)

  return self
end

return M
