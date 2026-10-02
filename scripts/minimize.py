#!/usr/bin/env python3
"""Minimize helper for the teknobu.minimize Omarchy plugin.

Implements the classic "minimize to a special workspace" pattern for Hyprland
0.56 (Omarchy). The window is moved to the named special workspace
`special:minimized`; restoring moves it back to the workspace it came from.

Commands:
  toggle-active          Toggle minimize/restore for the focused window.
  restore <address>      Restore a specific minimized window (tray left-click).
  close <address>        Gracefully close a specific minimized window (tray right-click).
  list                   Print minimized windows as JSON (debugging aid).

State and previews live under ~/.cache/omarchy-minimize/:
  state.json             { "<address>": {"workspace", "title", "class"} }
  <address>.png          Screenshot captured at the moment of minimize.
"""

import json
import os
import subprocess
import sys

CACHE_DIR = os.path.expanduser("~/.cache/omarchy-minimize")
STATE_PATH = os.path.join(CACHE_DIR, "state.json")
MINIMIZED_WS = "special:minimized"


def _env():
    """Environment for hyprctl: ensure the instance signature is available.

    Hyprland sets HYPRLAND_INSTANCE_SIGNATURE for processes it spawns (so a
    keybinding exec has it), but when run from an arbitrary terminal it may be
    missing. Discover it from the runtime dir socket glob as a fallback.
    """
    env = dict(os.environ)
    if env.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return env
    runtime = env.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    import glob
    socks = glob.glob(f"{runtime}/hypr/*/.socket.sock")
    if socks:
        # path is <runtime>/hypr/<signature>/.socket.sock
        sig = socks[0].split("/")[-2]
        env["HYPRLAND_INSTANCE_SIGNATURE"] = sig
    return env


def hyprctl_json(*args):
    out = subprocess.run(
        ["hyprctl", "-j", *args], env=_env(),
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=5,
    )
    if out.returncode != 0 or not out.stdout:
        return None
    try:
        return json.loads(out.stdout.decode("utf-8", "replace"))
    except Exception:
        return None


def dispatch(lua_expr):
    """Run `hyprctl dispatch <lua dispatcher>` and return the raw output."""
    out = subprocess.run(
        ["hyprctl", "dispatch", lua_expr], env=_env(),
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5,
    )
    txt = (out.stdout or b"") + (out.stderr or b"")
    return txt.decode("utf-8", "replace")


def active_window():
    return hyprctl_json("activewindow")


def focused_workspace_name():
    monitors = hyprctl_json("monitors")
    if not monitors:
        return "1"
    for m in monitors:
        if m.get("focused"):
            aw = m.get("activeWorkspace") or {}
            return str(aw.get("name") or aw.get("id") or "1")
    return "1"


def load_state():
    try:
        with open(STATE_PATH, "r") as f:
            return json.load(f)
    except Exception:
        return {}


def save_state(state):
    os.makedirs(CACHE_DIR, exist_ok=True)
    with open(STATE_PATH, "w") as f:
        json.dump(state, f)


def preview_path(addr):
    return os.path.join(CACHE_DIR, f"{addr}.png")


def capture_preview(addr, at, size):
    """grim -g 'x,y w x h' captures the window's screen region before it hides."""
    if not at or not size:
        return None
    try:
        x, y = int(at[0]), int(at[1])
        w, h = int(size[0]), int(size[1])
        if w <= 0 or h <= 0:
            return None
        geom = f"{x},{y} {w}x{h}"
        out = preview_path(addr)
        subprocess.run(
            ["grim", "-g", geom, "-s", "0.3", "-t", "png", out],
            env=_env(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5,
        )
        if os.path.exists(out) and os.path.getsize(out) > 0:
            return out
    except Exception:
        pass
    return None


def cleanup(addr):
    state = load_state()
    state.pop(addr, None)
    save_state(state)
    try:
        p = preview_path(addr)
        if os.path.exists(p):
            os.remove(p)
    except Exception:
        pass


def is_minimized(win):
    ws = win.get("workspace") or {}
    return str(ws.get("name", "")).startswith("special:")


def minimize(win):
    addr = win["address"]
    origin_ws = str((win.get("workspace") or {}).get("name") or "")
    if origin_ws.startswith("special:"):
        origin_ws = focused_workspace_name()

    preview = capture_preview(addr, win.get("at"), win.get("size"))

    state = load_state()
    state[addr] = {
        "workspace": origin_ws,
        "title": win.get("title", ""),
        "class": win.get("class", ""),
    }
    save_state(state)

    res = dispatch(
        f'hl.dsp.window.move({{ window = "address:{addr}", workspace = "{MINIMIZED_WS}", follow = false }})'
    )
    return res


def restore(addr):
    state = load_state()
    meta = state.get(addr) or {}
    origin = str(meta.get("workspace") or "")
    if not origin or origin.startswith("special:"):
        origin = focused_workspace_name()

    res = dispatch(
        f'hl.dsp.window.move({{ window = "address:{addr}", workspace = "{origin}" }})'
    )
    res2 = dispatch(f'hl.dsp.focus({{ window = "address:{addr}" }})')
    cleanup(addr)
    return res + res2


def close(addr):
    res = dispatch(f'hl.dsp.window.close({{ window = "address:{addr}" }})')
    cleanup(addr)
    return res


def prompt_close_active():
    """Ask "close or minimise?" via the Omarchy menu, then act on the result.

    Used by the titlebar close button so an accidental click doesn't destroy
    the window. The window address is captured BEFORE the menu opens (the menu
    steals focus), and Minimise parks the window in the preview tray.
    """
    win = active_window()
    if not win:
        return ""

    try:
        sel = subprocess.run(
            [
                "omarchy", "menu", "select",
                "Did you mean to close or minimise?",
                "Minimise", "Close",
                "--", "--width", "400",
            ],
            env=_env(), stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            timeout=120,
        )
    except Exception:
        return ""
    if sel.returncode != 0:
        return "cancelled"

    choice = (sel.stdout or b"").decode("utf-8", "replace").strip()
    if choice == "Close":
        return close(win["address"])
    if choice == "Minimise":
        return minimize(win)
    return "cancelled"


def list_minimized():
    clients = hyprctl_json("clients") or []
    out = []
    state = load_state()
    for c in clients:
        if is_minimized(c):
            addr = c.get("address", "")
            out.append({
                "address": addr,
                "title": c.get("title", ""),
                "class": c.get("class", ""),
                "originWorkspace": (state.get(addr) or {}).get("workspace", ""),
                "preview": preview_path(addr) if os.path.exists(preview_path(addr)) else "",
            })
    print(json.dumps(out, indent=2))


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return

    cmd = sys.argv[1]

    if cmd == "list":
        list_minimized()
        return

    if cmd == "toggle-active":
        win = active_window()
        if not win:
            return
        if is_minimized(win):
            restore(win["address"])
        else:
            minimize(win)
        return

    if cmd == "prompt-close-active":
        prompt_close_active()
        return

    if cmd in ("restore", "close") and len(sys.argv) >= 3:
        addr = sys.argv[2]
        if not addr.lower().startswith("0x"):
            addr = "0x" + addr
        if cmd == "restore":
            restore(addr)
        else:
            close(addr)
        return

    print(__doc__)


if __name__ == "__main__":
    main()
