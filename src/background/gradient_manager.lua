local utils = require("src.background.utils")

local M = {}

function M.new(wezterm, settings)
  local self = {
    cache = {},
  }

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
      .. utils.shell_quote(image_path)
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
          return utils.clamp(rgb_numbers[1] * 2.55, 0, 255), utils.clamp(rgb_numbers[2] * 2.55, 0, 255), utils.clamp(rgb_numbers[3] * 2.55, 0, 255)
        end
        return utils.clamp(rgb_numbers[1], 0, 255), utils.clamp(rgb_numbers[2], 0, 255), utils.clamp(rgb_numbers[3], 0, 255)
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
    return string.format("#%02X%02X%02X", utils.clamp(math.floor(r + 0.5), 0, 255), utils.clamp(math.floor(g + 0.5), 0, 255), utils.clamp(math.floor(b + 0.5), 0, 255))
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
    local saturation = utils.clamp((s * 0.20) + 0.05, 0.05, 0.20)

    local r1, g1, b1 = hsl_to_rgb(tint_hue, saturation, 0.18)
    local r2, g2, b2 = hsl_to_rgb(secondary_hue, utils.clamp(saturation * 0.80, 0.04, 0.16), 0.09)

    local tint_1 = rgb_to_hex(r1, g1, b1)
    local tint_2 = rgb_to_hex(r2, g2, b2)
    local base_1 = settings.gradient_colors[1]
    local base_2 = settings.gradient_colors[2]
    local tint_strength = utils.clamp(settings.adaptive_tint_strength or 0.18, 0, 0.45)

    return {
      blend_hex(base_1, tint_1, tint_strength),
      blend_hex(base_2, tint_2, tint_strength * 0.85),
    }
  end

  function self:gradient_for_image(image_path)
    if not settings.adaptive_gradient or not image_path then
      return utils.copy_gradient(settings.gradient_colors)
    end

    local cached = self.cache[image_path]
    if cached then
      return utils.copy_gradient(cached)
    end

    local ok, colors = pcall(function()
      return wezterm.color.extract_colors_from_image(image_path, settings.color_extract_params)
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
      gradient = utils.copy_gradient(settings.gradient_colors)
    end

    self.cache[image_path] = gradient
    return utils.copy_gradient(gradient)
  end

  function self:blended_gradient(current_gradient, next_gradient, progress)
    if not current_gradient then
      return next_gradient and utils.copy_gradient(next_gradient) or utils.copy_gradient(settings.gradient_colors)
    end

    if not next_gradient then
      return utils.copy_gradient(current_gradient)
    end

    return {
      blend_hex(current_gradient[1], next_gradient[1], progress),
      blend_hex(current_gradient[2], next_gradient[2], progress),
    }
  end

  function self:clear_cache()
    self.cache = {}
  end

  return self
end

return M
