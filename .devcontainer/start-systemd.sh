#!/bin/bash
# Attempts to boot systemd so `systemctl` behaves like on a real Fedora
# system, with the desktop started by vnc-desktop.service.
#
# HONEST LIMITATION: GitHub Codespace containers run with no effective
# capabilities (CapEff=0), a read-only cgroup2 mount, and seccomp-blocked
# unshare — verified empirically. systemd refuses to run as a non-PID1
# process ("Can't run system mode unless PID 1"), and creating a PID
# namespace (the way container runtimes give systemd a PID 1) requires
# CAP_SYS_ADMIN, which these containers do not have. So on GitHub
# Codespaces this script always fast-fails, and start-desktop.sh falls back
# to starting the VNC stack directly. On other devcontainer hosts (plain
# Docker with --privileged, podman, ...) the nested-systemd boot below
# DOES work and is used.
#
# If systemd boots, vnc-desktop.service (enabled in the image) starts the
# desktop; otherwise the caller handles it. Either way this exits quickly.
set -u

SYSTEMD=/usr/lib/systemd/systemd
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

# Already booted? /run/systemd/system is systemd's "booted" marker.
if [ -d /run/systemd/system ]; then
    echo "[start-systemd] systemd already running."
    exit 0
fi

# Fast pre-flight: can we create a PID namespace at all? (needs
# CAP_SYS_ADMIN; GitHub Codespaces: no.) This avoids the pointless
# wait-and-retry cycle when the answer is a hard no.
if ! $SUDO unshare --pid --fork /bin/true >/dev/null 2>&1; then
    echo "[start-systemd] This container cannot run systemd:"
    echo "[start-systemd]   no CAP_SYS_ADMIN / unshare blocked and systemd"
    echo "[start-systemd]   refuses to run as a non-PID1 process."
    echo "[start-systemd] Falling back to direct desktop startup."
    # Make sure the session runtime dir exists even on this path.
    VSC_UID="$(id -u vscode 2>/dev/null || echo 1000)"
    $SUDO mkdir -p "/run/user/$VSC_UID" 2>/dev/null || true
    $SUDO chown "$VSC_UID:$VSC_UID" "/run/user/$VSC_UID" 2>/dev/null || true
    $SUDO chmod 700 "/run/user/$VSC_UID" 2>/dev/null || true
    exit 1
fi

# systemd detects "running in a container" through the environment.
# container=docker makes it skip pieces that cannot work here (udev, VT
# consoles, swap) and tolerate a read-only cgroup tree instead of refusing
# to boot.
export container=docker

echo "[start-systemd] Booting systemd (nested container-init)..."
$SUDO env container=docker unshare --fork --pid --mount-proc \
    "$SYSTEMD" --system --unit=multi-user.target \
    > /tmp/systemd-boot.log 2>&1 &
disown 2>/dev/null || true

# Wait for the boot marker (systemd creates /run/systemd/system early).
for _ in $(seq 1 20); do
    [ -d /run/systemd/system ] && break
    sleep 1
done

if [ ! -d /run/systemd/system ]; then
    echo "[start-systemd] systemd did not come up; last log lines:" >&2
    tail -5 /tmp/systemd-boot.log >&2 2>/dev/null || true
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
