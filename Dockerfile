FROM ubuntu:22.04

LABEL maintainer="Martynyuu"
LABEL description="RealityScan Headless Server - REST/gRPC API"
LABEL org.opencontainers.image.source="https://github.com/Martynyuu/unraid-realityscan"

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

# Headless display
ENV DISPLAY=:99
ENV XDG_RUNTIME_DIR=/tmp/runtime-root

# API settings
ENV RS_REST_PORT=8080
ENV RS_GRPC_PORT=50051

# Install minimal dependencies for headless operation
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Basic tools
    curl wget ca-certificates \
    # Virtual framebuffer (required by Wine/RealityScan)
    xvfb \
    # Minimal X libs (required by RealityScan binaries)
    libx11-6 libxcb1 libxext6 libxrender1 libgl1-mesa-glx \
    # Vulkan runtime
    libvulkan1 vulkan-tools \
    # GTK minimal (required)
    libgtk-3-0 libglib2.0-0 \
    # Other required libs
    libnss3 libasound2 libdrm2 libgbm1 libgl1 libglapi-mesa \
    libatk1.0-0 libatk-bridge2.0-0 libcups2 libxkbcommon0 \
    # Wine dependencies (RealityScan uses Wine on Linux)
    winbind libfontconfig1 libsensors5 \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /opt/realityscan /data/scans /tmp/runtime-root \
    && chmod 700 /tmp/runtime-root
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y \
    wine wine64 wine32
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# REST and gRPC ports
EXPOSE 8080 50051

WORKDIR /data/scans

ENTRYPOINT ["/entrypoint.sh"]
CMD ["server"]
