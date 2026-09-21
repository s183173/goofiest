#!/bin/bash
# container-init.sh — the container's main process (the image CMD).
#
# Goal: boot this devcontainer like a normal Fedora system — systemd as
# PID 1, starting the enabled services (sshd, vnc-desktop, journald, ...)
# exactly like a real machine does on power-on.
#
# GitHub Codespaces are just devcontainers, and the devcontainer spec has
# the two properties this needs:
#     "overrideCommand": false  -> the container's own command (this script)
#                                  is allowed to run as PID 1, instead of
#                                  the tools forcing a sleep loop;
#     "privileged": true        -> the runtime starts the container with
#                                  the capabilities systemd needs.
# With both honoured, this script starts as PID 1 and hands over to the
# real Fedora init.
#
# Prebuilds: the Codespaces prebuild workflow builds the same image and
# boots the same container, but nobody ever attaches to it — the agent
# configures it, stops it and snapshots it into a template. GitHub's
# Codespaces team confirmed CODESPACE_NAME is only set once a *user*
# session exists ("$CODESPACE_NAME is not present during prebuilds",
# community discussion #33731), so it is the honest "is a human expected?"
# signal. Stopping a prebuild container must be instant: the agent's
# shutdown job times out otherwise (systemd-as-PID-1 treats SIGTERM as
# "re-exec yourself" and never dies, which broke prebuilds — job
# 'ShutdownEnvironment' did not succeed). So in prebuilds we deliberately
# stay a plain, fast-dying keep-alive shim, exactly like the platform's
# default; the snapshot then captures a clean, service-free filesystem and
# the next real codespace boots systemd from first start.
#
# Strategy, most- to least-faithful, always keeping the container alive
# (a dead PID 1 would tear the whole codespace down):
#
#   0. No CODESPACE_NAME (prebuild / orchestration) -> plain keep-alive.
#   1. PID 1 and systemd bootable  -> exec systemd: the true Fedora boot.
#   2. PID 1 held by the runtime   -> boot systemd in a nested PID
#      (needs CAP_SYS_ADMIN)          namespace: `systemctl` works and
#                                     vnc-desktop.service drives the
#                                     desktop, but systemd is not the
#                                     container's real init.
#   3. Neither possible            -> stay alive the devcontainer way and
#                                     let the lifecycle hooks start the
#                                     desktop directly (start-desktop.sh
#                                     -> start-vnc.sh), as before.

set -u
export container=docker   # systemd container mode: no udev, no VTs

SYSTEMD=/usr/lib/systemd/systemd
booted() { [ -d /run/systemd/system ]; }

# Diagnostic breadcrumb (stdout lands in prebuild run logs). Uses ${VAR:+set}
# — expands to "set" or nothing, never the value: GITHUB_CODESPACE_TOKEN is
# a secret and must not reach logs.
echo "[container-init] context: CODESPACES=${CODESPACES:+set} CODESPACE_NAME=${CODESPACE_NAME:+set} GITHUB_CODESPACE_TOKEN=${GITHUB_CODESPACE_TOKEN:+set}"

# Creating a PID namespace needs CAP_SYS_ADMIN — exactly what --privileged
# grants. A cheap probe avoids a fatal exec when systemd cannot run here.
can_nest() { unshare --pid --fork --mount-proc true >/dev/null 2>&1; }

# --- Path 0: prebuild / no user session -> plain keep-alive shim ----------
if [ -z "${CODESPACE_NAME:-}" ]; then
    echo "[container-init] no user session (prebuild or local run); staying a plain keep-alive shim so the snapshot stays service-free."
    trap 'exit 0' TERM INT
    while sleep 1000; do :; done
fi

# --- Paths 1-3: a real user session wants the full Fedora boot ------------
if [ "$$" -eq 1 ] && [ -x "$SYSTEMD" ] && can_nest; then
    echo "[container-init] PID 1: exec'ing systemd — real Fedora init..."
    exec "$SYSTEMD" --system --unit=multi-user.target
fi

if can_nest; then
    echo "[container-init] PID 1 held by the runtime; booting systemd in a nested PID namespace..."
    unshare --fork --pid --mount-proc "$SYSTEMD" --system --unit=multi-user.target &
    for _ in $(seq 1 30); do booted && break; sleep 1; done
    if booted; then
        # systemd owns the boot now; the container lives as long as it does.
        while booted; do sleep 10; done
    fi
fi

echo "[container-init] systemd unavailable in this sandbox; keeping the container alive (direct-start mode)."
trap 'exit 0' TERM INT
while sleep 1000; do :; done
