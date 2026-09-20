FROM quay.io/fedora/fedora:44

# KDE Plasma desktop. Since Fedora 43 the X11 session lives in its own
# package (plasma-workspace-x11); TigerVNC's Xvnc needs startplasma-x11
# from it, so it is installed explicitly.
RUN dnf install -y \
    @kde-desktop \
    plasma-workspace-x11 \
    tigervnc-server \
    novnc \
    python3-websockify \
    dbus-x11 \
    sudo \
    git \
    && dnf clean all

# Non-root user with passwordless sudo (Codespaces-friendly name).
RUN useradd -m -s /bin/bash vscode && \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode && \
    chmod 0440 /etc/sudoers.d/vscode

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

# Browser access: noVNC + websockify on port 6080, started idempotently.
# --chown/--chmod matter: COPY defaults to root ownership, and the later
# devcontainer steps run as "vscode", which cannot chmod a root-owned file.
COPY --chown=vscode:vscode --chmod=0755 start-vnc.sh /home/vscode/start-vnc.sh

EXPOSE 6080
USER vscode
