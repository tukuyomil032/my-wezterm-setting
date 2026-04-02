local wezterm = require("wezterm")
local utils = require("src.background.utils")
local layers = require("src.background.layers")
local SourceManager = require("src.background.source_manager")
local GradientManager = require("src.background.gradient_manager")
local VideoManager = require("src.background.video_manager")

local M = {}

M.settings = {
  -- Place preset directories like preset-1, preset-2 under this root.
  presets_root_dir = wezterm.config_dir,
  -- Write target preset name here to switch source at runtime.
  preset_selector_file = wezterm.config_dir .. "/.wezterm-background-preset",
  default_preset = "preset-1",
  -- Backward compatibility: used only if selected source has no media.
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

  -- Video playback (frame extraction with ffmpeg)
  enable_video_playback = true,
  video_extract_fps = 30,
  video_max_width = 1920,
  video_cache_dir = wezterm.config_dir .. "/.video-frame-cache",
  video_settings_file = wezterm.config_dir .. "/.wezterm-video-settings",

  -- Optional fallback if no media is found in selected source.
  fallback_image = nil,
}

local HOLD_TICKS = utils.to_tick_count(M.settings.slideshow_interval_seconds * 1000, M.settings.tick_interval_ms)
local FADE_TICKS = utils.to_tick_count(M.settings.transition_duration_ms, M.settings.tick_interval_ms)

local source_manager = SourceManager.new(wezterm, M.settings)
local gradient_manager = GradientManager.new(wezterm, M.settings)
local video_manager = VideoManager.new(wezterm, M.settings)

local state_by_window = {}

math.randomseed(os.time())

local function build_layers(current_image, current_opacity, next_image, next_opacity, gradient_colors)
  return layers.build_layers(M.settings, current_image, current_opacity, next_image, next_opacity, gradient_colors)
end

local function build_state_from_item(item)
  local state = {
    current_item = item,
    current_image = nil,
    current_gradient = utils.copy_gradient(M.settings.gradient_colors),
    next_item = nil,
    next_image = nil,
    next_gradient = nil,
    hold_tick = 0,
    fade_tick = 0,
    video = nil,
  }

  if not item then
    return state
  end

  if item.kind == "video" then
    local prepared, err = video_manager:prepare(item.path)
    if not prepared then
      wezterm.log_warn("Video skipped: " .. item.path .. " (" .. (err or "unknown error") .. ")")
      return nil
    end

    local first_frame = prepared.frame_paths[1]
    state.current_image = first_frame
    state.current_gradient = gradient_manager:gradient_for_image(first_frame)
    state.video = {
      frame_paths = prepared.frame_paths,
      frame_index = 1,
      frame_ticks = prepared.frame_ticks,
      tick = 0,
    }
    return state
  end

  state.current_image = item.path
  state.current_gradient = gradient_manager:gradient_for_image(item.path)
  return state
end

local function make_state(previous_item)
  local attempts = math.max(1, source_manager:item_count())
  local previous = previous_item

  for _ = 1, attempts do
    local candidate = source_manager:pick_random_item(previous)
    if not candidate then
      break
    end

    local built = build_state_from_item(candidate)
    if built then
      return built
    end

    previous = candidate
  end

  return build_state_from_item(nil)
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
  local initial_state = make_state(nil)
  return build_layers(initial_state.current_image, M.settings.image_opacity, nil, 0, initial_state.current_gradient)
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

  if source_changed or (state.current_item and not source_manager:contains_item(state.current_item)) then
    local refreshed = make_state(state.current_item)
    state_by_window[id] = refreshed
    apply_static_background(window, refreshed.current_image, refreshed.current_gradient)
    return
  end

  if state.video then
    state.video.tick = state.video.tick + 1
    if state.video.tick < state.video.frame_ticks then
      return
    end

    state.video.tick = 0

    if state.video.frame_index < #state.video.frame_paths then
      state.video.frame_index = state.video.frame_index + 1
      state.current_image = state.video.frame_paths[state.video.frame_index]
      apply_static_background(window, state.current_image, state.current_gradient)
      return
    end

    local refreshed = make_state(state.current_item)
    state_by_window[id] = refreshed
    apply_static_background(window, refreshed.current_image, refreshed.current_gradient)
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
      state.current_item = state.next_item
      state.current_image = state.next_image
      state.current_gradient = utils.copy_gradient(state.next_gradient)
      state.next_item = nil
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

  local candidate = source_manager:pick_random_item(state.current_item)
  if not candidate or (state.current_item and candidate.key == state.current_item.key) then
    state.hold_tick = 0
    return
  end

  local candidate_state = build_state_from_item(candidate)
  if not candidate_state then
    state.hold_tick = 0
    return
  end

  if not M.settings.enable_crossfade or candidate.kind == "video" then
    state_by_window[id] = candidate_state
    apply_static_background(window, candidate_state.current_image, candidate_state.current_gradient)
    return
  end

  state.next_item = candidate
  state.next_image = candidate_state.current_image
  state.next_gradient = candidate_state.current_gradient
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
