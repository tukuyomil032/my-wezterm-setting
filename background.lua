local wezterm = require("wezterm")

local M = {}

M.settings = {
  image_dir = wezterm.config_dir .. "/background-img",
  slideshow_interval_seconds = 18,
  rescan_interval_seconds = 5,
  tick_interval_ms = 16,
  transition_duration_ms = 1800,
  image_opacity = 0.22,
  enable_crossfade = false,
  adaptive_gradient = true,
  adaptive_tint_strength = 0.18,
  gradient_angle = 90.0,
  gradient_colors = {
    "#101823",
    "#070B11",
  },
  color_extract_params = {
    num_colors = 3,
    max_width = 320,
    max_height = 180,
    min_brightness = 8,
    max_brightness = 92,
    threshold = 65,
    fuzziness = 6,
  },
  -- Optional fallback if background-img is empty.
  fallback_image = nil,
}

local function clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

local function copy_gradient(colors)
  return { colors[1], colors[2] }
end

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function to_tick_count(duration_ms)
  local ticks = math.floor((duration_ms / M.settings.tick_interval_ms) + 0.5)
  return math.max(1, ticks)
end

local HOLD_TICKS = to_tick_count(M.settings.slideshow_interval_seconds * 1000)
local FADE_TICKS = to_tick_count(M.settings.transition_duration_ms)

local function file_exists(path)
  if not path or path == "" then
    return false
  end
  local handle = io.open(path, "r")
  if not handle then
    return false
  end
  handle:close()
  return true
end

local function collect_image_files()
  local command = "find "
    .. shell_quote(M.settings.image_dir)
    .. " -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \\) -print 2>/dev/null"
  local pipe = io.popen(command)
  local files = {}
  local seen = {}

  if not pipe then
    wezterm.log_warn("Failed to scan image directory: " .. M.settings.image_dir)
    return files
  end

  for file in pipe:lines() do
    local normalized = file:gsub("%s+$", "")
    if normalized ~= "" and not seen[normalized] then
      seen[normalized] = true
      table.insert(files, normalized)
    end
  end

  pipe:close()
  table.sort(files)

  if #files == 0 and file_exists(M.settings.fallback_image) then
    table.insert(files, M.settings.fallback_image)
  end

  return files
end

local image_files = {}
local last_scan_epoch = 0
local warned_no_images = false

local function refresh_image_files(force)
  local now = os.time()
  if not force and (now - last_scan_epoch) < M.settings.rescan_interval_seconds then
    return
  end

  image_files = collect_image_files()
  last_scan_epoch = now

  if #image_files == 0 and not warned_no_images then
    warned_no_images = true
    wezterm.log_warn("No background images found in " .. M.settings.image_dir)
  elseif #image_files > 0 then
    warned_no_images = false
  end
end

refresh_image_files(true)
math.randomseed(os.time())

local function pick_random_image(previous)
  refresh_image_files(false)

  if #image_files == 0 then
    return nil
  end

  if #image_files == 1 then
    return image_files[1]
  end

  local picked = image_files[math.random(#image_files)]
  while picked == previous do
    picked = image_files[math.random(#image_files)]
  end

  return picked
end

local function coerce_color_input(value)
  if value == nil then
    return nil
  end

  if type(value) == "string" then
    return value
  end

  if type(value) == "table" then
    local srgb_u8 = value.srgb_u8
    if type(srgb_u8) == "function" then
      local ok, r, g, b = pcall(srgb_u8, value)
      if ok and r and g and b then
        return string.format("#%02X%02X%02X", r, g, b)
      end
    end

    if type(value.hex) == "string" then
      return value.hex
    end

    if type(value.color) == "string" then
      return value.color
    end

    if type(value[1]) == "string" then
      return value[1]
    end
  end

  local as_string = tostring(value)
  if type(as_string) == "string" then
    local embedded_hex = as_string:match("#[%x]+")
    if embedded_hex then
      return embedded_hex
    end
    return as_string
  end

  return nil
end

local function extract_dominant_hex_with_magick(image_path)
  if not image_path or image_path == "" then
    return nil
  end

  local command = "magick "
    .. shell_quote(image_path)
    .. " -resize 1x1\\! -format \"%[hex:p{0,0}]\" info: 2>/dev/null"
  local pipe = io.popen(command)
  if not pipe then
    return nil
  end

  local output = pipe:read("*a") or ""
  pipe:close()

  local hex = output:gsub("%s+", "")
  if #hex == 8 then
    hex = hex:sub(1, 6)
  end

  if #hex ~= 6 or not hex:match("^[%x]+$") then
    return nil
  end

  return "#" .. hex
end

local function hex_to_rgb(hex)
  local raw = coerce_color_input(hex)
  if not raw then
    return nil
  end

  local rgb_numbers = {}
  if raw:find("^%s*[sS]?[rR][gG][bB]%(") then
    for number in raw:gmatch("([%d%.]+)") do
      table.insert(rgb_numbers, tonumber(number))
    end

    if #rgb_numbers >= 3 then
      if raw:find("%%") then
        return clamp(rgb_numbers[1] * 2.55, 0, 255), clamp(rgb_numbers[2] * 2.55, 0, 255), clamp(rgb_numbers[3] * 2.55, 0, 255)
      end
      return clamp(rgb_numbers[1], 0, 255), clamp(rgb_numbers[2], 0, 255), clamp(rgb_numbers[3], 0, 255)
    end
  end

  local value = raw:match("#([%x]+)") or raw:match("^%s*([%x]+)%s*$")
  if not value then
    return nil
  end

  if #value == 8 then
    value = value:sub(1, 6)
  end

  if #value ~= 6 then
    return nil
  end

  local r = tonumber(value:sub(1, 2), 16)
  local g = tonumber(value:sub(3, 4), 16)
  local b = tonumber(value:sub(5, 6), 16)

  if not r or not g or not b then
    return nil
  end

  return r, g, b
end

local function rgb_to_hex(r, g, b)
  return string.format("#%02X%02X%02X", clamp(math.floor(r + 0.5), 0, 255), clamp(math.floor(g + 0.5), 0, 255), clamp(math.floor(b + 0.5), 0, 255))
end

local function rgb_to_hsl(r, g, b)
  local max_v = math.max(r, g, b)
  local min_v = math.min(r, g, b)
  local h = 0
  local l = (max_v + min_v) / 2
  local s = 0

  if max_v ~= min_v then
    local d = max_v - min_v
    s = d / (1 - math.abs((2 * l) - 1))

    if max_v == r then
      h = ((g - b) / d) % 6
    elseif max_v == g then
      h = ((b - r) / d) + 2
    else
      h = ((r - g) / d) + 4
    end

    h = h / 6
  end

  return h, s, l
end

local function hsl_to_rgb(h, s, l)
  local c = (1 - math.abs((2 * l) - 1)) * s
  local h_prime = h * 6
  local x = c * (1 - math.abs((h_prime % 2) - 1))
  local r1, g1, b1 = 0, 0, 0

  if h_prime < 1 then
    r1, g1, b1 = c, x, 0
  elseif h_prime < 2 then
    r1, g1, b1 = x, c, 0
  elseif h_prime < 3 then
    r1, g1, b1 = 0, c, x
  elseif h_prime < 4 then
    r1, g1, b1 = 0, x, c
  elseif h_prime < 5 then
    r1, g1, b1 = x, 0, c
  else
    r1, g1, b1 = c, 0, x
  end

  local m = l - (c / 2)
  return (r1 + m) * 255, (g1 + m) * 255, (b1 + m) * 255
end

local function blend_hex(from_hex, to_hex, t)
  local fr, fg, fb = hex_to_rgb(from_hex)
  local tr, tg, tb = hex_to_rgb(to_hex)
  if not fr or not tr then
    return from_hex
  end

  local blended_r = fr + ((tr - fr) * t)
  local blended_g = fg + ((tg - fg) * t)
  local blended_b = fb + ((tb - fb) * t)

  return rgb_to_hex(blended_r, blended_g, blended_b)
end

local function build_adaptive_gradient(dominant_hex)
  local dr, dg, db = hex_to_rgb(dominant_hex)
  if not dr then
    return nil
  end

  local h, s, _ = rgb_to_hsl(dr / 255, dg / 255, db / 255)
  local tint_hue = h
  local secondary_hue = (tint_hue + 0.03) % 1.0
  local saturation = clamp((s * 0.20) + 0.05, 0.05, 0.20)

  local r1, g1, b1 = hsl_to_rgb(tint_hue, saturation, 0.18)
  local r2, g2, b2 = hsl_to_rgb(secondary_hue, clamp(saturation * 0.80, 0.04, 0.16), 0.09)

  local tint_1 = rgb_to_hex(r1, g1, b1)
  local tint_2 = rgb_to_hex(r2, g2, b2)
  local base_1 = M.settings.gradient_colors[1]
  local base_2 = M.settings.gradient_colors[2]
  local tint_strength = clamp(M.settings.adaptive_tint_strength or 0.18, 0, 0.45)

  return {
    blend_hex(base_1, tint_1, tint_strength),
    blend_hex(base_2, tint_2, tint_strength * 0.85),
  }
end

local gradient_cache = {}

local function gradient_for_image(image_path)
  if not M.settings.adaptive_gradient or not image_path then
    return copy_gradient(M.settings.gradient_colors)
  end

  local cached = gradient_cache[image_path]
  if cached then
    return copy_gradient(cached)
  end

  local ok, colors = pcall(function()
    return wezterm.color.extract_colors_from_image(image_path, M.settings.color_extract_params)
  end)

  local gradient = nil
  if ok and type(colors) == "table" and #colors > 0 then
    gradient = build_adaptive_gradient(colors[1])
  end

  if not gradient then
    local fallback_hex = extract_dominant_hex_with_magick(image_path)
    if fallback_hex then
      gradient = build_adaptive_gradient(fallback_hex)
    end
  end

  if not gradient then
    gradient = copy_gradient(M.settings.gradient_colors)
  end

  gradient_cache[image_path] = gradient
  return copy_gradient(gradient)
end

local function blended_gradient(current_gradient, next_gradient, progress)
  if not current_gradient then
    return next_gradient and copy_gradient(next_gradient) or copy_gradient(M.settings.gradient_colors)
  end

  if not next_gradient then
    return copy_gradient(current_gradient)
  end

  return {
    blend_hex(current_gradient[1], next_gradient[1], progress),
    blend_hex(current_gradient[2], next_gradient[2], progress),
  }
end

local function build_layers(current_image, current_opacity, next_image, next_opacity, gradient_colors)
  local gradient = gradient_colors or M.settings.gradient_colors
  local layers = {
    {
      source = {
        Gradient = {
          orientation = { Linear = { angle = M.settings.gradient_angle } },
          colors = gradient,
        },
      },
      width = "100%",
      height = "100%",
      opacity = 1.0,
    },
  }

  if current_image and current_opacity > 0 then
    table.insert(layers, {
      source = { File = current_image },
      horizontal_align = "Center",
      vertical_align = "Middle",
      width = "Cover",
      height = "Cover",
      opacity = current_opacity,
    })
  end

  if next_image and next_opacity > 0 then
    table.insert(layers, {
      source = { File = next_image },
      horizontal_align = "Center",
      vertical_align = "Middle",
      width = "Cover",
      height = "Cover",
      opacity = next_opacity,
    })
  end

  return layers
end

local function ease_in_out_sine(t)
  return -(math.cos(math.pi * t) - 1) / 2
end

local function make_state(initial_image, initial_gradient)
  return {
    current_image = initial_image,
    current_gradient = copy_gradient(initial_gradient),
    next_image = nil,
    next_gradient = nil,
    hold_tick = 0,
    fade_tick = 0,
  }
end

local function apply_static_background(window, image_path, gradient)
  window:set_config_overrides({
    background = build_layers(image_path, M.settings.image_opacity, nil, 0, gradient),
  })
end

local function apply_fade_background(window, current_image, next_image, current_gradient, next_gradient, progress)
  local clamped = clamp(progress, 0, 1)
  local eased = ease_in_out_sine(clamped)
  local gradient = blended_gradient(current_gradient, next_gradient, eased)

  window:set_config_overrides({
    background = build_layers(
      current_image,
      M.settings.image_opacity * (1 - eased),
      next_image,
      M.settings.image_opacity * eased,
      gradient
    ),
  })
end

local initial_image = pick_random_image(nil)
local initial_gradient = gradient_for_image(initial_image)

local state_by_window = {}

function M.get_initial_background()
  return build_layers(initial_image, M.settings.image_opacity, nil, 0, initial_gradient)
end

function M.tick(window)
  refresh_image_files(false)

  local id = tostring(window:window_id())
  local state = state_by_window[id]

  if not state then
    state = make_state(initial_image, initial_gradient)
    state_by_window[id] = state
    apply_static_background(window, state.current_image, state.current_gradient)
    return
  end

  if state.next_image then
    state.fade_tick = state.fade_tick + 1
    local progress = state.fade_tick / FADE_TICKS
    apply_fade_background(
      window,
      state.current_image,
      state.next_image,
      state.current_gradient,
      state.next_gradient,
      progress
    )

    if progress >= 1 then
      state.current_image = state.next_image
      state.current_gradient = copy_gradient(state.next_gradient)
      state.next_image = nil
      state.next_gradient = nil
      state.fade_tick = 0
      state.hold_tick = 0
      apply_static_background(window, state.current_image, state.current_gradient)
    end
    return
  end

  state.hold_tick = state.hold_tick + 1
  if state.hold_tick < HOLD_TICKS then
    return
  end

  local candidate = pick_random_image(state.current_image)
  if not candidate or candidate == state.current_image then
    state.hold_tick = 0
    return
  end

  if not M.settings.enable_crossfade then
    state.current_image = candidate
    state.current_gradient = gradient_for_image(candidate)
    state.hold_tick = 0
    apply_static_background(window, state.current_image, state.current_gradient)
    return
  end

  state.next_image = candidate
  state.next_gradient = gradient_for_image(candidate)
  state.fade_tick = 0
  apply_fade_background(
    window,
    state.current_image,
    state.next_image,
    state.current_gradient,
    state.next_gradient,
    0
  )
end

return M
