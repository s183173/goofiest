#!/bin/bash
# Boots a nested systemd so the container behaves like a real Fedora system:
# `systemctl` works, journald logs, a system D-Bus runs, and enabled units
# (including the vnc-desktop.service that draws the desktop) are started by
# systemd itself, like on any Fedora machine.
#
# systemd insists on being PID 1. Inside a fresh PID namespace created with
# `unshare --pid` it *is* PID 1 — the same thing every container runtime
# does when running a systemd container. Codespace containers are
# privileged, so the namespace and cgroup operations succeed. If systemd
# cannot come up in this sandbox, this script exits non-zero and the caller
# (start-desktop.sh) falls back to starting the desktop directly.
set -u

SYSTEMD=/usr/lib/systemd/systemd
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

# systemd detects "running in a container" through the environment.
# container=docker makes it skip pieces that cannot work here (udev, VT
# consoles, swap) and tolerate a read-only cgroup tree instead of refusing
# to boot.
export container=docker

# Already booted? /run/systemd/system is systemd's "booted" marker.
if [ -d /run/systemd/system ]; then
    echo "[start-systemd] systemd already running."
    exit 0
fi

echo "[start-systemd] Booting systemd (nested container-init)..."
# Preferred: give systemd its own PID namespace so it really is PID 1.
$SUDO env container=docker unshare --fork --pid --mount-proc \
    "$SYSTEMD" --system --unit=multi-user.target \
    > /tmp/systemd-boot.log 2>&1 &
disown 2>/dev/null || true

# Wait for the boot marker (systemd creates /run/systemd/system early).
for _ in $(seq 1 20); do
    [ -d /run/systemd/system ] && break
    sleep 1
done

# Fallback: run systemd directly in this namespace. Newer systemd refuses
# ("Can't run system mode unless PID 1"), but tolerate the attempt.
if [ ! -d /run/systemd/system ]; then
    echo "[start-systemd] unshare attempt failed; trying without a PID namespace..."
    $SUDO env container=docker "$SYSTEMD" --system --unit=multi-user.target \
        > /tmp/systemd-boot.log 2>&1 &
    disown 2>/dev/null || true
    for _ in $(seq 1 15); do
        [ -d /run/systemd/system ] && break
        sleep 1
    done
fi

if [ ! -d /run/systemd/system ]; then
    echo "[start-systemd] systemd did not come up; last log lines:" >&2
    tail -20 /tmp/systemd-boot.log >&2 2>/dev/null || true
    exit 1
fi

# Runtime dir for the desktop session: system units with User= do not get
# one automatically, so create it while we are root-ish.
VSC_UID=$($SUDO id -u vscode 2>/dev/null || echo 1000)
$SUDO mkdir -p "/run/user/$VSC_UID"
$SUDO chown "$VSC_UID:$VSC_UID" "/run/user/$VSC_UID" 2>/dev/null || true
$SUDO chmod 700 "/run/user/$VSC_UID" 2>/dev/null || true

echo "[start-systemd] systemd is up."
exit 0
