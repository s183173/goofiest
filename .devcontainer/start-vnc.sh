#!/bin/bash
set -u

# Port probes instead of pgrep: a pgrep -f "websockify.*6080" guard matches
# any process whose command line merely mentions those strings (e.g. the
# very shell running this script), which silently skips startup.

# Plasma needs a writable XDG_RUNTIME_DIR. When the desktop is started by
# Codespaces' lifecycle (postStartCommand) the variable may be unset, and
# /run/user/<uid> may not exist and may not be creatable without sudo.
if [ -z "${XDG_RUNTIME_DIR:-}" ] || [ ! -w "${XDG_RUNTIME_DIR}" ]; then
    RUN_UID="$(id -u)"
    RUN_GID="$(id -g)"
    if sudo mkdir -p "/run/user/$RUN_UID" 2>/dev/null; then
        sudo chown "$RUN_UID:$RUN_GID" "/run/user/$RUN_UID" 2>/dev/null || true
        sudo chmod 700 "/run/user/$RUN_UID" 2>/dev/null || true
        export XDG_RUNTIME_DIR="/run/user/$RUN_UID"
    else
        export XDG_RUNTIME_DIR="$HOME/.runtime"
        mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
        chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
    fi
fi

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
# setsid detaches websockify from this script's session: Codespaces reaps
# the whole process tree of postStartCommand when it exits, and a plain
# "nohup ... &" child dies with it. Xvnc survives on its own because
# vncserver(1) daemonizes properly.
if timeout 1 bash -c '</dev/tcp/127.0.0.1/6080' 2>/dev/null; then
    echo "[start-vnc] noVNC already running."
else
    echo "[start-vnc] Starting noVNC on port 6080..."
    setsid nohup websockify --web /usr/share/novnc/ 6080 localhost:5901 \
        < /dev/null > /tmp/websockify.log 2>&1 &
    disown 2>/dev/null || true
fi
