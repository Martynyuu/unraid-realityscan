# RealityScan render node for Unraid (LumaLod Studio)

[![Docker](https://img.shields.io/badge/Docker-martynyuu%2Frealityscan-blue)](https://hub.docker.com/r/martynyuu/realityscan)
[![Unraid](https://img.shields.io/badge/Unraid-template-orange)](https://unraid.net/)

Runs **RSNode.exe** from **RealityScan for Linux** (Epic's Wine build) in a Docker container on
Unraid, with the NVIDIA GPU for CUDA and Vulkan. LumaLod Studio then talks to it over the same
RSNode HTTP API it uses for a Windows node. You configure everything in the Unraid Docker GUI.

**RealityScan is not part of the image.** The `.deb` is behind an Epic login and may not be
redistributed. You download it yourself and put it in a folder. On first start the container
unpacks it into a persistent folder. It does that again only when the `.deb` changes.

> **Status (2026-10-27).** The scripts are linted (`bash -n`, shellcheck) and the install,
> update, healthcheck and stop logic is tested against a fake package. RSNode under Wine has
> worked in an earlier setup, but this exact image has **not** run RealityScan yet. Untested are
> the Epic sign-in flow, `-dataRoot Z:\data\sessions`, CUDA/Vulkan with this image, and Studio
> connecting over the LAN. See [Troubleshooting](#troubleshooting).

## Requirements

- Unraid with an NVIDIA GPU
- [NVIDIA Driver plugin](https://forums.unraid.net/topic/98978-plugin-nvidia-driver/). It provides
  the `nvidia` Docker runtime.
- [Vulkan Support plugin](https://github.com/Martynyuu/unraid-vulkan). It provides the Vulkan ICD
  in `/etc/vulkan/icd.d`.
- The **RealityScan for Linux `.deb`** from <https://www.realityscan.com/en-US/linux> (needs an
  Epic login)

## Install on Unraid

1. **Add the template.** Use one of these:
   - *Docker > Template repositories:* add `https://github.com/Martynyuu/unraid-realityscan` and
     save.
   - Or download `unraid-template.xml` to
     `/boot/config/plugins/dockerMan/templates-user/my-LumaLod-RSNode.xml`.
   - Or run `bash install-unraid.sh` from a copy of this repo. It also checks the prerequisites
     and creates the folders.
2. **Put the `.deb` in place.** Copy it to `/mnt/user/appdata/lumalod-rsnode/installer/`. If
   there are several, the newest one is used.
3. **First start: sign in.** Go to *Docker > Add Container > Template: LumaLod-RSNode*.
   - Set **Mode = `login`** and a **VNC password**, then *Apply*.
   - The first start unpacks RealityScan, which takes a few minutes. Watch the container log.
   - Open `http://<unraid-ip>:6080/vnc.html`, sign in to your Epic account in RealityScan, and
     check *Settings > GPUs to use*. Then close RealityScan.
4. **Run as a node.** Edit the container: set **Mode = `rsnode`**, clear the VNC password, then
   *Apply*.
   - The container turns *healthy* once RSNode answers.
   - The WebUI link opens `/node/status`. A `401 Missing authentication token` answer there is
     expected and means RSNode is up.
5. **Diagnostics.** If something does not work, start once with **Mode = `inventory`** and read
   the log. It shows:
   - package contents and dependencies
   - where RSNode.exe is
   - the Wine prefix
   - `nvidia-smi`
   - Vulkan ICDs and `vulkaninfo --summary`
   - CUDA under Wine (`CudaDeviceQuery.exe`)

**Updating RealityScan:** put the new `.deb` in the installer folder (delete the old one) and
restart the container. The old install is replaced. The sign-in in AppData stays.
**Updating the image:** use Unraid's normal *Check for updates*. RealityScan and the sign-in live in
volumes, so they survive.

## Connect LumaLod Studio

In the Studio settings under `reality_scan`, set:

| key | value |
|---|---|
| `bind_host` | Unraid IP |
| `bind_port` | `30010` |
| `auto_launch` | `false` |

Studio gets RSNode's bearer from `GET /node/connection`. On Windows (RSNode 2.2, measured) RSNode
**answers that request only for loopback callers**. From another address the connection stays
open without a reply. In Docker every Studio request comes from the LAN, so Studio may wait for
`/node/connection` until it times out. Whether Wine behaves the same way is not verified yet.

If Studio cannot connect:

- **Read the bearer by hand.** Run `docker exec LumaLod-RSNode rsnode-token`. The bearer stays
  the same across restarts. Studio has no field for a manual token yet; this is a Studio-side
  change.
- **Or use the loopback relay** (advanced settings). Set *Loopback relay port* = `30011` and
  point Studio at `bind_port = 30011`. The relay forwards to RSNode from inside the container,
  so RSNode treats every caller as local. **That hands the bearer to anyone who can reach port
  30011.** Use it only on a trusted LAN.

## Modes (`MODE`)

| mode | what |
|---|---|
| `rsnode` (default) | `RSNode.exe` under the bundled Wine: `-hostAddress 0.0.0.0 -port $RSNODE_PORT -dataRoot Z:\data\sessions $RSNODE_ARGS`. Restarts RSNode if it exits. |
| `login` | RealityScan GUI on the virtual display, for the Epic sign-in. Needs `VNC_PASSWORD`. |
| `remote` | Epic's [Remote Command Plugin in Docker](https://dev.epicgames.com/documentation/realityscan/remote-command-plugin-in-docker): `-setInstanceName $CON_NAME`, then `-delegateTo $CON_NAME -RsRemoteStartREST http://0.0.0.0:1234`. Optional; Studio does not use it. |
| `inventory` | Diagnostics, then exit |
| `bash` | Shell with a TTY. Without one the container idles so you can use the Unraid console. |

## Paths, ports, variables

| container path | purpose |
|---|---|
| `/installer` (ro) | the RealityScan `.deb` |
| `/config` | `HOME`: RealityScan's Wine prefix `~/.realityscan` and the Epic sign-in |
| `/opt/realityscan` | the unpacked RealityScan, several GB. Must be empty or a previous install; anything else is refused. |
| `/data` | RSNode sessions in `/data/sessions`. Put this on a cache/SSD pool. |
| `/host/vulkan/icd.d` (ro) | host `/etc/vulkan/icd.d` (fallback ICD, see below) |

| port | purpose |
|---|---|
| 30010 | RSNode API |
| 6080 | noVNC (only with `VNC_PASSWORD`) |
| 5900 | VNC (only with `VNC_PASSWORD`) |
| 1234 | Remote Command REST (`MODE=remote`) |
| 30011 | optional loopback relay |

| variable | default | |
|---|---|---|
| `MODE` | `rsnode` | see above |
| `VNC_PASSWORD` | *(empty)* | empty means no VNC/noVNC. VNC uses only the first 8 characters. |
| `RSNODE_PORT` | `30010` | |
| `RSNODE_ARGS` | *(empty)* | space-separated, e.g. `-allowedHosts tower.lan;tower` |
| `RSNODE_DATA` | `/data/sessions` | `-dataRoot`. Passed as `Z:\data\sessions`, since Wine maps `/` to `Z:`. Override the Windows form with `RSNODE_DATAROOT_WIN`. |
| `RSNODE_RELAY_PORT` | *(empty)* | loopback relay, see above |
| `RSNODE_RESTART` | `1` | restart RSNode when it exits |
| `NVIDIA_VISIBLE_DEVICES` / `NVIDIA_DRIVER_CAPABILITIES` | `all` / `all` | |
| `CON_NAME`, `RS_ARGS`, `RSREMOTE_ARGS`, `REMOTE_PORT` | | `MODE=remote`, as in Epic's sample |

### Why HOME and not WINEPREFIX

Epic's Linux build keeps its own Wine prefix in `~/.realityscan/realityscan/`, next to the
bundled template prefix in `/opt/realityscan/support/`. Epic advises against modifying the
bundled prefix. The launcher picks the prefix. If `WINEPREFIX` were overridden, the launcher
would be pointed at a prefix it did not set up. So the image leaves `WINEPREFIX` alone and puts
`HOME` on a volume (`/config`). That keeps the prefix and the sign-in across container
recreation and image updates.

### Why the .deb is unpacked, not installed

`dpkg-deb -x` puts `opt/realityscan` into the volume. It does not need apt, does not run
maintainer scripts as root, and survives container recreation. A marker file records the
size/mtime and sha256 of the installed `.deb`. Files the package has outside `/opt/realityscan`
(menu entries and the like) are listed in the log and skipped. The image already contains the
runtime libraries from Epic's Docker page, plus common Wine libraries. Dependencies that the
package declares but that are missing from the image are logged.

## Security

- **Trusted LAN only.** RSNode speaks plain HTTP, and its bearer does not change across restarts.
  `/node/connection` hands the bearer out without authentication: only to loopback callers
  (measured on Windows), or to everyone with the relay on. Do not forward these ports to the
  internet.
- **`-allowedHosts`** is a Host-header allow list. RSNode always rejects unknown host names with
  `403 Host header not allowed.`, while IP literals pass. You need it only when Studio connects by
  name (`RSNODE_ARGS=-allowedHosts tower.lan;tower`). It is **not** access control.
- `-tlsKey <pem>` works on Windows. It takes the key first, then the certificate. It makes bulk
  transfers 4–7× slower. The healthcheck and `rsnode-token` switch to HTTPS when `RSNODE_ARGS`
  contains `-tlsKey`, but this is untested here.
- `/project/close` leaves the session folder on `/data`. Clients should call
  `/project/delete?guid=<id>` afterwards, or the disk fills up.

## Troubleshooting

**`Cannot create Vulkan instance` / `vkCreateInstance` errors.**
- Check `NVIDIA_DRIVER_CAPABILITIES=all` and `--runtime=nvidia` (in the template's *Extra
  Parameters*). Run `MODE=inventory`: `nvidia-smi` and `vulkaninfo --summary` must show the GPU.
- The entrypoint uses either the ICD manifest the NVIDIA runtime injects or the host's
  `/etc/vulkan/icd.d` (Vulkan Support plugin). A manifest with an absolute `library_path` that does
  not exist in the container (e.g. Unraid's `/usr/lib64/...`) is rewritten to the bare file name.
  The loader then finds the library the runtime injected.
- Set `VK_ICD_FILENAMES` yourself to override this.

**CUDA under Wine.** `MODE=inventory` runs Epic's `CudaDeviceQuery.exe` through the bundled Wine.
If it finds no device but `nvidia-smi` works, check that `NVIDIA_DRIVER_CAPABILITIES` includes
`compute` (`all` does).

**Container stays *unhealthy*.** The healthcheck reads the bearer over loopback and calls
`/node/status` with it. Check the log for RSNode errors. Run
`docker exec LumaLod-RSNode rsnode-token --json` to see whether `/node/connection` answers. The
first start can take minutes because of unpacking and Wine prefix setup; the start period is
180 s.

**Sign-in.**
- Epic notes that the login may need a browser inside the container, so the image ships Firefox.
  Build with `--build-arg INSTALL_BROWSER=0` to drop it.
- Some dialogs render as black rectangles; press Enter (Epic's note).

**`refusing to overwrite`.** The *RealityScan install* path points at a folder that is not empty
and not a previous install. Use an empty folder.

## Without Unraid

```bash
docker run -d --name rsnode --runtime=nvidia --shm-size=2g \
  -e NVIDIA_VISIBLE_DEVICES=all -e NVIDIA_DRIVER_CAPABILITIES=all \
  -e MODE=rsnode \
  -p 30010:30010 \
  -v /path/to/installer:/installer:ro \
  -v /path/to/config:/config \
  -v /path/to/realityscan:/opt/realityscan \
  -v /path/to/data:/data \
  -v /etc/vulkan/icd.d:/host/vulkan/icd.d:ro \
  martynyuu/realityscan:latest
```

With the NVIDIA Container Toolkit installed, `--gpus all` works instead of `--runtime=nvidia`.

## Build locally

```bash
docker build -t martynyuu/realityscan:local .
# or on Unraid, from a copy of this repo:
bash install-unraid.sh --build
```

The `.dockerignore` excludes `*.deb`, so a `.deb` lying in the folder never ends up in an image.

## License

The scripts and the Dockerfile are MIT. RealityScan is © Epic Games and governed by its own
license; it is not distributed here.

- [Epic: Docker deployment](https://dev.epicgames.com/documentation/realityscan/docker-deployment)
- [Epic: Remote Command Plugin in Docker](https://dev.epicgames.com/documentation/realityscan/remote-command-plugin-in-docker)
- [Issues](https://github.com/Martynyuu/unraid-realityscan/issues) · [Ko-fi](https://ko-fi.com/strudel9)
