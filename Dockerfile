FROM ubuntu:22.04

LABEL maintainer="Martynyuu"
LABEL description="RealityScan with X11 Forwarding - REST/gRPC API"
LABEL org.opencontainers.image.source="https://github.com/Martynyuu/unraid-realityscan"

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

# API settings
ENV RS_REST_PORT=8080
ENV RS_GRPC_PORT=50051

# Install dependencies for X11 forwarding (per Epic Docs)
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Basic tools
    curl wget bzip2 xz-utils x11-apps ca-certificates \
    # X11 forwarding libs (required by RealityScan binaries)
    libgtk-3-0 libdbus-glib-1-2 libxt6 \
    libx11-xcb1 libxcb-shm0 libxcb-dri3-0 \
    libxcomposite1 libasound2 libxi6 libxcursor1 \
    # Vulkan runtime
    libvulkan1 vulkan-tools \
    # Other required libs
    libnss3 libdrm2 libgbm1 libgl1 libglapi-mesa \
    libatk1.0-0 libatk-bridge2.0-0 libcups2 libxkbcommon0 \
    # Wine dependencies (RealityScan uses Wine on Linux)
    winbind libfontconfig1 libsensors5 \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /opt/realityscan /data/scans /tmp/runtime-root \
    && chmod 700 /tmp/runtime-root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# REST and gRPC ports
EXPOSE 8080 50051

WORKDIR /data/scans

ENTRYPOINT ["/entrypoint.sh"]
CMD ["gui"]
