local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- GPU / WebGPU
local gpus = wezterm.gui.enumerate_gpus()
local best_gpu = (function()
  local backend_score  = { Metal = 1 }
  local device_score   = { DiscreteGpu = 128, IntegratedGpu = 64, Other = 32, Cpu = 16 }
  local best, score = nil, 0
  for _, gpu in ipairs(gpus) do
    local s = (backend_score[gpu.backend] or 0) + (device_score[gpu.device_type] or 0)
    if s > score then best, score = gpu, s end
  end
  return best
end)()
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"
if best_gpu then config.webgpu_preferred_adapter = best_gpu end

-- Appearance
config.color_scheme = "Tokyo Night Storm"
config.font = wezterm.font("JetBrainsMono Nerd Font", { weight = "Regular" })
config.font_size = 14.0
config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" }
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.window_padding = { left = 4, right = 4, top = 4, bottom = 4 }

-- Tab bar
config.use_fancy_tab_bar = true

-- Cursor
config.default_cursor_style = "BlinkingBlock"
config.animation_fps = 60
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = "EaseIn"
config.cursor_blink_ease_out = "EaseOut"

-- Mouse
config.pane_focus_follows_mouse = true

-- Scrollback
config.scrollback_lines = 50000

-- Bell
config.audible_bell = "SystemBeep"

-- Hyperlinks
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Copy on select
config.selection_word_boundary = " \t\n{}[]()\"'`,;:"

-- Command palette
config.command_palette_font_size = 16
config.command_palette_rows = 7

-- Keybindings
config.keys = {
  -- Splits
  { key = "d", mods = "CMD",       action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "d", mods = "CMD|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  -- Tabs
  { key = "t", mods = "CMD",       action = act.SpawnTab("CurrentPaneDomain") },
  { key = "w", mods = "CMD",       action = act.CloseCurrentTab({ confirm = true }) },
  { key = "[", mods = "CMD",       action = act.ActivateTabRelative(-1) },
  { key = "]", mods = "CMD",       action = act.ActivateTabRelative(1) },
  { key = "r", mods = "CMD",       action = act.PromptInputLine {
    description = "Rename tab",
    action = wezterm.action_callback(function(window, _, line)
      if line then window:active_tab():set_title(line) end
    end),
  }},
  -- Word navigation
  { key = "LeftArrow",  mods = "OPT", action = act.SendString("\x1bb") },
  { key = "RightArrow", mods = "OPT", action = act.SendString("\x1bf") },
  -- Pane navigation
  { key = "h", mods = "CTRL", action = act.ActivatePaneDirection("Left") },
  { key = "j", mods = "CTRL", action = act.ActivatePaneDirection("Down") },
  { key = "k", mods = "CTRL", action = act.ActivatePaneDirection("Up") },
  { key = "l", mods = "CTRL", action = act.ActivatePaneDirection("Right") },
  { key = "z", mods = "CMD", action = act.TogglePaneZoomState },
  { key = "p", mods = "CMD|SHIFT", action = act.ActivateCommandPalette },
}

-- Switch to a warm theme when on the local domain
local LOCAL_THEME = "Gruvbox dark, medium (base16)"
local REMOTE_FRAME = {
  font = wezterm.font("JetBrainsMono Nerd Font", { weight = "Bold" }),
  font_size = 16.0,
  active_titlebar_bg = "#1e2030",
  inactive_titlebar_bg = "#1e2030",
}
local LOCAL_FRAME = {
  font = wezterm.font("JetBrainsMono Nerd Font", { weight = "Bold" }),
  font_size = 16.0,
  active_titlebar_bg = "#1d2021",
  inactive_titlebar_bg = "#1d2021",
}
wezterm.on("update-status", function(window, pane)
  local domain = pane:get_domain_name()
  if domain == "local" then
    window:set_config_overrides({ color_scheme = LOCAL_THEME, window_frame = LOCAL_FRAME })
  else
    window:set_config_overrides({ window_frame = REMOTE_FRAME })
  end
end)

return config
