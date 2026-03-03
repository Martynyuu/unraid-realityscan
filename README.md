# RealityScan Docker for Unraid

[![Docker](https://img.shields.io/badge/Docker-ready-blue)](https://hub.docker.com/)
[![Unraid](https://img.shields.io/badge/Unraid-6.10%2B-orange)](https://unraid.net/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Run Epic Games' **RealityScan** 3D photogrammetry software on Unraid with full GPU acceleration.

## Features

- 🎮 **GPU Accelerated** - Full NVIDIA CUDA/Vulkan support
- 🐳 **Docker Container** - Isolated, reproducible environment  
- 📦 **Unraid Ready** - Community Apps template included
- 🖥️ **X11 Forwarding** - GUI via VNC or X11

## Requirements

- Unraid 6.10.0 or later
- NVIDIA GPU with CUDA support
- [NVIDIA Driver Plugin](https://forums.unraid.net/topic/98978-plugin-nvidia-driver/)
- [Vulkan Support Plugin](https://github.com/Martynyuu/unraid-vulkan)
- RealityScan Linux installer (.deb) from [Epic Games](https://dev.epicgames.com/documentation/en-us/realityscan)

## Quick Start

### 1. Download RealityScan

Get the Linux .deb installer from Epic Games Developer Portal.

### 2. Run Headless REST Server

```bash
docker run -d --gpus all \
  -p 8080:8080 \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  -v /etc/vulkan/icd.d:/etc/vulkan/icd.d:ro \
  -v /mnt/user/scans:/data/scans \
  -v /path/to/realityscan.deb:/tmp/realityscan.deb \
  --name realityscan \
  martynyuu/realityscan:latest server
```

### 3. Send Commands via REST API

```bash
# Check status
curl http://localhost:8080/api/status

# Align photos
curl -X POST http://localhost:8080/api/align \
  -d '{"project":"/data/scans/my_project"}'

# Process model
curl -X POST http://localhost:8080/api/process

# Export
curl -X POST http://localhost:8080/api/export \
  -d '{"format":"obj","path":"/data/scans/output.obj"}'
```

## Unraid Installation

### Via Community Applications

1. Open **Apps** tab
2. Search for "RealityScan"
3. Click **Install**
4. Configure paths and click **Apply**

### Manual Docker Setup

Add a new container in Unraid with these settings:

| Setting | Value |
|---------|-------|
| Repository | `martynyuu/realityscan:latest` |
| Network Type | `bridge` |
| Extra Parameters | `--gpus all -e NVIDIA_DRIVER_CAPABILITIES=all` |
| /data/scans | `/mnt/user/scans` |
| /tmp/realityscan.deb | Path to your .deb installer |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DISPLAY` | X11 display for GUI | `:0` |
| `NVIDIA_VISIBLE_DEVICES` | GPU selection | `all` |
| `NVIDIA_DRIVER_CAPABILITIES` | Driver features | `all` |

## Volume Mounts

| Container Path | Description |
|----------------|-------------|
| `/data/scans` | Output directory for processed scans |
| `/tmp/realityscan.deb` | RealityScan installer (first run) |
| `/home/realityscan/.config` | App configuration persistence |

## GPU Verification

Inside the container:

```bash
# Check NVIDIA driver
nvidia-smi

# Check Vulkan
vulkaninfo --summary

# Check CUDA
/opt/realityscan/bin/wine CudaDeviceQuery.exe
```

## Troubleshooting

### Black rectangles in dialogs
Press Enter to dismiss - this is a known Wine rendering issue.

### "Cannot create Vulkan instance"
Ensure Vulkan plugin is installed and ICD is mounted:
```bash
-v /etc/vulkan/icd.d:/etc/vulkan/icd.d:ro
```

### Epic Games login issues
The container may need a browser. Install one:
```bash
apt-get install firefox
```

### No GPU detected
Check that NVIDIA Container Toolkit is installed on Unraid:
```bash
nvidia-container-cli info
```

## Building Locally

```bash
git clone https://github.com/Martynyuu/unraid-realityscan.git
cd unraid-realityscan
docker build -t realityscan:latest .
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

- [Epic Games RealityScan](https://www.unrealengine.com/en-US/realityscan)
- [CodeWeavers Wine](https://www.codeweavers.com/)
- Unraid community

## Support

- [GitHub Issues](https://github.com/Martynyuu/unraid-realityscan/issues)
- [Unraid Forums](https://forums.unraid.net/)
- [Donations](https://ko-fi.com/strudel9)
