# omarchy-window-training-wheels

Windows-style window controls for [Omarchy](https://omarchy.org): titlebar
buttons, minimise-to-tray, and a "did you mean to close?" confirmation.

## What it does

- **Titlebar buttons** — a Windows-style bar on every window with close (red),
  maximise (yellow) and minimise (green) buttons, via the
  [hyprbars](https://github.com/hyprwm/hyprland-plugins) Hyprland plugin.
- **Minimise to a tray** — minimising drops the window into a hidden workspace
  and a preview tray slides up from the bottom of the screen showing a live
  thumbnail of each minimised window. Left-click restores, right-click (or the
  ×) closes, and it fades out when empty. Thumbnails are captured with `grim`
  at the moment of minimise.
- **Close confirmation** — clicking the titlebar × (or pressing `SUPER+W`)
  asks "Did you mean to close or minimise?" before doing anything, so an
  accidental click can't destroy a window. **Minimise** (the default, so Enter
  picks it) parks the window in the tray; **Close** really closes it; **Esc**
  does nothing.

## Install

The tray + close confirmation are an Omarchy shell plugin:

```bash
omarchy plugin add https://github.com/phillpal/omarchy-window-training-wheels.git --enable
```

The Windows-style titlebar is a separate Hyprland-level component (it needs a
compiled plugin). Install it with the bundled script:

```bash
bash ~/.config/omarchy/plugins/teknobu.minimize/hyprbars/install.sh
```

That script installs `hyprland-plugin-hyprbars` from the AUR, drops in the
titlebar config, and wires up the `SUPER+H` / `SUPER+W` keybindings. It's
idempotent — safe to re-run.

## Keybindings

| Keys | Action |
|------|--------|
| `SUPER+H` | Minimise / restore the focused window |
| `SUPER+W` | Close the window (asks for confirmation first) |

The titlebar buttons do the same thing, no keyboard needed.

## How it works

Minimised windows are moved to a hidden `special:minimized` Hyprland workspace.
`scripts/minimize.py` drives that over `hyprctl`; `MinimizeTray.qml` is the
Quickshell overlay that reads the workspace and renders the tray. The close
confirmation uses `omarchy menu select` as a dmenu-style prompt.

## Dependencies

- Omarchy (Hyprland + Quickshell).
- `grim` — for tray thumbnails (ships with Omarchy).
- `hyprland-plugin-hyprbars` (AUR) — only for the titlebar buttons. It is a
  compiled C++ plugin, so it is **version-locked to your Hyprland build**. If
  the titlebar vanishes after an `omarchy update`, re-run
  `omarchy pkg aur add hyprland-plugin-hyprbars` to rebuild it. The tray and
  close confirmation keep working regardless.

## Removal

```bash
# 1. Remove the shell plugin
omarchy plugin remove teknobu.minimize

# 2. If you installed the optional titlebar, undo those steps too:
#    - delete the `require("hypr.hyprbars")` line added to ~/.config/hypr/hyprland.lua
#    - rm ~/.config/hypr/hyprbars.lua
#    - remove the SUPER+H and SUPER+W lines added to ~/.config/hypr/bindings.lua
#    - optionally: omarchy pkg remove hyprland-plugin-hyprbars
```

## License

MIT — see [LICENSE](LICENSE).
