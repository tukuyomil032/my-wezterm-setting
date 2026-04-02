local wezterm = require("wezterm")
local utils = require("src.background.utils")
local layers = require("src.background.layers")
local SourceManager = require("src.background.source_manager")
local GradientManager = require("src.background.gradient_manager")

local M = {}

M.settings = {
  -- Place preset directories like preset-1, preset-2 under this root.
  presets_root_dir = wezterm.config_dir,
  -- Write target preset name here to switch source at runtime.
  preset_selector_file = wezterm.config_dir .. "/.wezterm-background-preset",
  default_preset = "preset-1",
  -- Backward compatibility: used only if selected preset has no images.
  legacy_image_dir = wezterm.config_dir .. "/background-img",

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

  -- Optional fallback if no images are found in selected source.
  fallback_image = nil,
}

local HOLD_TICKS = utils.to_tick_count(M.settings.slideshow_interval_seconds * 1000, M.settings.tick_interval_ms)
local FADE_TICKS = utils.to_tick_count(M.settings.transition_duration_ms, M.settings.tick_interval_ms)

local source_manager = SourceManager.new(wezterm, M.settings)
local gradient_manager = GradientManager.new(wezterm, M.settings)

local state_by_window = {}

math.randomseed(os.time())

local function build_layers(current_image, current_opacity, next_image, next_opacity, gradient_colors)
  return layers.build_layers(M.settings, current_image, current_opacity, next_image, next_opacity, gradient_colors)
end

local function make_state(previous_image)
  local current_image = source_manager:pick_random_image(previous_image)
  return {
    current_image = current_image,
    current_gradient = gradient_manager:gradient_for_image(current_image),
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
  local clamped = utils.clamp(progress, 0, 1)
  local eased = layers.ease_in_out_sine(clamped)
  local gradient = gradient_manager:blended_gradient(current_gradient, next_gradient, eased)

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

function M.list_available_sources()
  return source_manager:list_available_sources()
end

function M.set_selected_source(source_name)
  local ok, err = source_manager:set_selected_source(source_name)
  if ok then
    gradient_manager:clear_cache()
  end
  return ok, err
end

function M.force_rescan()
  local source_changed = source_manager:refresh(true)
  if source_changed then
    gradient_manager:clear_cache()
  end
  return source_changed
end

function M.get_initial_background()
  source_manager:refresh(true)
  local initial_image = source_manager:pick_random_image(nil)
  local initial_gradient = gradient_manager:gradient_for_image(initial_image)
  return build_layers(initial_image, M.settings.image_opacity, nil, 0, initial_gradient)
end

function M.tick(window)
  local source_changed = source_manager:refresh(false)
  if source_changed then
    gradient_manager:clear_cache()
  end

  local id = tostring(window:window_id())
  local state = state_by_window[id]

  if not state then
    state = make_state(nil)
    state_by_window[id] = state
    apply_static_background(window, state.current_image, state.current_gradient)
    return
  end

  if source_changed or (state.current_image and not source_manager:contains_image(state.current_image)) then
    local previous = state.current_image
    local refreshed = make_state(previous)
    state.current_image = refreshed.current_image
    state.current_gradient = refreshed.current_gradient
    state.next_image = nil
    state.next_gradient = nil
    state.hold_tick = 0
    state.fade_tick = 0
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
      state.current_gradient = utils.copy_gradient(state.next_gradient)
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

  local candidate = source_manager:pick_random_image(state.current_image)
  if not candidate or candidate == state.current_image then
    state.hold_tick = 0
    return
  end

  if not M.settings.enable_crossfade then
    state.current_image = candidate
    state.current_gradient = gradient_manager:gradient_for_image(candidate)
    state.hold_tick = 0
    apply_static_background(window, state.current_image, state.current_gradient)
    return
  end

  state.next_image = candidate
  state.next_gradient = gradient_manager:gradient_for_image(candidate)
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
