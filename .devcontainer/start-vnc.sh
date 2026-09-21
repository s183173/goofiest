#!/bin/bash
set -u

# Port probes instead of pgrep: a pgrep -f "websockify.*6080" guard matches
# any process whose command line merely mentions those strings (e.g. the
# very shell running this script), which silently skips startup.

# Plasma expects an XDG_RUNTIME_DIR. When the desktop is started by systemd
# (vnc-desktop.service) the variable is not set for system units, so provide
# it best-effort here.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true

# Start the VNC server if nothing is listening on 5901.
if timeout 1 bash -c '</dev/tcp/127.0.0.1/5901' 2>/dev/null; then
    echo "[start-vnc] VNC server already running."
else
    echo "[start-vnc] Starting VNC server on :1 (1920x1080)..."
    # A dead Xvnc leaves /tmp locks behind (unclean container stop/restart),
    # and vncserver then refuses to start even though the port is free.
    # The port probe above proves no server is alive, so they are stale.
    rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 "$HOME"/.vnc/*:1.pid
    vncserver :1 -geometry 1920x1080 -depth 24 -localhost no \
        -xstartup "$HOME/.vnc/xstartup"
fi

# Start the noVNC browser bridge if nothing is listening on 6080.
if timeout 1 bash -c '</dev/tcp/127.0.0.1/6080' 2>/dev/null; then
    echo "[start-vnc] noVNC already running."
else
    echo "[start-vnc] Starting noVNC on port 6080..."
    nohup websockify --web /usr/share/novnc/ 6080 localhost:5901 \
        > /tmp/websockify.log 2>&1 &
    disown
fi
