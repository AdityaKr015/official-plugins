--!nonstrict
-- Region indicator overlay ([[layer]] entry)
--
-- Lazy full-screen surface: one script copy per output, created by the service's
-- noctalia.layer.show("overlay"), destroyed on hide. While a region capture is
-- live the service publishes the picked region as
--
--   "regionIndicator" -> { geometry = "WxH+X+Y" }   (global layout coordinates)
--
-- Each copy dims everything OUTSIDE the region on its own output. The hole stays
-- fully transparent, and a thin accent ring frames it from outside, so
-- nothing inside the recorded area changes on screen: gpu-screen-recorder crops
-- to the region, so the recording is pixel-clean even when the compositor
-- captures this overlay. click_through keeps the pointer working underneath.

local DIM = "#00000066"      -- translucent black (~40%)
local RING = "primary"       -- accent ring framing the region, like the annotation tool
local BORDER_THICKNESS = 2   -- in logical px

-- Global "WxH+X+Y" -> region clipped to this output, in local logical px.
-- Returns hx, hy, hw, hh, outputWidth, outputHeight, or nil when off-output.
local function localRegion(geometry)
  if geometry == nil then return nil end

  local outputName = layer.outputName()
  if outputName == nil then return nil end

  local w, h, x, y = geometry:match("^(%d+)x(%d+)%+(-?%d+)%+(-?%d+)$")
  if w == nil then return nil end
  w, h, x, y = tonumber(w), tonumber(h), tonumber(x), tonumber(y)

  for _, output in ipairs(noctalia.outputs()) do
    if output.name == outputName then
      local hx = math.max(x - output.x, 0)
      local hy = math.max(y - output.y, 0)
      local right = math.min(x + w - output.x, output.width)
      local bottom = math.min(y + h - output.y, output.height)
      local hw = right - hx
      local hh = bottom - hy
      if hw <= 0 or hh <= 0 then return nil end
      return hx, hy, hw, hh, output.width, output.height
    end
  end
  return nil
end

local function render()
  local indicator = noctalia.state.get("regionIndicator")
  local geometry = if type(indicator) == "table" then indicator.geometry else nil

  local hx, hy, hw, hh, outputWidth, outputHeight = localRegion(geometry)
  if hx == nil then
    layer.render(ui.column({}))
    return
  end

  -- Ring thickness clamps at output edges, zero-size bands paint nothing and
  -- the bands always sum to the output size
  local top = math.min(BORDER_THICKNESS, hy)
  local bottom = math.min(BORDER_THICKNESS, outputHeight - hy - hh)
  local left = math.min(BORDER_THICKNESS, hx)
  local right = math.min(BORDER_THICKNESS, outputWidth - hx - hw)

  -- the ring's horizontal side
  local function ringRow(height)
    return ui.row({ height = height }, {
      ui.box({ width = hx - left, fill = DIM }),
      ui.box({ width = hw + left + right, fill = RING }),
      ui.box({ flexGrow = 1, fill = DIM }),
    })
  end

  layer.render(ui.column({}, {
    ui.box({ height = hy - top, fill = DIM }),
    ringRow(top),
    ui.row({ height = hh }, {
      ui.box({ width = hx - left, fill = DIM }),
      ui.box({ width = left, fill = RING }),
      ui.box({ width = hw, fill = "#00000000" }),
      ui.box({ width = right, fill = RING }),
      ui.box({ flexGrow = 1, fill = DIM }),
    }),
    ringRow(bottom),
    ui.box({ height = outputHeight - hy - hh - bottom, fill = DIM }),
  }))
end

noctalia.state.watch("regionIndicator", render)
render()
