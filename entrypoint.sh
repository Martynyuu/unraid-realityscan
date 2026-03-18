#!/bin/bash
set -e

# Setup environment
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

# Start virtual framebuffer (required by RealityScan)
export DISPLAY=:99

# Kill any existing Xvfb on display 99 or remove stale lock
if pgrep -x "Xvfb" > /dev/null; then
    echo "Killing existing Xvfb process..."
    pkill -x Xvfb || true
    sleep 1
fi

# Remove stale lock file if exists
rm -f /tmp/.X99-lock

Xvfb :99 -screen 0 1024x768x24 -nolisten tcp &
sleep 1

RS_BIN="/opt/realityscan/bin/realityscan"

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

case "$1" in
    server|rest)
        PORT=${RS_REST_PORT:-8080}
        echo "Starting REST server on port $PORT"
        exec $RS_BIN -headless -silent -restServer $PORT
        ;;
    grpc)
        PORT=${RS_GRPC_PORT:-50051}
        echo "Starting gRPC server on port $PORT"
        exec $RS_BIN -headless -silent -grpcServer $PORT
        ;;
    both)
        REST=${RS_REST_PORT:-8080}
        GRPC=${RS_GRPC_PORT:-50051}
        echo "Starting REST ($REST) + gRPC ($GRPC)"
        exec $RS_BIN -headless -silent -restServer $REST -grpcServer $GRPC
        ;;
    bash|sh)
        exec /bin/bash
        ;;
    *)
        exec $RS_BIN -headless -silent "$@"
        ;;
esac
