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

# Find the RemoteCommandPlugin (multiple possible locations)
RS_PLUGIN=""
for plugin_path in \
    "/opt/realityscan/support/realityscan/drive_c/Program Files/Epic Games/RealityScan/Plugins/RealityScan.RemoteCommandPlugin/RealityScan.RemoteCommandPlugin.rsplugin" \
    "/opt/realityscan/support/realityscan/drive_c/Program\ Files/Epic\ Games/RealityScan/Plugins/RealityScan.RemoteCommandPlugin/RealityScan.RemoteCommandPlugin.rsplugin" \
    "/opt/realityscan/bin/Plugins/RealityScan.RemoteCommandPlugin/RealityScan.RemoteCommandPlugin.rsplugin"
do
    if [ -f "$plugin_path" ]; then
        RS_PLUGIN="$plugin_path"
        echo "Found plugin: $RS_PLUGIN"
        break
    fi
done

if [ -z "$RS_PLUGIN" ]; then
    echo "WARNING: RemoteCommandPlugin not found"
    echo "Searching for .rsplugin files..."
    find /opt/realityscan -name "*.rsplugin" 2>/dev/null || true
    echo "REST/gRPC APIs may not work without the plugin"
fi

# Generate unique instance name
INSTANCE_NAME="rs_$$"

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
        echo "Starting RealityScan with REST server on port $PORT"
        echo "Instance name: $INSTANCE_NAME"
        
        # Start RealityScan instance with plugin registered
        if [ -n "$RS_PLUGIN" ]; then
            run_rs -setInstanceName "$INSTANCE_NAME" -registerPlugin "$RS_PLUGIN" -headless -silent &
        else
            run_rs -setInstanceName "$INSTANCE_NAME" -headless -silent &
        fi
        sleep 15
        
        # Delegate to instance and start REST server
        exec run_rs -delegateTo "$INSTANCE_NAME" -RsRemoteStartREST "http://0.0.0.0:$PORT"
        ;;
    grpc)
        PORT=${RS_GRPC_PORT:-50051}
        echo "Starting RealityScan with gRPC server on port $PORT"
        echo "Instance name: $INSTANCE_NAME"
        
        # Start RealityScan instance with plugin registered
        if [ -n "$RS_PLUGIN" ]; then
            run_rs -setInstanceName "$INSTANCE_NAME" -registerPlugin "$RS_PLUGIN" -headless -silent &
        else
            run_rs -setInstanceName "$INSTANCE_NAME" -headless -silent &
        fi
        sleep 15
        
        # Delegate to instance and start gRPC server
        exec run_rs -delegateTo "$INSTANCE_NAME" -RsRemoteStartGRPC "0.0.0.0:$PORT"
        ;;
    both)
        REST=${RS_REST_PORT:-8080}
        GRPC=${RS_GRPC_PORT:-50051}
        echo "Starting RealityScan with REST ($REST) + gRPC ($GRPC)"
        echo "Instance name: $INSTANCE_NAME"
        
        # Start RealityScan instance with plugin registered
        if [ -n "$RS_PLUGIN" ]; then
            run_rs -setInstanceName "$INSTANCE_NAME" -registerPlugin "$RS_PLUGIN" -headless -silent &
        else
            run_rs -setInstanceName "$INSTANCE_NAME" -headless -silent &
        fi
        sleep 15
        
        # Start REST server in background
        run_rs -delegateTo "$INSTANCE_NAME" -RsRemoteStartREST "http://0.0.0.0:$REST" &
        sleep 2
        
        # Start gRPC server as main process
        exec run_rs -delegateTo "$INSTANCE_NAME" -RsRemoteStartGRPC "0.0.0.0:$GRPC"
        ;;
    bash|sh)
        exec /bin/bash
        ;;
    *)
        exec run_rs -headless -silent "$@"
        ;;
esac
