# goofiest — Fedora KDE Desktop in GitHub Codespaces

Open this repository in a GitHub Codespace and you get a full Fedora KDE
Plasma desktop in your browser — the same package set, defaults and
first-login experience as the Fedora KDE Spin, with sudo and systemd, no
extra setup.

## Quick start

1. On this repo's GitHub page, click **Code → Codespaces → Create codespace
   on main**.
2. Wait for the build. The first build installs the whole KDE Plasma
   environment (the same comps environment the Fedora KDE Spin uses), so
   expect roughly 10–20 minutes. Later rebuilds are much faster.
3. When the Codespace is ready, a notification offers to open the forwarded
   port **6080** ("noVNC Desktop") in your browser — click open, or use the
   **Ports** panel and open port 6080 yourself.
4. The noVNC page asks for a password: it is `password` by default.
5. You are now looking at a KDE Plasma desktop (1920×1080). On the first
   login the **KDE Welcome Center** opens, just like on a fresh Fedora KDE
   install — it is the regular onboarding flow, not a custom screen.

The repo checkout lives at `/workspaces/goofiest` (where Codespaces mounts
it), and a `~/goofiest` symlink makes it read like a normal Fedora home
path in the desktop's file manager and terminal.

## Details

- **Base image**: Fedora 44 (`quay.io/fedora/fedora:44`), supported until
  ~May 2027. `os-release` is re-branded like the KDE Spin
  (`Fedora Linux 44 (KDE Plasma)`).
- **Desktop**: the full `@kde-desktop-environment` group — the same package
  set the Fedora KDE Spin installs (Dolphin, Konsole, Spectacle, KDE
  Settings, system tray applets, wallpapers, ...). KDE Plasma runs on X11;
  since Fedora 43 `startplasma-x11` lives in the separate
  `plasma-workspace-x11` package, which is installed explicitly because
  TigerVNC's `Xvnc` needs it.
- **systemd**: this is the one place where a container cannot match a real
  Fedora install. systemd refuses to run as a non-PID-1 process, and GitHub
  Codespace containers run with no capabilities (CapEff=0), a read-only
  cgroup2 mount, and blocked `unshare` — so neither a nested-systemd boot
  nor any other runtime trick can provide real systemd there. The startup
  scripts still *attempt* a nested systemd boot (that works on privileged
  Docker/podman hosts, where `systemctl`, `journalctl` and the enabled
  `vnc-desktop.service` then behave like on any Fedora machine) and fall
  back to starting the desktop directly on Codespaces, with a clear message
  in the log instead of a mysterious failure.
- **Onboarding**: `plasma-welcome` (the KDE Welcome Center) autostarts on
  first login via the stock XDG autostart mechanism.
- **Remote access**: TigerVNC's `Xvnc` serves display `:1`, `websockify`
  bridges it to HTTP on port 6080, and noVNC (served by websockify) renders
  it in the browser. Codespaces can only forward HTTP, which is why the
  browser-facing port is 6080 and not raw VNC 5901.
- **Home folder**: the desktop plumbing (start scripts, systemd unit) lives
  in `/usr/local/bin` and `/etc/systemd/system`, not in `$HOME`, so the
  home folder looks like a fresh Fedora home.
- **Sudo / SSH**: the `vscode` user has passwordless sudo, and the image
  ships `openssh-server` so `gh codespace ssh` works out of the box.

## How the desktop starts

1. Codespaces runs `postStartCommand` → `/usr/local/bin/start-desktop.sh`.
2. `start-desktop.sh` tries to boot systemd (`start-systemd.sh`). On hosts
   that allow it, systemd starts the enabled `vnc-desktop.service`.
3. Where systemd is impossible (GitHub Codespaces — see above), the script
   falls back immediately to `start-vnc.sh` as the `vscode` user.
4. Either way `start-vnc.sh` ends up running `Xvnc :1` (with the stock
   `xstartup`: `dbus-run-session -- startplasma-x11`) and the
   noVNC/websockify bridge, detached so Codespaces cannot reap it.

Everything is idempotent (port probes, not process-name guesses), so it is
safe to re-run on every container start or attach, and the script heals
stale `/tmp/.X1-lock` files after unclean container shutdowns by itself.

## Customizing

- **VNC password**: edit the `echo "password"` line in
  `.devcontainer/Dockerfile`, then run **Codespaces: Rebuild Container**.
- **Resolution**: edit `-geometry 1920x1080` in `.devcontainer/start-vnc.sh`,
  then rebuild, or run `xrandr -s 1280x1024` inside the desktop for a quick
  change.
- **More packages**: add them to the `dnf install` list in
  `.devcontainer/Dockerfile` and rebuild.
- **Services**: enable more units in the Dockerfile (`systemctl enable
  ...`); they start with the nested systemd boot.

## Troubleshooting

- **Desktop looks black / empty right after a (re)build**: Plasma's first
  start can take a minute or two. If it stays empty, run
  `/usr/local/bin/start-desktop.sh` once in the VS Code terminal (it is
  idempotent — it only starts what is missing), then reload the browser tab.
- **Port 6080 page loads but shows "connection refused" / black screen**:
  the desktop services may not have started. In the VS Code terminal run
  `/usr/local/bin/start-desktop.sh`, then reload the browser tab.
- **Desktop gone after the Codespace stopped and restarted**: the start
  script clears stale `/tmp/.X1-lock` files left by an unclean shutdown and
  brings the desktop back on its own; give it a few seconds after the
  container comes up, then reload the tab.
- **Desktop looks frozen after long idle**: Codespaces stops idle containers.
  Restart the Codespace; `postStartCommand` brings the desktop back.
- **`systemctl` says "System has not been booted with systemd"**: expected
  on GitHub Codespaces — their containers cannot run systemd (no
  capabilities, read-only cgroups). Everything else works as usual. On a
  privileged Docker/podman host the same image boots systemd and
  `systemctl`/`journalctl` behave normally.
- **Anything else broken**: run **Codespaces: Rebuild Container** for a
  clean rebuild from the Dockerfile.

## Where this came from

Condensed from [`s183173/goofier`](https://github.com/s183173/goofier)
(a fork of the Kasm Workspaces images catalog). Only the Codespaces
devcontainer parts were kept; all Kasm image definitions, CI plumbing, and
docs were dropped.
