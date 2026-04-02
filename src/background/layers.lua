local M = {}

function M.build_layers(settings, current_image, current_opacity, next_image, next_opacity, gradient_colors)
  local gradient = gradient_colors or settings.gradient_colors
  local layers = {
    {
      source = {
        Gradient = {
          orientation = { Linear = { angle = settings.gradient_angle } },
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

function M.ease_in_out_sine(t)
  return -(math.cos(math.pi * t) - 1) / 2
end

return M
