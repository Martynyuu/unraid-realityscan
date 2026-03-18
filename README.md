# RealityScan Headless Server for Unraid

[![Docker](https://img.shields.io/badge/Docker-ready-blue)](https://hub.docker.com/r/martynyuu/realityscan)
[![Unraid](https://img.shields.io/badge/Unraid-6.10%2B-orange)](https://unraid.net/)

Headless **RealityScan** server with REST and gRPC APIs for automated 3D photogrammetry processing.

## Features

- 🖥️ **Fully Headless** - No GUI, no X11 forwarding needed
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

### 1. Start REST Server (with GPU passthrough)

**⚠️ CRITICAL:** RealityScan requires NVIDIA library mappings for Vulkan/CUDA to work in Docker.

```bash
# First, find your NVIDIA lib paths:
ls /usr/lib/x86_64-linux-gnu/libGLX_nvidia.so*
ls /usr/lib/x86_64-linux-gnu/libEGL_nvidia.so*

# Then run with required mounts:
docker run -d --gpus all \
  -p 8080:8080 \
  -v /etc/vulkan/icd.d:/etc/vulkan/icd.d:ro \
  -v /usr/share/vulkan/icd.d:/usr/share/vulkan/icd.d:ro \
  -v /dev/dri:/dev/dri \
  -v /mnt/user/scans:/data/scans \
  -v /mnt/user/realityscan.deb:/tmp/realityscan.deb \
  -v /usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.0:/usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.0:ro \
  -v /usr/lib/x86_64-linux-gnu/libEGL_nvidia.so.0:/usr/lib/x86_64-linux-gnu/libEGL_nvidia.so.0:ro \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  --name realityscan \
  martynyuu/realityscan:latest server
```

### 2. Use the API

```bash
# Status
curl http://localhost:8080/api/status

# Align
curl -X POST http://localhost:8080/api/align \
  -H "Content-Type: application/json" \
  -d '{"project":"/data/scans/my_project"}'

# Process
curl -X POST http://localhost:8080/api/process

# Export
curl -X POST http://localhost:8080/api/export \
  -d '{"format":"obj"}'
```

## Run Modes

| Command | Description |
|---------|-------------|
| `server` / `rest` | REST API on port 8080 (default) |
| `grpc` | gRPC API on port 50051 |
| `both` | REST + gRPC simultaneously |
| `bash` | Interactive shell |
| `<any>` | Pass-through to RealityScan CLI |

### Examples

```bash
# REST only (default)
docker run -d --gpus all -p 8080:8080 ... martynyuu/realityscan:latest

# gRPC only
docker run -d --gpus all -p 50051:50051 ... martynyuu/realityscan:latest grpc

# Both APIs
docker run -d --gpus all -p 8080:8080 -p 50051:50051 ... martynyuu/realityscan:latest both

# Direct CLI command
docker run --rm --gpus all ... martynyuu/realityscan:latest -align /data/scans/project
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RS_REST_PORT` | `8080` | REST API port |
| `RS_GRPC_PORT` | `50051` | gRPC API port |

## Volumes

| Path | Description |
|------|-------------|
| `/data/scans` | Working directory for projects |
| `/tmp/realityscan.deb` | Installer (first run only) |
| `/etc/vulkan/icd.d` | Vulkan ICD config (read-only) |

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

### gRPC

See [Epic Games gRPC documentation](https://dev.epicgames.com/documentation/en-us/realityscan/remote-command-plugin)

## Unraid Template

Add this repository to your Docker template URLs:
```
https://github.com/Martynyuu/unraid-realityscan
```

## Support

- [GitHub Issues](https://github.com/Martynyuu/unraid-realityscan/issues)
- [Donations](https://ko-fi.com/strudel9)

## License

MIT
