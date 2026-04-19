local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- GPU / WebGPU
local gpus = wezterm.gui.enumerate_gpus()
local best_gpu = (function()
  local backend_score = { Metal = 1 }
  local device_score  = { DiscreteGpu = 128, IntegratedGpu = 64, Other = 32, Cpu = 16 }
  local best, score   = nil, 0
  for _, gpu in ipairs(gpus) do
    local s = (backend_score[gpu.backend] or 0) + (device_score[gpu.device_type] or 0)
    if s > score then best, score = gpu, s end
  end
  return best
end)()
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"
if best_gpu then config.webgpu_preferred_adapter = best_gpu end

-- HELPERS

local function brightness_auto_adjust(hex, amount)
  if #hex ~= 7 or hex:sub(1, 1) ~= "#" then
    error("Invalid hex color format. Expected format: #RRGGBB")
  end
  amount = math.min(math.max(amount, 0), 1)
  local r = tonumber(hex:sub(2, 3), 16)
  local g = tonumber(hex:sub(4, 5), 16)
  local b = tonumber(hex:sub(6, 7), 16)
  local brightness = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
  if brightness < 0.5 then
    r = math.min(255, math.floor(r + (255 - r) * amount))
    g = math.min(255, math.floor(g + (255 - g) * amount))
    b = math.min(255, math.floor(b + (255 - b) * amount))
  else
    r = math.max(0, math.floor(r * (1 - amount)))
    g = math.max(0, math.floor(g * (1 - amount)))
    b = math.max(0, math.floor(b * (1 - amount)))
  end
  return string.format("#%02X%02X%02X", r, g, b)
end

local function getDirectoryName(path)
  if not path then return "Unknown" end
  path = path:gsub("/+$", "")
  return path:match("([^/]+)$") or "Unknown"
end

-- Build window_frame + tab colors from a scheme name
local function build_theme(scheme_name)
  local def = wezterm.color.get_builtin_schemes()[scheme_name]
  local bg = def.background
  local tab_font = wezterm.font("JetBrainsMono Nerd Font", { weight = "Bold" })
  return {
    def = def,
    overrides = {
      color_scheme = scheme_name,
      window_frame = {
        font                 = tab_font,
        font_size            = 14.0,
        active_titlebar_bg   = brightness_auto_adjust(bg, 0.165),
        inactive_titlebar_bg = brightness_auto_adjust(bg, 0.100),
        border_bottom_height = "1px",
        border_left_width    = "1px",
        border_right_width   = "1px",
        border_bottom_color  = brightness_auto_adjust(bg, 0.300),
        border_left_color    = brightness_auto_adjust(bg, 0.300),
        border_right_color   = brightness_auto_adjust(bg, 0.300),
      },
      colors = {
        tab_bar = {
          inactive_tab_edge = brightness_auto_adjust(bg, 0.500),
          active_tab        = { bg_color = bg, fg_color = def.foreground },
          inactive_tab      = { bg_color = "none", fg_color = brightness_auto_adjust(bg, 0.500) },
        },
      },
    },
  }
end

local LOCAL_THEME                   = build_theme("Gruvbox dark, medium (base16)")
local REMOTE_THEME                  = build_theme("Tokyo Night Storm")

-- Appearance
config.color_scheme                 = REMOTE_THEME.overrides.color_scheme
config.window_frame                 = REMOTE_THEME.overrides.window_frame
config.colors                       = REMOTE_THEME.overrides.colors
config.font                         = wezterm.font("JetBrainsMono Nerd Font", { weight = "Regular" })
config.font_size                    = 14.0
config.harfbuzz_features            = { "calt=1", "clig=1", "liga=1" }
config.window_decorations           = "RESIZE"
config.window_padding               = { left = 4, right = 4, top = 4, bottom = 4 }

-- Tab bar
config.use_fancy_tab_bar            = true
config.tab_bar_at_bottom            = false
config.hide_tab_bar_if_only_one_tab = false

-- Cursor
config.default_cursor_style         = "BlinkingBlock"
config.animation_fps                = 120
config.max_fps                      = 120
config.cursor_blink_rate            = 500
config.cursor_blink_ease_in         = "EaseIn"
config.cursor_blink_ease_out        = "EaseOut"

-- Scrollback
config.scrollback_lines             = 50000

-- Bell
config.audible_bell                 = "SystemBeep"

-- Hyperlinks
config.hyperlink_rules              = wezterm.default_hyperlink_rules()

-- Copy on select
config.selection_word_boundary      = " \t\n{}[]()\"'`,;:"

-- Command palette
config.command_palette_font_size    = 16
config.command_palette_rows         = 7

-- Tab title: ⌘{index}  {dir}
wezterm.on("format-tab-title", function(tab)
  local pane = tab.active_pane
  local cwd_uri = pane.current_working_dir
  local dir = cwd_uri and getDirectoryName(cwd_uri.file_path) or "Unknown"
  return { { Text = string.format(" ⌘%s  %s ", tab.tab_index + 1, dir) } }
end)

-- Theme switching + status bar
wezterm.on("update-status", function(window, pane)
  local domain = pane:get_domain_name()
  local theme = domain == "local" and LOCAL_THEME or REMOTE_THEME
  window:set_config_overrides(theme.overrides)

  local workspace = window:active_workspace()
  local cwd_uri = pane.current_working_dir
  local hostname = (cwd_uri and cwd_uri.host and cwd_uri.host ~= "" and cwd_uri.host)
      or (domain ~= "local" and domain)
      or wezterm.hostname()

  window:set_left_status(wezterm.format({
    { Foreground = { Color = theme.def.foreground } },
    { Attribute = { Intensity = "Bold" } },
    { Text = "  " .. wezterm.nerdfonts.oct_person .. " " .. hostname },
    { Text = "  " .. wezterm.nerdfonts.oct_table .. " " .. workspace .. "  " },
  }))
  window:set_right_status("")
end)

-- Keybindings
config.keys = {
  -- Splits
  { key = "d", mods = "CMD",       action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "d", mods = "CMD|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  -- Tabs
  { key = "t", mods = "CMD",       action = act.SpawnTab("CurrentPaneDomain") },
  { key = "w", mods = "CMD",       action = act.CloseCurrentPane({ confirm = true }) },
  { key = "[", mods = "CMD",       action = act.ActivateTabRelative(-1) },
  { key = "]", mods = "CMD",       action = act.ActivateTabRelative(1) },
  {
    key = "r",
    mods = "CMD",
    action = act.PromptInputLine {
      description = "Rename tab",
      action = wezterm.action_callback(function(window, _, line)
        if line then window:active_tab():set_title(line) end
      end),
    }
  },
  -- Word navigation
  { key = "LeftArrow",  mods = "OPT",       action = act.SendString("\x1bb") },
  { key = "RightArrow", mods = "OPT",       action = act.SendString("\x1bf") },
  -- Pane navigation
  { key = "h",          mods = "CTRL",      action = act.ActivatePaneDirection("Left") },
  { key = "j",          mods = "CTRL",      action = act.ActivatePaneDirection("Down") },
  { key = "k",          mods = "CTRL",      action = act.ActivatePaneDirection("Up") },
  { key = "l",          mods = "CTRL",      action = act.ActivatePaneDirection("Right") },
  { key = "z",          mods = "CMD",       action = act.TogglePaneZoomState },
  { key = "p",          mods = "CMD|SHIFT", action = act.ActivateCommandPalette },
}

return config
