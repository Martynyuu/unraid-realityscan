#!/bin/bash
set -e

# Setup environment
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

export DISPLAY=:99

# RealityScan binary path
RS_BIN="/opt/realityscan/bin/realityscan"
WINE="/opt/realityscan/bin/wine"

# Auto-install if .deb is mounted
if [ ! -f "$RS_BIN" ] && [ -f /tmp/realityscan.deb ]; then
    echo "Installing RealityScan and dependencies..."
    apt-get update
    dpkg -i /tmp/realityscan.deb || apt-get install -f -y
    rm -rf /var/lib/apt/lists/*
fi

# Check installation
if [ ! -f "$RS_BIN" ]; then
    echo "ERROR: RealityScan not installed"
    echo "Mount installer: -v /path/to/realityscan.deb:/tmp/realityscan.deb"
    exit 1
fi

# Wine prefix setup
export WINEPREFIX=/tmp/wine-realityscan
export WINEDEBUG="-all"

# Start supervisor (manages Xvfb, VNC, websockify)
echo "Starting supervisor (Xvfb + VNC + noVNC)..."
supervisord -c /etc/supervisor/conf.d/realityscan.conf &
sleep 3

# Check if services started
if ! pgrep -x "Xvfb" > /dev/null; then
    echo "ERROR: Xvfb failed to start"
    exit 1
fi
echo "Xvfb running on :99"

if ! pgrep -x "x11vnc" > /dev/null; then
    echo "ERROR: x11vnc failed to start"
    exit 1
fi
echo "VNC server running on port ${VNC_PORT:-5900}"

if ! pgrep -x "websockify" > /dev/null; then
    echo "ERROR: websockify failed to start"
    exit 1
fi
echo "noVNC web server running on port ${VNC_WEB_PORT:-6080}"
echo ""
echo "Access Remote Desktop at: http://<host>:${VNC_WEB_PORT:-6080}"
echo "Password: ${VNC_PASSWORD:-clarity}"
echo ""

case "$1" in
    server|rest)
        PORT=${RS_REST_PORT:-8080}
        echo "Starting REST server on port $PORT"
        if [ -f "$WINE" ]; then
            exec $WINE $RS_BIN -headless -silent -restServer $PORT
        else
            exec $RS_BIN -headless -silent -restServer $PORT
        fi
        ;;
    grpc)
        PORT=${RS_GRPC_PORT:-50051}
        echo "Starting gRPC server on port $PORT"
        if [ -f "$WINE" ]; then
            exec $WINE $RS_BIN -headless -silent -grpcServer $PORT
        else
            exec $RS_BIN -headless -silent -grpcServer $PORT
        fi
        ;;
    both)
        REST=${RS_REST_PORT:-8080}
        GRPC=${RS_GRPC_PORT:-50051}
        echo "Starting REST ($REST) + gRPC ($GRPC)"
        if [ -f "$WINE" ]; then
            exec $WINE $RS_BIN -headless -silent -restServer $REST -grpcServer $GRPC
        else
            exec $RS_BIN -headless -silent -restServer $REST -grpcServer $GRPC
        fi
        ;;
    gui)
        echo "Starting RealityScan GUI (access via http://<host>:${VNC_WEB_PORT:-6080})..."
        sleep 2
        if [ -f "$WINE" ]; then
            exec $WINE $RS_BIN
        else
            exec $RS_BIN
        fi
        ;;
    bash|sh)
        exec /bin/bash
        ;;
    *)
        # Default: GUI mode
        echo "Starting RealityScan GUI (access via http://<host>:${VNC_WEB_PORT:-6080})..."
        sleep 2
        if [ -f "$WINE" ]; then
            exec $WINE $RS_BIN "$@"
        else
            exec $RS_BIN "$@"
        fi
        ;;
esac
