# RealityScan render node for Unraid / LumaLod Studio.
#
# Runs RSNode.exe from RealityScan for Linux (Epic's Wine build) so LumaLod Studio talks the same
# RSNode API as to a Windows node. The image contains only the runtime: RealityScan is NOT included
# (the .deb is behind an Epic login and not redistributable). The entrypoint extracts the .deb
# that the user mounts at /installer into /opt/realityscan (a volume) on first start.
#
# Base image and package list follow Epic's "Docker Deployment" page (Ubuntu 22.04, Vulkan, X11 libs).
FROM ubuntu:22.04

ARG INSTALL_BROWSER=1
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# 1) Epic's list.  2) Common Wine runtime libraries.  3) Virtual display, VNC/noVNC, init, tools.
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl wget bzip2 xz-utils x11-apps ca-certificates \
      libgtk-3-0 libdbus-glib-1-2 libxt6 libx11-xcb1 libxcb-shm0 libxcb-dri3-0 libxcomposite1 \
      libvulkan1 vulkan-tools libasound2 \
      libfreetype6 libfontconfig1 fonts-dejavu-core libgnutls30 libgl1 libegl1 libglu1-mesa \
      libnss3 libxrandr2 libxinerama1 libxcursor1 libxi6 libsm6 libxkbcommon0 perl xdg-utils \
      xvfb x11vnc novnc websockify socat tini procps \
    && ln -sf vnc.html /usr/share/novnc/index.html \
    && rm -rf /var/lib/apt/lists/*

# Epic: "Epic login may require installing a browser inside the container". Ubuntu 22.04's
# firefox package is a snap stub, so Firefox comes from Mozilla's APT repository.
# Build with --build-arg INSTALL_BROWSER=0 to leave it out.
RUN if [ "$INSTALL_BROWSER" = 1 ]; then \
      install -d -m 0755 /etc/apt/keyrings \
      && curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg -o /etc/apt/keyrings/packages.mozilla.org.asc \
      && echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
           > /etc/apt/sources.list.d/mozilla.list \
      && printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' > /etc/apt/preferences.d/mozilla \
      && apt-get update && apt-get install -y --no-install-recommends firefox \
      && rm -rf /var/lib/apt/lists/*; \
    fi

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
COPY rsnode-token /usr/local/bin/rsnode-token
RUN chmod 0755 /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/rsnode-token \
    && mkdir -p /config /data /installer /opt/realityscan /host/vulkan/icd.d

# HOME is the persistent appdata volume: RealityScan's Wine prefix (~/.realityscan) and the
# Epic sign-in live there. WINEPREFIX is deliberately not set (bundled launcher decides).
# No VOLUME instruction: the Unraid template maps the paths; VOLUME would leave anonymous volumes.
ENV HOME=/config \
    XDG_RUNTIME_DIR=/tmp/runtime-root \
    BROWSER=firefox \
    WINEDEBUG=-all \
    MODE=rsnode \
    RSNODE_PORT=30010 \
    RSNODE_DATA=/data/sessions \
    RSNODE_ARGS= \
    VNC_PASSWORD= \
    VNC_PORT=5900 \
    NOVNC_PORT=6080 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all

LABEL org.opencontainers.image.title="RealityScan render node (RSNode under Wine)" \
      org.opencontainers.image.description="Runtime for RealityScan for Linux's RSNode.exe as a LumaLod Studio render node on Unraid. RealityScan is not included; mount the .deb from Epic." \
      org.opencontainers.image.source="https://github.com/Martynyuu/unraid-realityscan" \
      org.opencontainers.image.licenses="MIT" \
      maintainer="Martynyuu"

# 30010 RSNode, 6080 noVNC, 5900 VNC, 1234 Remote Command Plugin (MODE=remote)
EXPOSE 30010 6080 5900 1234

HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=3 \
  CMD ["/usr/local/bin/healthcheck.sh"]

WORKDIR /data
# tini -g: signals go to the whole process group (Xvfb, x11vnc, wine, RSNode).
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/entrypoint.sh"]
