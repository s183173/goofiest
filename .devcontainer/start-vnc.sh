#!/bin/bash
set -u

# Start the VNC server if it is not already running.
if ! pgrep -u "$USER" Xvnc > /dev/null; then
    echo "[start-vnc] Starting VNC server on :1 (1920x1080)..."
    vncserver :1 -geometry 1920x1080 -depth 24 -localhost no \
        -xstartup "$HOME/.vnc/xstartup"
else
    echo "[start-vnc] VNC server already running."
fi

# Start the noVNC browser bridge on 6080 if it is not already running.
if ! pgrep -f "websockify.*6080" > /dev/null; then
    echo "[start-vnc] Starting noVNC on port 6080..."
    nohup websockify --web /usr/share/novnc/ 6080 localhost:5901 \
        > /tmp/websockify.log 2>&1 &
    disown
else
    echo "[start-vnc] noVNC already running."
fi

exit 0