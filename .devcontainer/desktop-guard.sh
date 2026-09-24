#!/bin/bash
# Self-healing guard for the KDE desktop (run by desktop-guard.timer).
#
# The historical "black noVNC" failure: the systemd --user manager
# (user@1000.service) bounced and took plasmashell/kded6 down with it;
# Xvnc kept running, so the canvas showed the bare painted root window
# forever. With the user-bus xstartup, plasmashell runs as the
# auto-restarting user unit plasma-plasmashell.service, but a full user
# manager stop still leaves the graphical session inactive until the
# desktop service re-logs-in. This guard detects that state and recovers:
#   Xvnc running for > 180s + no plasmashell process
#     -> start user@1000 again (linger makes it cheap)
#     -> restart vnc-desktop.service (xstartup re-adopts systemd startup)
# The 180s grace period keeps it away from legitimate slow first boots
# (Plasma is fully up in well under a minute on a 2-core codespace).
set -u

XPID=$(pgrep -x Xvnc | head -1)
[ -z "$XPID" ] && exit 0                      # no Xvnc: desktop not expected
AGE=$(ps -o etimes= -p "$XPID" 2>/dev/null | tr -d ' ')
[ -z "$AGE" ] && exit 0
[ "$AGE" -lt 180 ] && exit 0                  # startup grace

if pgrep -x plasmashell >/dev/null; then exit 0; fi

echo "[desktop-guard] plasmashell dead while Xvnc up ${AGE}s - recovering desktop"
systemctl start user@1000.service 2>/dev/null || true
sleep 3
systemctl restart vnc-desktop.service
