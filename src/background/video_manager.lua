local utils = require("src.background.utils")

local M = {}

local function quick_hash(text)
  local hash = 0
  for i = 1, #text do
    hash = (hash * 131 + text:byte(i)) % 2147483647
  end
  return string.format("%08x", hash)
end

function M.new(wezterm, settings)
  local self = {
    cache_by_video = {},
    checked_ffmpeg = false,
    ffmpeg_available = false,
    warned_missing_ffmpeg = false,
    runtime_config_cache = nil,
  }

  local function command_exists(name)
    local command = "command -v " .. utils.shell_quote(name) .. " >/dev/null 2>&1 && printf '1' || true"
    local pipe = io.popen(command)
    if not pipe then
      return false
    end

    local output = utils.trim(pipe:read("*a") or "")
    pipe:close()
    return output == "1"
  end

  local function ensure_ffmpeg()
    if self.checked_ffmpeg then
      return self.ffmpeg_available
    end

    self.ffmpeg_available = command_exists("ffmpeg")
    self.checked_ffmpeg = true

    if not self.ffmpeg_available and not self.warned_missing_ffmpeg then
      self.warned_missing_ffmpeg = true
      wezterm.log_warn("Video background requires ffmpeg. Install ffmpeg to enable mp4/mov playback.")
    end

    return self.ffmpeg_available
  end

  local function file_mtime(path)
    local command = "stat -f %m " .. utils.shell_quote(path) .. " 2>/dev/null"
    local pipe = io.popen(command)
    if not pipe then
      return nil
    end

    local output = utils.trim(pipe:read("*a") or "")
    pipe:close()

    local mtime = tonumber(output)
    return mtime
  end

  local function read_runtime_settings()
    local config_file = settings.video_settings_file
    local default_fps = settings.video_extract_fps
    local default_max_width = settings.video_max_width

    if not config_file or config_file == "" or not utils.file_exists(config_file) then
      return {
        video_extract_fps = default_fps,
        video_max_width = default_max_width,
        settings_mtime = nil,
      }
    end

    local mtime = file_mtime(config_file)
    if self.runtime_config_cache and self.runtime_config_cache.settings_mtime == mtime then
      return self.runtime_config_cache
    end

    local runtime = {
      video_extract_fps = default_fps,
      video_max_width = default_max_width,
      settings_mtime = mtime,
    }

    local handle = io.open(config_file, "r")
    if handle then
      for raw_line in handle:lines() do
        local line = utils.trim(raw_line)
        if line ~= "" and not line:match("^#") then
          local key, value = line:match("^([%w_]+)%s*=%s*(.-)%s*$")
          if key and value then
            if key == "video_extract_fps" then
              local parsed_fps = tonumber(value)
              if parsed_fps == 30 or parsed_fps == 60 then
                runtime.video_extract_fps = parsed_fps
              end
            elseif key == "video_max_width" then
              local parsed_width = tonumber(value)
              if parsed_width and parsed_width >= 0 then
                runtime.video_max_width = parsed_width
              end
            end
          end
        end
      end
      handle:close()
    end

    self.runtime_config_cache = runtime
    return runtime
  end

  local function collect_frame_paths(frame_dir)
    local command = "find "
      .. utils.shell_quote(frame_dir)
      .. " -maxdepth 1 -type f -name 'frame-*.jpg' -print 2>/dev/null"

    local pipe = io.popen(command)
    local frames = {}

    if not pipe then
      return frames
    end

    for line in pipe:lines() do
      local path = utils.trim(line)
      if path ~= "" then
        table.insert(frames, path)
      end
    end

    pipe:close()
    table.sort(frames)
    return frames
  end

  local function extract_frames(video_path, output_dir, fps, max_width)
    local vf = "fps=" .. tostring(fps)

    if max_width and max_width > 0 then
      vf = vf .. ",scale=" .. tostring(max_width) .. ":-2:flags=lanczos"
    end

    local output_pattern = output_dir .. "/frame-%06d.jpg"
    local command = "mkdir -p "
      .. utils.shell_quote(output_dir)
      .. " && ffmpeg -hide_banner -loglevel error -y -i "
      .. utils.shell_quote(video_path)
      .. " -vf "
      .. utils.shell_quote(vf)
      .. " "
      .. utils.shell_quote(output_pattern)
      .. " 2>/dev/null"

    local ok = os.execute(command)
    return ok == true or ok == 0
  end

  function self:prepare(video_path)
    if not settings.enable_video_playback then
      return nil, "Video playback is disabled"
    end

    if not ensure_ffmpeg() then
      return nil, "ffmpeg is not available"
    end

    local runtime = read_runtime_settings()
    local fps = runtime.video_extract_fps
    local max_width = runtime.video_max_width

    local mtime = file_mtime(video_path)
    local cache = self.cache_by_video[video_path]

    if cache
      and cache.mtime == mtime
      and cache.video_extract_fps == fps
      and cache.video_max_width == max_width
      and cache.frame_paths
      and #cache.frame_paths > 0 then
      return cache, nil
    end

    local cache_key = quick_hash(video_path .. "|" .. tostring(mtime) .. "|" .. tostring(fps) .. "|" .. tostring(max_width))
    local output_dir = settings.video_cache_dir .. "/" .. cache_key
    local frame_paths = collect_frame_paths(output_dir)

    if #frame_paths == 0 then
      local extracted = extract_frames(video_path, output_dir, fps, max_width)
      if not extracted then
        return nil, "Failed to extract frames from video"
      end
      frame_paths = collect_frame_paths(output_dir)
    end

    if #frame_paths == 0 then
      return nil, "No frames extracted from video"
    end

    local frame_ms = 1000 / fps
    local frame_ticks = utils.to_tick_count(frame_ms, settings.tick_interval_ms)

    local prepared = {
      video_path = video_path,
      mtime = mtime,
      output_dir = output_dir,
      frame_paths = frame_paths,
      frame_ticks = frame_ticks,
      video_extract_fps = fps,
      video_max_width = max_width,
    }

    self.cache_by_video[video_path] = prepared
    return prepared, nil
  end

  return self
end

return M
