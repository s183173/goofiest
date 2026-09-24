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

The desktop is visible while it loads: seconds after boot the noVNC canvas turns **dark navy** (the X server painting its root window — that means it is alive, not broken), and the full Plasma desktop (wallpaper + taskbar) appears **roughly 10–20 seconds after the container starts** (measured at 8.9s to multi-user on a fresh 2-core boot), measured on the 2-core machine with a first boot. The **Fedora 44 KDE first-boot setup** — the KDE Welcome Center — pops up on the desktop during that first boot, exactly like a freshly installed Fedora KDE Spin; close it and carry on, it won't show again. A stop/start cycle brings it back just as fast, and `gh codespace stop` shuts it down cleanly (no systemd hang).

`gh codespace ssh` gives you a plain shell if you don't need the desktop (if it times out on a brand-new codespace, open the codespace in the browser once, then retry).

## How it works

- `devcontainer.json` sets `privileged: true` + `overrideCommand: false`, so the image's CMD (`container-init.sh`) runs as **PID 1** and execs the real systemd — a genuine Fedora boot, journald and logind included. Prebuild containers (no user session yet) deliberately stay a plain keep-alive shim so prebuild snapshots stay clean and green.
- The desktop: TigerVNC `Xvnc :1` (1920×1080) runs `startplasma-x11` **on the lingered user manager's bus**, so Plasma adopts full systemd startup — `plasma-plasmashell.service` and the other session parts run as auto-restarting `systemctl --user` units, exactly like a normal Fedora login (the old `dbus-run-session` wrapper silently degraded to unsupervised "legacy forking mode", which is what caused the black-desktop-after-user-manager-bounce bug). websockify + noVNC serve it on port 6080; everything is a systemd service (`vnc-desktop.service`, `vnc-novnc.service`, `sshd`, `desktop-guard.timer`), the desktop user is lingered, and `systemctl is-system-running` reports `running`.
- Self-healing: `desktop-guard.timer` runs a guard every 45s — if Xvnc has been up for 3+ minutes but plasmashell is gone (the historical black-desktop failure mode), it brings the user manager back and restarts `vnc-desktop.service`. A polkit rule lets the desktop user manage network connections without the "Authentication Required" popup (the VNC session is not a logind-active session).
- Tuned for 2 cores: baloo file indexing, ksplash, kwin compositing and the akonadi PIM stack (it starts a whole private MariaDB!) are disabled in the image. The **Welcome Center IS kept**: it is the Fedora KDE first-boot setup screen, so your first login pops it up just like a real Fedora 44 KDE install (it will not re-appear afterwards unless you run `plasma-welcome`). Undo the `/etc/xdg` preseeds in the Dockerfile if you want stock Fedora behaviour everywhere else.
