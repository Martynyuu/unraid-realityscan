FROM ubuntu:22.04

LABEL maintainer="Martynyuu"
LABEL description="RealityScan Linux for 3D Photogrammetry Processing"
LABEL org.opencontainers.image.source="https://github.com/Martynyuu/unraid-realityscan"

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Basic tools
    curl wget ca-certificates gnupg \
    # X11 and display
    x11-apps libx11-xcb1 libxcb-shm0 libxcb-dri3-0 \
    libxcomposite1 libxcursor1 libxdamage1 libxfixes3 \
    libxi6 libxrandr2 libxrender1 libxtst6 \
    # GTK and desktop integration
    libgtk-3-0 libdbus-glib-1-2 libxt6 \
    # Vulkan support
    libvulkan1 vulkan-tools mesa-vulkan-drivers \
    # Audio
    libasound2 libpulse0 \
    # Fonts
    fonts-liberation fonts-dejavu-core \
    # Misc libs
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
    libdrm2 libgbm1 libpango-1.0-0 libcairo2 \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /opt/realityscan

# Create user for running the app
RUN useradd -m -s /bin/bash realityscan && \
    mkdir -p /home/realityscan/.config && \
    chown -R realityscan:realityscan /home/realityscan

# Download directory for scans
RUN mkdir -p /data/scans && chown realityscan:realityscan /data/scans

# The RealityScan .deb will be mounted or copied at runtime
# Install script to handle .deb installation
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER realityscan
WORKDIR /home/realityscan

ENTRYPOINT ["/entrypoint.sh"]
CMD ["realityscan"]
