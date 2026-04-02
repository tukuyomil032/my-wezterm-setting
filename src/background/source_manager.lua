local utils = require("src.background.utils")

local M = {}

function M.new(wezterm, settings)
  local self = {
    image_files = {},
    image_file_lookup = {},
    last_scan_epoch = 0,
    warned_no_images = false,
    active_source_name = "",
    active_image_dir = "",
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

  local function collect_image_files(image_dir)
    local files = {}
    if not image_dir or image_dir == "" then
      return files
    end

    local command = "find "
      .. utils.shell_quote(image_dir)
      .. " -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \\) -print 2>/dev/null"

    local pipe = io.popen(command)
    local seen = {}

    if not pipe then
      wezterm.log_warn("Failed to scan image directory: " .. image_dir)
      return files
    end

    for file in pipe:lines() do
      local normalized = utils.trim(file)
      if normalized ~= "" and not seen[normalized] then
        seen[normalized] = true
        table.insert(files, normalized)
      end
    end

    pipe:close()
    table.sort(files)
    return files
  end

  local function rebuild_image_lookup(files)
    self.image_file_lookup = {}
    for _, file in ipairs(files) do
      self.image_file_lookup[file] = true
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
    local files = collect_image_files(source_dir)

    local resolved_label = source_label
    local resolved_dir = source_dir

    if #files == 0 and settings.legacy_image_dir and settings.legacy_image_dir ~= source_dir then
      local legacy_files = collect_image_files(settings.legacy_image_dir)
      if #legacy_files > 0 then
        files = legacy_files
        resolved_label = "legacy:background-img"
        resolved_dir = settings.legacy_image_dir
      end
    end

    if #files == 0 and utils.file_exists(settings.fallback_image) then
      table.insert(files, settings.fallback_image)
    end

    local source_changed = (resolved_dir ~= self.active_image_dir) or (requested_source ~= self.active_source_name)

    self.active_source_name = requested_source
    self.active_source_label = resolved_label
    self.active_image_dir = resolved_dir
    self.image_files = files
    rebuild_image_lookup(self.image_files)
    self.last_scan_epoch = now

    if source_changed then
      wezterm.log_info("Background source switched to: " .. self.active_source_label)
    end

    if #self.image_files == 0 and not self.warned_no_images then
      self.warned_no_images = true
      wezterm.log_warn("No background images found in source: " .. self.active_source_label)
    elseif #self.image_files > 0 then
      self.warned_no_images = false
    end

    return source_changed
  end

  function self:pick_random_image(previous)
    self:refresh(false)

    if #self.image_files == 0 then
      return nil
    end

    if #self.image_files == 1 then
      return self.image_files[1]
    end

    local picked = self.image_files[math.random(#self.image_files)]
    while picked == previous do
      picked = self.image_files[math.random(#self.image_files)]
    end

    return picked
  end

  function self:contains_image(image_path)
    if not image_path then
      return false
    end
    return self.image_file_lookup[image_path] == true
  end

  self:refresh(true)

  return self
end

return M
