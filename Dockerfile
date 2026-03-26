FROM ubuntu:22.04

LABEL maintainer="Martynyuu"
LABEL description="RealityScan Headless with VNC Remote Desktop"
LABEL org.opencontainers.image.source="https://github.com/Martynyuu/unraid-realityscan"

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

# Virtual display
ENV DISPLAY=:99
ENV XDG_RUNTIME_DIR=/tmp/runtime-root

# VNC settings
ENV VNC_PORT=5900
ENV VNC_WEB_PORT=6080
ENV VNC_PASSWORD=clarity

# API settings
ENV RS_REST_PORT=8080
ENV RS_GRPC_PORT=50051

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Basic tools
    curl wget ca-certificates \
    # Virtual framebuffer (Xvfb for headless GUI)
    xvfb \
    # VNC + Web Remote Desktop
    x11vnc novnc websockify \
    # X libs (required by RealityScan binaries)
    libx11-6 libxcb1 libxext6 libxrender1 libgl1-mesa-glx \
    libxcomposite1 libxrandr2 libxi6 libxcursor1 libxdamage1 \
    libxss1 libxtst6 libxfixes3 libx11-xcb1 libxcb-shm0 libxcb-dri3-0 \
    # Vulkan runtime
    libvulkan1 vulkan-tools \
    # GTK (required by RealityScan GUI)
    libgtk-3-0 libglib2.0-0 \
    # Other required libs
    libnss3 libasound2 libdrm2 libgbm1 libgl1 libglapi-mesa \
    libatk1.0-0 libatk-bridge2.0-0 libcups2 libxkbcommon0 \
    libdbus-1-3 libdbus-glib-1-2 libxt6 \
    # Wine dependencies (RealityScan uses Wine on Linux)
    winbind libfontconfig1 libsensors5 \
    # Supervisor for process management
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Setup noVNC
RUN ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# Create directories
RUN mkdir -p /opt/realityscan /data/scans /tmp/runtime-root /var/log/supervisor \
    && chmod 700 /tmp/runtime-root

# Supervisor config
RUN echo -e "[supervisord]\nnodaemon=true\n\n[xvfb]\nprogram=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp\nautostart=true\nstdout_logfile=/var/log/xvfb.log\nstderr_logfile=/var/log/xvfb.err\n\n[x11vnc]\nprogram=/usr/bin/x11vnc -display :99 -forever -shared -rfbport $VNC_PORT -password $VNC_PASSWORD\nautostart=true\nstdout_logfile=/var/log/x11vnc.log\nstderr_logfile=/var/log/x11vnc.err\n\n[websockify]\nprogram=/usr/bin/websockify --webshare /usr/share/novnc $VNC_WEB_PORT localhost:$VNC_PORT\nautostart=true\nstdout_logfile=/var/log/websockify.log\nstderr_logfile=/var/log/websockify.err" > /etc/supervisor/conf.d/realityscan.conf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Ports
EXPOSE 8080 50051 5900 6080

WORKDIR /data/scans

ENTRYPOINT ["/entrypoint.sh"]
CMD ["gui"]
