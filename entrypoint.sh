#!/bin/bash
set -e

# Setup environment
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

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

# Helper function to run RealityScan with Wine
run_rs() {
    if [ -f "$WINE" ] && [ "$RS_BIN" = "/opt/realityscan/bin/realityscan" ]; then
        # RealityScan on Linux uses Wine
        "$WINE" "$RS_BIN" "$@"
    else
        "$RS_BIN" "$@"
    fi
}

case "$1" in
    server|rest)
        PORT=${RS_REST_PORT:-8080}
        echo "Starting REST server on port $PORT"
        exec run_rs -headless -silent -restServer $PORT
        ;;
    grpc)
        PORT=${RS_GRPC_PORT:-50051}
        echo "Starting gRPC server on port $PORT"
        exec run_rs -headless -silent -grpcServer $PORT
        ;;
    both)
        REST=${RS_REST_PORT:-8080}
        GRPC=${RS_GRPC_PORT:-50051}
        echo "Starting REST ($REST) + gRPC ($GRPC)"
        exec run_rs -headless -silent -restServer $REST -grpcServer $GRPC
        ;;
    gui)
        echo "Starting RealityScan GUI with X11 forwarding..."
        # Start GUI in foreground - container stays alive as long as GUI is running
        exec run_rs
        ;;
    bash|sh)
        exec /bin/bash
        ;;
    *)
        # Default: GUI mode
        echo "Starting RealityScan GUI..."
        exec run_rs
        ;;
esac
