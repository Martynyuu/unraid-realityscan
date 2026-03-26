# RealityScan for Unraid (X11 Forwarding)

[![Docker](https://img.shields.io/badge/Docker-ready-blue)](https://hub.docker.com/r/martynyuu/realityscan)
[![Unraid](https://img.shields.io/badge/Unraid-6.10%2B-orange)](https://unraid.net/)

**RealityScan** with X11 forwarding, REST and gRPC APIs for automated 3D photogrammetry processing.

## Features

- 🖥️ **X11 Forwarding** - GUI appears on host display
- 🌐 **REST API** - HTTP endpoints on port 8080
- ⚡ **gRPC API** - High-performance RPC on port 50051
- 🎮 **GPU Accelerated** - Full NVIDIA CUDA/Vulkan support
- 🐳 **Docker Native** - Lightweight, production-ready

## Requirements

- Unraid 6.10+ with Docker
- NVIDIA GPU
- [NVIDIA Driver Plugin](https://forums.unraid.net/topic/98978-plugin-nvidia-driver/)
- [Vulkan Support Plugin](https://github.com/Martynyuu/unraid-vulkan)
- RealityScan Linux .deb from [Epic Games](https://dev.epicgames.com/)

## Quick Start

### 1. Enable X11 Forwarding (Required for GUI)

```bash
# Allow Docker to access X11 display
xhost +local:docker
```

### 2. Start with GUI + X11 Forwarding

**⚠️ IMPORTANT:** Read the Epic Games Docker documentation for proper setup: https://dev.epicgames.com/documentation/en-us/realityscan/docker-deployment

```bash
docker run -it --gpus all \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v /etc/vulkan/icd.d:/etc/vulkan/icd.d:ro \
  -v /usr/share/vulkan/icd.d:/usr/share/vulkan/icd.d:ro \
  -v /dev/dri:/dev/dri \
  -v /mnt/user/scans:/data/scans \
  martynyuu/realityscan:latest
```

### 3. REST API Mode (Headless)

```bash
docker run -d --gpus all \
  -p 8080:8080 \
  -v /mnt/user/scans:/data/scans \
  martynyuu/realityscan:latest server
```

### 4. Both GUI + REST API

```bash
docker run -it --gpus all \
  -p 8080:8080 \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v /etc/vulkan/icd.d:/etc/vulkan/icd.d:ro \
  -v /usr/share/vulkan/icd.d:/usr/share/vulkan/icd.d:ro \
  -v /dev/dri:/dev/dri \
  -v /mnt/user/scans:/data/scans \
  martynyuu/realityscan:latest both
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DISPLAY` | *(required)* | Host X11 display (e.g., `:0`) |
| `RS_REST_PORT` | `8080` | REST API port |
| `RS_GRPC_PORT` | `50051` | gRPC API port |

## Volumes

| Path | Description |
|------|-------------|
| `/tmp/.X11-unix` | X11 socket for GUI |
| `/etc/vulkan/icd.d` | Vulkan ICD config |
| `/usr/share/vulkan/icd.d` | Vulkan ICD config |
| `/dev/dri` | DRM device for GPU |
| `/data/scans` | Working directory for projects |

## Run Modes

| Command | Description |
|---------|-------------|
| *(none)* | GUI mode (default) |
| `gui` | GUI with X11 forwarding |
| `server` / `rest` | REST API on port 8080 |
| `grpc` | gRPC API on port 50051 |
| `both` | GUI + REST + gRPC |
| `bash` | Interactive shell |

## Troubleshooting

### Vulkan Errors

```
ERROR: loader_scanned_icd_add: Could not get 'vkCreateInstance'
```

**Solution:** Mount the correct Vulkan ICD:
```bash
-v /etc/vulkan/icd.d:/etc/vulkan/icd.d:ro \
-v /usr/share/vulkan/icd.d:/usr/share/vulkan/icd.d:ro
```

### DISPLAY Not Set

```
'DISPLAY' environment variable not set... skipping surface info
```

**Solution:** Pass DISPLAY environment variable:
```bash
-e DISPLAY=$DISPLAY
```

### XDG_RUNTIME_DIR Error

```
error: XDG_RUNTIME_DIR is invalid or not set
```

**Solution:** Container sets this automatically. If problems persist, add:
```bash
-e XDG_RUNTIME_DIR=/tmp/runtime-root
```

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

## Support

- [GitHub Issues](https://github.com/Martynyuu/unraid-realityscan/issues)
- [Epic Games Docs](https://dev.epicgames.com/documentation/en-us/realityscan/docker-deployment)
- [Donations](https://ko-fi.com/strudel9)

## License

MIT
