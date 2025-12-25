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
