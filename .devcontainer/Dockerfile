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

# Onboarding: the KDE Welcome Center, which also autostarts on first login
# on a fresh Fedora KDE account. Same tolerant pattern as above.
RUN (dnf install -y plasma-welcome || \
     echo "[build] plasma-welcome unavailable, skipping") \
    && dnf clean all

# Brand the system like the KDE Spin instead of "Container Image".
RUN sed -i \
      -e 's|^PRETTY_NAME=.*|PRETTY_NAME="Fedora Linux 44 (KDE Plasma)"|' \
      -e 's|^VERSION=.*|VERSION="44 (KDE Plasma)"|' \
      -e 's|^VARIANT=.*|VARIANT="KDE Plasma"|' \
      -e 's|^VARIANT_ID=.*|VARIANT_ID=kde|' \
      /usr/lib/os-release

# sshd host keys so Codespaces can bring up its SSH bridge on connect.
RUN ssh-keygen -A

# Units that cannot work inside a container (no VTs) would otherwise show
# up as failed services on `systemctl`; mask/disable them quietly.
RUN systemctl mask getty@.service serial-getty@.service 2>/dev/null; \
    systemctl disable sddm.service 2>/dev/null; true

# Non-root user with passwordless sudo (Codespaces-friendly name).
RUN useradd -m -s /bin/bash vscode && \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode && \
    chmod 0440 /etc/sudoers.d/vscode

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
COPY --chmod=0644 vnc-desktop.service /etc/systemd/system/vnc-desktop.service
COPY --chmod=0644 vnc-novnc.service /etc/systemd/system/vnc-novnc.service

# Services that a normal Fedora boot starts. This must run as root, so it
# stays above the USER switch.
RUN systemctl enable vnc-desktop.service vnc-novnc.service 2>/dev/null || true

# sshd: a real Fedora service under systemd (Codespaces' SSH bridge can use
# it, and `systemctl status sshd` reads like on a normal machine).
RUN systemctl enable sshd.service 2>/dev/null || true

USER vscode

# VNC password. Change "password" to something else and rebuild to update.
RUN mkdir -p /home/vscode/.vnc && \
    echo "password" | vncpasswd -f > /home/vscode/.vnc/passwd && \
    chmod 600 /home/vscode/.vnc/passwd

# Launch KDE Plasma (X11) in its own session D-Bus when VNC starts.
RUN printf '%s\n' \
    '#!/bin/sh' \
    'unset SESSION_MANAGER' \
    'unset DBUS_SESSION_BUS_ADDRESS' \
    'exec dbus-run-session -- startplasma-x11' \
    > /home/vscode/.vnc/xstartup && \
    chmod +x /home/vscode/.vnc/xstartup

EXPOSE 6080

# The container's main process. With the devcontainer "privileged": true +
# "overrideCommand": false properties honoured, this boots systemd as the
# real init — a normal Fedora machine power-on (see container-init.sh). It
# must run as root: system systemd refuses to run as a non-root PID 1.
COPY --chmod=0755 container-init.sh /usr/local/bin/container-init.sh
USER root
CMD ["/usr/local/bin/container-init.sh"]
