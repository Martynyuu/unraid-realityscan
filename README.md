# RealityScan for Unraid (Headless with VNC)

[![Docker](https://img.shields.io/badge/Docker-ready-blue)](https://hub.docker.com/r/martynyuu/realityscan)
[![Unraid](https://img.shields.io/badge/Unraid-6.10%2B-orange)](https://unraid.net/)

**RealityScan** headless server with VNC remote desktop, REST and gRPC APIs.

## Features

- 🖥️ **VNC Remote Desktop** - Access GUI via browser (noVNC on port 6080)
- 🌐 **REST API** - HTTP endpoints on port 8080
- ⚡ **gRPC API** - High-performance RPC on port 50051
- 🎮 **GPU Accelerated** - Full NVIDIA CUDA/Vulkan support
- 🐳 **Docker Native** - Production-ready for Unraid

## Requirements

- Unraid 6.10+ with Docker
- NVIDIA GPU
- [NVIDIA Driver Plugin](https://forums.unraid.net/topic/98978-plugin-nvidia-driver/)
- [Vulkan Support Plugin](https://github.com/Martynyuu/unraid-vulkan)
- RealityScan Linux .deb from [Epic Games](https://dev.epicgames.com/)

## Quick Start

### Start with Remote Desktop (default)

```bash
docker run -d --gpus all \
  -p 6080:6080 \
  -p 5900:5900 \
  -v /etc/vulkan/icd.d:/etc/vulkan/icd.d:ro \
  -v /usr/share/vulkan/icd.d:/usr/share/vulkan/icd.d:ro \
  -v /dev/dri:/dev/dri \
  -v /mnt/user/scans:/data/scans \
  -v /mnt/user/realityscan.deb:/tmp/realityscan.deb \
  -v /usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.0:/usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.0:ro \
  -v /usr/lib/x86_64-linux-gnu/libEGL_nvidia.so.0:/usr/lib/x86_64-linux-gnu/libEGL_nvidia.so.0:ro \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  --name realityscan \
  martynyuu/realityscan:latest
```

**Access Remote Desktop:**
- Browser: `http://<unraid-ip>:6080`
- VNC Client: `<unraid-ip>:5900`
- **Password:** `clarity` (change with `-e VNC_PASSWORD`)

### REST API Mode (Headless only)

```bash
docker run -d --gpus all \
  -p 8080:8080 \
  -v /mnt/user/scans:/data/scans \
  -v /mnt/user/realityscan.deb:/tmp/realityscan.deb \
  martynyuu/realityscan:latest server
```

### Both GUI + REST API

```bash
docker run -d --gpus all \
  -p 6080:6080 \
  -p 8080:8080 \
  -v /mnt/user/scans:/data/scans \
  -v /mnt/user/realityscan.deb:/tmp/realityscan.deb \
  martynyuu/realityscan:latest both
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VNC_PORT` | `5900` | VNC server port |
| `VNC_WEB_PORT` | `6080` | noVNC web port |
| `VNC_PASSWORD` | `clarity` | VNC password |
| `RS_REST_PORT` | `8080` | REST API port |
| `RS_GRPC_PORT` | `50051` | gRPC API port |

## Volumes

| Path | Description |
|------|-------------|
| `/etc/vulkan/icd.d` | Vulkan ICD config |
| `/usr/share/vulkan/icd.d` | Vulkan ICD config |
| `/dev/dri` | DRM device for GPU |
| `/data/scans` | Working directory |
| `/tmp/realityscan.deb` | Installer (first run only) |
| `/usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.0` | NVIDIA lib (required) |
| `/usr/lib/x86_64-linux-gnu/libEGL_nvidia.so.0` | NVIDIA lib (required) |

## Run Modes

| Command | Description |
|---------|-------------|
| *(none)* | GUI with VNC (default) |
| `gui` | GUI with VNC remote desktop |
| `server` / `rest` | REST API only (no GUI) |
| `grpc` | gRPC API only (no GUI) |
| `both` | GUI + REST + gRPC |
| `bash` | Interactive shell |

## API Reference

### REST Endpoints

```
GET  /api/status              - Server status
POST /api/align               - Align photos
POST /api/process             - Generate model
POST /api/export              - Export model
POST /api/abort               - Abort current task
GET  /api/progress            - Task progress
```

## Troubleshooting

### Vulkan Errors

```
ERROR: loader_scanned_icd_add: Could not get 'vkCreateInstance'
```

**Solution:** Mount NVIDIA libraries:
```bash
-v /usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.0:/usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.0:ro \
-v /usr/lib/x86_64-linux-gnu/libEGL_nvidia.so.0:/usr/lib/x86_64-linux-gnu/libEGL_nvidia.so.0:ro
```

### VNC not accessible

Check if ports are open:
```bash
docker port realityscan
```

Should show `6080/tcp` and `5900/tcp`.

## Support

- [GitHub Issues](https://github.com/Martynyuu/unraid-realityscan/issues)
- [Epic Games Docs](https://dev.epicgames.com/documentation/en-us/realityscan/docker-deployment)
- [Donations](https://ko-fi.com/strudel9)

## License

MIT
