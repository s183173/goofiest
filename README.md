# Goofiest — Fedora KDE Plasma desktop in a GitHub Codespace

A full Fedora 44 **KDE Plasma desktop in your browser**, straight from this repo's Codespaces — and it is a *real* Linux boot: **systemd runs as PID 1**, so `systemctl`, `journalctl`, sshd, the VNC services and `systemctl --user` all behave like on a normal Fedora machine.

## Setup

1. **Code → Codespaces → + Create codespace** on this repo.
   - The 2-core machine works fine; 4-core makes the desktop snappier.
2. The first creation **builds the image** (the whole Fedora KDE Spin — about 10 minutes; later creations reuse that build). A [prebuild](https://docs.github.com/en/codespaces/prebuilding-your-devcontainers) makes it near-instant.
3. When the codespace is ready, your browser opens the **noVNC Desktop** port (6080) automatically.
   - **VNC password:** `password`
   - If the tab opens before the port is up, wait a moment and refresh.
4. Done. The repo is checked out at `/workspaces/goofiest` (symlinked as `~/goofiest` on the desktop).

## What you'll see while it boots

The desktop is visible while it loads: seconds after boot the noVNC canvas turns **dark navy** (the X server painting its root window — that means it is alive, not broken), and the full Plasma desktop (wallpaper + taskbar) appears **roughly 15–25 seconds after the container starts**, measured on the 2-core machine with a first boot. A stop/start cycle brings it back just as fast, and `gh codespace stop` shuts it down cleanly (no systemd hang).

`gh codespace ssh` gives you a plain shell if you don't need the desktop (if it times out on a brand-new codespace, open the codespace in the browser once, then retry).

## How it works

- `devcontainer.json` sets `privileged: true` + `overrideCommand: false`, so the image's CMD (`container-init.sh`) runs as **PID 1** and execs the real systemd — a genuine Fedora boot, journald and logind included. Prebuild containers (no user session yet) deliberately stay a plain keep-alive shim so prebuild snapshots stay clean and green.
- The desktop: TigerVNC `Xvnc :1` (1920×1080) runs `startplasma-x11`; websockify + noVNC serve it on port 6080. Everything is a systemd service: `vnc-desktop.service`, `vnc-novnc.service`, `sshd` — and the desktop user is lingered, so `systemctl --user` works from first boot and `systemctl is-system-running` reports `running`.
- Tuned for 2 cores: baloo file indexing, ksplash, kwin compositing, the Welcome Center popup and the akonadi PIM stack (it starts a whole private MariaDB!) are disabled or removed in the image. Undo the `/etc/xdg` preseeds in the Dockerfile if you want stock Fedora behaviour.
