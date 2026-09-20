# goofiest — Fedora KDE Desktop in GitHub Codespaces

Open this repository in a GitHub Codespace and you get a full Fedora KDE
Plasma desktop in your browser, with sudo, no extra setup.

## Quick start

1. On this repo's GitHub page, click **Code → Codespaces → Create codespace
   on main**.
2. Wait for the build. The first build installs the whole KDE Plasma group,
   so expect roughly 5–10 minutes. Later rebuilds are faster.
3. When the Codespace is ready, a notification offers to open the forwarded
   port **6080** ("noVNC Desktop") in your browser — click open, or use the
   **Ports** panel and open port 6080 yourself.
4. The noVNC page asks for a password: it is `password` by default.
5. You are now looking at a KDE Plasma desktop (1920×1080). Do normal
   computer stuff: file manager, terminal, browser, settings, and so on.

The terminal in VS Code and the desktop share the same machine, so files you
create in the desktop appear in `/workspaces/goofiest` (the repo checkout)
and anywhere else in the container.

## Details

- **Base image**: Fedora 44 (`quay.io/fedora/fedora:44`), supported until
  ~May 2027. The old `fedora:40` from the previous repo is end-of-life and
  its dnf mirrors are archived, so the old build no longer works.
- **Desktop**: KDE Plasma on X11. Since Fedora 43, `startplasma-x11` lives in
  the separate `plasma-workspace-x11` package — installed explicitly here.
- **Remote access**: TigerVNC's `Xvnc` serves display `:1`, `websockify`
  bridges it to HTTP on port 6080, and noVNC (served by websockify) renders
  it in the browser. Codespaces can only forward HTTP, which is why the
  browser-facing port is 6080 and not raw VNC 5901.
- **Sudo**: the `vscode` user has passwordless sudo inside the Codespace.

## Customizing

- **VNC password**: edit the `echo "password"` line in
  `.devcontainer/Dockerfile`, then run **Codespaces: Rebuild Container**.
- **Resolution**: edit `-geometry 1920x1080` in `.devcontainer/start-vnc.sh`,
  then rebuild, or run `xrandr -s 1280x1024` inside the desktop for a quick
  change.
- **More packages**: add them to the `dnf install` list in
  `.devcontainer/Dockerfile` and rebuild.

## Troubleshooting

- **Desktop looks black / empty right after a (re)build**: Plasma's first
  start can take a minute or two. If it stays empty, run
  `/home/vscode/start-vnc.sh` once in the VS Code terminal (it is idempotent
  — it only starts what is missing), then reload the browser tab.
- **Port 6080 page loads but shows "connection refused" / black screen**:
  the desktop services may not have started. In the VS Code terminal run
  `/home/vscode/start-vnc.sh` (it is idempotent — it only starts what is
  missing), then reload the browser tab.
- **Desktop gone after the Codespace stopped and restarted**: the start
  script clears stale `/tmp/.X1-lock` files left by an unclean shutdown and
  brings the desktop back on its own; give it a few seconds after the
  container comes up, then reload the tab.
- **Desktop looks frozen after long idle**: Codespaces stops idle containers.
  Restart the Codespace; `postStartCommand` brings the desktop back.
- **Anything else broken**: run **Codespaces: Rebuild Container** for a
  clean rebuild from the Dockerfile.

## Where this came from

Condensed from [`s183173/goofier`](https://github.com/s183173/goofier)
(a fork of the Kasm Workspaces images catalog). Only the Codespaces
devcontainer parts were kept; all Kasm image definitions, CI plumbing, and
docs were dropped.
