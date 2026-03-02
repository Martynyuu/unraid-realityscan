#!/bin/bash
set -e

# Check for RealityScan installation
if [ ! -f /opt/realityscan/bin/realityscan ]; then
    echo "=============================================="
    echo " RealityScan not installed!"
    echo ""
    echo " Please mount the .deb installer:"
    echo "   -v /path/to/realityscan.deb:/tmp/realityscan.deb"
    echo ""
    echo " Then run: dpkg -i /tmp/realityscan.deb"
    echo "=============================================="
    
    # Check if installer is mounted
    if [ -f /tmp/realityscan.deb ]; then
        echo "Found installer at /tmp/realityscan.deb"
        echo "Installing RealityScan..."
        sudo dpkg -i /tmp/realityscan.deb || sudo apt-get install -f -y
        echo "Installation complete!"
    else
        echo "Waiting for manual installation..."
        exec /bin/bash
    fi
fi

# Check Vulkan availability
echo "Checking Vulkan..."
if command -v vulkaninfo &> /dev/null; then
    GPU_NAME=$(vulkaninfo --summary 2>/dev/null | grep "deviceName" | head -1 | cut -d= -f2 | xargs)
    if [ -n "$GPU_NAME" ]; then
        echo "GPU detected: $GPU_NAME"
    else
        echo "WARNING: No Vulkan GPU detected!"
    fi
fi

# Handle commands
case "$1" in
    realityscan)
        echo "Starting RealityScan..."
        exec /opt/realityscan/bin/realityscan "${@:2}"
        ;;
    bash|sh)
        exec /bin/bash
        ;;
    *)
        exec "$@"
        ;;
esac
