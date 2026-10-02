-- hyprbars: Windows-style window titlebar with close / maximise / minimise buttons.
-- Part of the teknobu.minimize plugin (Omarchy shell plugin).
-- Theme: Minecraft (accent #5cbf40 grass, background #1c1f1a, foreground #e8e6dc).
--
-- Requires the hyprland-plugin-hyprbars AUR package (compiled against your
-- Hyprland build). See the README / hyprbars/install.sh for the one-shot setup.

local HYPRBARS_PATH = "/usr/lib/libhyprbars.so"

-- The shell plugin installs to ~/.config/omarchy/plugins/teknobu.minimize/.
local MINIMIZE_SCRIPT =
  "$HOME/.config/omarchy/plugins/teknobu.minimize/scripts/minimize.py"

-- Declare the plugin on every config pass. Hyprland loads it after the first
-- pass, then reloads config so its options and add_button become available.
hl.plugin.load(HYPRBARS_PATH)

local hyprbars_loaded = false
for _, plugin in ipairs(hl.get_loaded_plugins()) do
  if plugin.name == "hyprbars" then
    hyprbars_loaded = true
    break
  end
end

if hyprbars_loaded then
  hl.config({
    plugin = {
      hyprbars = {
        bar_color = "rgb(1c1f1a)",
        bar_height = 36,
        col = { text = "rgb(e8e6dc)" },
        bar_text_size = 13,
        bar_text_font = "Sans",
        bar_text_align = "center",
        bar_buttons_alignment = "right",
        bar_part_of_window = 1,
        bar_precedence_over_border = 0,
        bar_padding = 10,
        bar_button_padding = 8,
        icon_on_hover = true,
      },
    },
  })

  local minimize_cmd = "python3 " .. MINIMIZE_SCRIPT .. " toggle-active"
  local close_cmd = "python3 " .. MINIMIZE_SCRIPT .. " prompt-close-active"

  -- Buttons are added left-to-right but rendered right-to-left, so the first
  -- added is the rightmost: close, maximise, minimise.
  -- Close asks "close or minimise?" first, so an accidental click can't
  -- destroy the window.
  hl.plugin.hyprbars.add_button({
    bg_color = "rgb(b02e26)", -- Minecraft redstone: close
    fg_color = "rgb(ffffff)",
    size = 12,
    icon = "×",
    action = close_cmd,
  })

  hl.plugin.hyprbars.add_button({
    bg_color = "rgb(f5d532)", -- Minecraft gold: maximise
    fg_color = "rgb(000000)",
    size = 12,
    icon = "□",
    action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
  })

  hl.plugin.hyprbars.add_button({
    bg_color = "rgb(5cbf40)", -- Minecraft grass: minimise
    fg_color = "rgb(000000)",
    size = 12,
    icon = "–",
    action = minimize_cmd,
  })
end
