#!/bin/bash
set -e

# Setup environment
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

# Start virtual display if not running
if ! pgrep -x "Xvfb" > /dev/null; then
    echo "Starting virtual display on :99..."
    Xvfb :99 -screen 0 1920x1080x24 &
    sleep 2
fi

export DISPLAY=:99

# Check for RealityScan installation
RS_BIN="/opt/realityscan/bin/realityscan"

if [ ! -f "$RS_BIN" ]; then
    echo "=============================================="
    echo " RealityScan not installed!"
    echo "=============================================="
    
    if [ -f /tmp/realityscan.deb ]; then
        echo "Found installer, installing..."
        dpkg -i /tmp/realityscan.deb || apt-get install -f -y
        echo "Installation complete!"
    else
        echo ""
        echo " Please mount the .deb installer:"
        echo "   -v /path/to/realityscan.deb:/tmp/realityscan.deb"
        echo ""
        echo " Or run interactively:"
        echo "   docker run -it --entrypoint /bin/bash ..."
        echo "=============================================="
        
        if [ "$1" = "bash" ] || [ "$1" = "sh" ]; then
            exec /bin/bash
        fi
        exit 1
    fi
fi

# Check Vulkan
echo "Checking Vulkan..."
if vulkaninfo --summary 2>/dev/null | grep -q "deviceName"; then
    GPU=$(vulkaninfo --summary 2>/dev/null | grep "deviceName" | head -1 | cut -d= -f2 | xargs)
    echo "GPU: $GPU"
else
    echo "WARNING: No Vulkan GPU detected!"
fi

# Handle commands
case "$1" in
    server|rest)
        # Start RealityScan with REST API server
        PORT=${RS_REST_PORT:-8080}
        echo ""
        echo "=============================================="
        echo " Starting RealityScan REST Server"
        echo " Port: $PORT"
        echo " Headless: true"
        echo "=============================================="
        echo ""
        echo "API Endpoints:"
        echo "  POST /api/align    - Align photos"
        echo "  POST /api/process  - Process model"
        echo "  POST /api/export   - Export model"
        echo "  GET  /api/status   - Get status"
        echo ""
        exec $RS_BIN -headless -silent -restServer $PORT
        ;;
    
    grpc)
        # Start with gRPC server
        PORT=${RS_GRPC_PORT:-50051}
        echo "Starting RealityScan gRPC Server on port $PORT..."
        exec $RS_BIN -headless -silent -grpcServer $PORT
        ;;
    
    process)
        # One-shot processing
        shift
        echo "Processing: $@"
        exec $RS_BIN -headless -silent "$@"
        ;;
    
    align)
        shift
        exec $RS_BIN -headless -silent -align "$@"
        ;;
    
    export)
        shift
        exec $RS_BIN -headless -silent -export "$@"
        ;;
    
    gui)
        # Start with GUI (requires X11 forwarding)
        echo "Starting RealityScan GUI..."
        exec $RS_BIN
        ;;
    
    bash|sh)
        exec /bin/bash
        ;;
    
    *)
        # Pass through to RealityScan
        exec $RS_BIN -headless -silent "$@"
        ;;
esac
