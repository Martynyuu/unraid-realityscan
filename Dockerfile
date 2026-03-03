FROM ubuntu:22.04

LABEL maintainer="Martynyuu"
LABEL description="RealityScan Linux for 3D Photogrammetry Processing (Headless)"
LABEL org.opencontainers.image.source="https://github.com/Martynyuu/unraid-realityscan"

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

# Virtual display settings
ENV DISPLAY=:99
ENV XDG_RUNTIME_DIR=/tmp/runtime-root

# RealityScan settings
ENV RS_REST_PORT=8080
ENV RS_HEADLESS=true

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Basic tools
    curl wget ca-certificates gnupg \
    # Virtual display for headless
    xvfb x11-utils \
    # X11 and display libs
    x11-apps libx11-xcb1 libxcb-shm0 libxcb-dri3-0 \
    libxcomposite1 libxcursor1 libxdamage1 libxfixes3 \
    libxi6 libxrandr2 libxrender1 libxtst6 \
    # GTK and desktop integration
    libgtk-3-0 libdbus-glib-1-2 libxt6 \
    # Vulkan support
    libvulkan1 vulkan-tools mesa-vulkan-drivers \
    # Audio (stub)
    libasound2 libpulse0 \
    # Fonts
    fonts-liberation fonts-dejavu-core \
    # Misc libs
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
    libdrm2 libgbm1 libpango-1.0-0 libcairo2 \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /opt/realityscan \
    && mkdir -p /data/scans \
    && mkdir -p /tmp/runtime-root \
    && chmod 700 /tmp/runtime-root

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose REST API port
EXPOSE 8080

WORKDIR /data/scans

ENTRYPOINT ["/entrypoint.sh"]
CMD ["server"]
