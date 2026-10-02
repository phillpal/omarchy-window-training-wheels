-- teknobu.minimize — append these to ~/.config/hypr/bindings.lua
-- (or let hyprbars/install.sh do it for you).

-- Minimise / restore the focused window into the tray.
o.bind("SUPER + H", "Minimize window", "python3 $HOME/.config/omarchy/plugins/teknobu.minimize/scripts/minimize.py toggle-active")

-- Close window asks "close or minimise?" first (same as the titlebar ×).
-- The Omarchy default SUPER+W closes instantly; unbind it and route through the prompt.
hl.unbind("SUPER + W")
o.bind("SUPER + W", "Close window (confirm)", "python3 $HOME/.config/omarchy/plugins/teknobu.minimize/scripts/minimize.py prompt-close-active")
