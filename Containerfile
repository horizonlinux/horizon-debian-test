# Allow build scripts to be referenced without being copied into the final image
ARG BUILD_ARCH="${BUILD_PLATFORM:-}"
FROM scratch AS ctx
COPY build_files /

# Base Debian Image
FROM docker.io/library/debian:testing

COPY system_files /

ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_ID=${BUILD_ID}
ARG BUILD_ARCH="${BUILD_PLATFORM:-}"
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=cache,dst=/var/lib/apt \
    --mount=type=cache,dst=/var/lib/dpkg/updates \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/install-bootloader && \
    /ctx/install-bootc && \
    /ctx/build && \
    apt install -y kde-plasma-desktop sddm flatpak && \
    systemctl enable sddm

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=cache,dst=/var/lib/apt \
    --mount=type=cache,dst=/var/lib/dpkg/updates \
    --mount=type=tmpfs,dst=/tmp \
    useradd -m --shell=/bin/bash build && usermod -L build && \
    cp /etc/sudoers /etc/sudoers.bak && \
    echo "build ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER build
WORKDIR /home/build
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=cache,dst=/var/lib/apt \
    --mount=type=cache,dst=/var/lib/dpkg/updates \
    --mount=type=tmpfs,dst=/tmp \
    apt install -y \
        libgcc-s1 \
        libc6 \
        libqt6core6 \
        libqt6gui6 \
        libqt6widgets6 \
        libqt6qml6 \
        libqt6quick6 \
        libqt6svg6 \
        libkf6auth6 \
        libkf6coreaddons6 \
        libkf6i18n6 \
        libkf6package6 \
        libkf6config6 \
        libkf6screen6 \
        libkf6windowsystem6 \
        libkf6plasma-dev \
        kf6-plasma-dev \
        plasma-desktop && \
    apt install -y \
        git \
        cmake \
        extra-cmake-modules \
        pkgconf \
        gettext && \
	git clone https://invent.kde.org/plasma/plasma-setup.git /tmp/kiss && \
    cd /tmp/kiss && \ 
    cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr && \
    cmake --build build
USER root
WORKDIR /

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=cache,dst=/var/lib/apt \
    --mount=type=cache,dst=/var/lib/dpkg/updates \
    --mount=type=tmpfs,dst=/tmp \
    userdel build && mv /etc/sudoers.bak /etc/sudoers && \
    apt autoremove -y \
        git \
        cmake \
        extra-cmake-modules

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=cache,dst=/var/lib/apt \
    --mount=type=cache,dst=/var/lib/dpkg/updates \
    --mount=type=tmpfs,dst=/tmp \
    systemd-sysusers && \
    sed -i '/Current=/c\Current=breeze' /usr/lib/sddm/sddm.conf.d/default.conf && \
    sed -i '/CursorSize=/c\CursorSize=24' /usr/lib/sddm/sddm.conf.d/default.conf && \
    sed -i '/CursorTheme=/c\CursorTheme=breeze_cursors' /usr/lib/sddm/sddm.conf.d/default.conf && \
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && \
    systemctl disable systemd-firstboot && \
    systemctl enable plasma-setup.service && \
    /ctx/shared/build-initramfs && \
    /ctx/shared/finalize

# DEBUGGING
# RUN apt update -y && apt install -y whois
RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

# Lint
RUN bootc container lint
