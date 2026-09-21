#!/bin/bash
# Brings the desktop up, preferring the systemd path — the closest thing to
# a real Fedora boot, where systemd starts the display session. If systemd
# cannot run in this sandbox, fall back to starting the VNC stack directly.
# Both paths are idempotent, so this is safe to run on every start/attach.
set -u

if /usr/local/bin/start-systemd.sh; then
    # vnc-desktop.service is enabled at build time, so the nested systemd
    # boot should have started it. Wait for the VNC port, then leave.
    for _ in $(seq 1 20); do
        timeout 1 bash -c '</dev/tcp/127.0.0.1/5901' 2>/dev/null && exit 0
        sleep 2
    done
    echo "[start-desktop] systemd did not bring the desktop up; starting directly."
fi

exec /usr/local/bin/start-vnc.sh
