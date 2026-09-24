FROM quay.io/fedora/fedora:44

# The full Fedora KDE Spin desktop. @kde-desktop-environment is the same
# comps environment the official Fedora KDE Spin installs, so the app set,
# wallpapers, system components and defaults match a normal Fedora KDE
# installation instead of a hand-picked minimum.
# Since Fedora 43 the X11 session lives in its own package
# (plasma-workspace-x11); TigerVNC's Xvnc needs startplasma-x11 from it, so
# it stays explicit. openssh-server is what GitHub Codespaces' "gh codespace
# ssh" connects to.
RUN (dnf install -y @kde-desktop-environment \
      || dnf install -y @kde-desktop) \
    && dnf install -y \
    plasma-workspace-x11 \
    tigervnc-server \
    novnc \
    python3-websockify \
    dbus-x11 \
    openssh-server \
    sudo \
    git \
    && dnf clean all

# Fedora-KDE identity extras: the spin's wallpaper and KDE-branded
# os-release (PRETTY_NAME "Fedora Linux 44 (KDE Plasma)"). Tolerant so a
# renamed package can never break the build.
RUN (dnf install -y f44-backgrounds-kde kde-settings || \
     echo "[build] branding extras unavailable, skipping") \
    && dnf clean all

# Keep the KDE Welcome Center (plasma-welcome): it is the Fedora KDE Spin's
# first-boot setup screen. Its kded module (kded_plasma_welcome.so) pops it
# up on the very first Plasma login and records that in the user's config,
# so it appears on first boot and not again — stock Fedora behaviour.
# Ensure no stale "already shown" marker ships in the image so a fresh
# codespace always gets the first-boot setup screen:
RUN rm -f /home/vscode/.config/plasma-welcomerc

# Brand the system like the KDE Spin instead of "Container Image".
RUN sed -i \
      -e 's|^PRETTY_NAME=.*|PRETTY_NAME="Fedora Linux 44 (KDE Plasma)"|' \
      -e 's|^VERSION=.*|VERSION="44 (KDE Plasma)"|' \
      -e 's|^VARIANT=.*|VARIANT="KDE Plasma"|' \
      -e 's|^VARIANT_ID=.*|VARIANT_ID=kde|' \
      /usr/lib/os-release

# sshd host keys so Codespaces can bring up its SSH bridge on connect.
RUN ssh-keygen -A

# Units that cannot work inside a container (no VTs, no hardware audit
# or MCE support) would otherwise show up as failed services and make
# `systemctl is-system-running` report "degraded" instead of "running".
# Mask/disable them quietly.
RUN systemctl mask getty@.service serial-getty@.service \
      auditd.service audit-rules.service mcelog.service 2>/dev/null; \
    systemctl disable sddm.service 2>/dev/null; true

# Non-root user with passwordless sudo (Codespaces-friendly name).
RUN useradd -m -s /bin/bash vscode && \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode && \
    chmod 0440 /etc/sudoers.d/vscode

# Enable lingering for the desktop user. The whole KDE session runs as a
# system service (vnc-desktop.service) out of /run/user/<uid>, but without
# a login session, closing an SSH login used to stop user@<uid>.service
# and try to tear down /run/user/<uid> — the "User Runtime Directory" unit
# then failed (directory still in use by the desktop) and left systemd
# "degraded". With lingering, the user manager is up from first boot,
# `systemctl --user` works in terminals, and the runtime directory is
# never torn down underneath the desktop. enable-linger is just this
# marker file, so it can be created at image build time.
RUN mkdir -p /var/lib/systemd/linger && touch /var/lib/systemd/linger/vscode

# A normal Fedora KDE first boot does not show a lock screen, and a VNC
# session cannot be unlocked through the greeter without a login password
# (with systemd running, kscreenlocker is fully functional and WILL engage).
# Match the first-boot behaviour: no automatic locking. Also give vscode a
# login password ("password", same as the VNC password) so the lock greeter
# stays usable if someone locks the screen by hand.
RUN printf '%s\n' \
    '[Daemon]' \
    'Autolock=false' \
    'LockOnResume=false' \
    > /etc/xdg/kscreenlockerrc && \
    echo "vscode:password" | chpasswd

# Fast first boot on a 2-core codespace. /etc/xdg is KConfig's system-wide
# default layer, so these apply from the very first login (before the user
# has any ~/.config of their own):
# - baloo file indexing off — a first login would otherwise index $HOME and
#   /workspaces, pinning both cores for minutes while the desktop "looks
#   blank".
# - ksplash off — the splash is a QtQuick/OpenGL scene rendered by Xvnc's
#   software rasterizer; it delays the desktop instead of decorating it.
# - kwin compositing off — compositing runs on llvmpipe (software GL), which
#   burns CPU constantly for transparency effects nobody can see over VNC.
# (the plasma-welcome kded module is intentionally NOT disabled: it is what
# shows the Fedora KDE first-boot setup screen the user wants)
# The korgac autostart is removed for the same reason: it pulls in the
# whole akonadi PIM stack on every login (see the akonadiserverrc below).
RUN printf '%s\n' \
      '[Basic Settings]' \
      'Indexing-Enabled=false' \
      > /etc/xdg/baloofilerc && \
    printf '%s\n' \
      '[KSplash][$i]' \
      'Engine=none' \
      'Theme=None' \
      > /etc/xdg/ksplashrc && \
    printf '%s\n' \
      '[Compositing]' \
      'Enabled=false' \
      > /etc/xdg/kwinrc && \
    rm -f /etc/xdg/autostart/org.kde.korgac.desktop

# Codespaces always mounts the repo at /workspaces/<repo>; a symlink makes
# it feel like a normal Fedora home ("my project lives in my home dir").
# VS Code still opens /workspaces/goofiest as the workspace.
RUN ln -sfn /workspaces/goofiest /home/vscode/goofiest

# Boot scripts and the systemd unit that runs the desktop. They live in
# /usr/local/bin (root-owned) instead of $HOME, so the home folder reads
# like a fresh Fedora home: Desktop, Documents, Downloads, ... and nothing
# that belongs to the plumbing.
COPY --chmod=0755 start-vnc.sh /usr/local/bin/start-vnc.sh
COPY --chmod=0755 start-systemd.sh /usr/local/bin/start-systemd.sh
COPY --chmod=0755 start-desktop.sh /usr/local/bin/start-desktop.sh
COPY --chmod=0755 desktop-guard.sh /usr/local/bin/desktop-guard.sh
COPY --chmod=0644 vnc-desktop.service /etc/systemd/system/vnc-desktop.service
COPY --chmod=0644 vnc-novnc.service /etc/systemd/system/vnc-novnc.service
COPY --chmod=0644 desktop-guard.service /etc/systemd/system/desktop-guard.service
COPY --chmod=0644 desktop-guard.timer /etc/systemd/system/desktop-guard.timer
COPY --chmod=0644 polkit-network.rules /etc/polkit-1/rules.d/10-codespaces-network.rules

# Services that a normal Fedora boot starts. This must run as root, so it
# stays above the USER switch.
RUN systemctl enable vnc-desktop.service vnc-novnc.service desktop-guard.timer 2>/dev/null || true

# sshd: a real Fedora service under systemd (Codespaces' SSH bridge can use
# it, and `systemctl status sshd` reads like on a normal machine).
RUN systemctl enable sshd.service 2>/dev/null || true

USER vscode

# No PIM stack. @kde-desktop-environment pulls in akonadi (KDE's personal
# information manager), which — if anything ever activates it — starts a
# private MariaDB server (mysqld) eating hundreds of MB of RAM on a 2-core
# machine. This tells akonadi to never start its server; harmless if the
# user later wants KMail & co. (they can flip this file back).
RUN mkdir -p /home/vscode/.config/akonadi && \
    printf '%s\n' '[Startup]' 'StartServer=false' \
      > /home/vscode/.config/akonadi/akonadiserverrc

# VNC password. Change "password" to something else and rebuild to update.
RUN mkdir -p /home/vscode/.vnc && \
    echo "password" | vncpasswd -f > /home/vscode/.vnc/passwd && \
    chmod 600 /home/vscode/.vnc/passwd

# Launch KDE Plasma (X11) when VNC starts. The xsetroot line paints the
# root window immediately (dark Fedora-blue) so the noVNC canvas visibly
# "connects to something" while Plasma is still booting, instead of
# showing an unpainted black screen.
#
# The session bus choice matters: with the old `dbus-run-session --`
# wrapper Plasma could not see the systemd user manager on its bus and
# silently fell back to "legacy forking mode" — plasmashell/kded6 ran as
# unsupervised forked children, and when user@1000.service ever bounced
# they died with it and NOTHING restarted them, leaving the bare root
# window (the "black noVNC desktop" bug). The desktop user is lingered,
# so /run/user/<uid>/bus (the user manager's own bus, which exposes
# org.freedesktop.systemd1) is always alive: pointing
# DBUS_SESSION_BUS_ADDRESS at it makes Plasma adopt full systemd startup
# and run plasmashell & co. as auto-restarting user units
# (plasma-plasmashell.service ...). The dbus-send probe verifies the bus
# is really alive and keeps the old wrapper as a fallback for sandboxes
# without systemd.
RUN printf '%s\n' \
    '#!/bin/sh' \
    'unset SESSION_MANAGER' \
    "xsetroot -solid '#151e2e' || true" \
    'if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "$XDG_RUNTIME_DIR/bus" ]; then' \
    '    export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"' \
    '    if dbus-send --session --dest=org.freedesktop.DBus --type=method_call --print-reply / org.freedesktop.DBus.ListNames >/dev/null 2>&1; then' \
    '        exec startplasma-x11' \
    '    fi' \
    'fi' \
    'exec dbus-run-session -- startplasma-x11' \
    > /home/vscode/.vnc/xstartup && \
    chmod +x /home/vscode/.vnc/xstartup

EXPOSE 6080

# How "docker stop" asks this container's PID 1 to shut down. systemd's
# canonical power-off signal is SIGRTMIN+3 (SIGTERM means "re-exec yourself"
# to systemd and never stops it — the classic "docker stop hangs on systemd
# containers" trap). With this, any runtime that stops the container
# (Codespaces prebuild snapshots, `gh codespace stop`, local docker) gets a
# clean, fast Fedora shutdown instead of a hang.
STOPSIGNAL SIGRTMIN+3

# The container's main process. With the devcontainer "privileged": true +
# "overrideCommand": false properties honoured, real user sessions boot
# systemd as the true init — a normal Fedora machine power-on. Prebuild
# containers (no user session yet) deliberately stay a keep-alive shim so
# the prebuild snapshot is clean and fast (see container-init.sh).
# It must run as root: system systemd refuses to run as a non-root PID 1.
COPY --chmod=0755 container-init.sh /usr/local/bin/container-init.sh
USER root
CMD ["/usr/local/bin/container-init.sh"]
