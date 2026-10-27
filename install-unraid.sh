#!/bin/bash
# Optional helper for the Unraid terminal. Normal installs only need the template (README).
#   1. checks prerequisites (NVIDIA runtime, Vulkan ICD)
#   2. creates the appdata folders and copies a RealityScan .deb into the installer folder
#   3. installs the template as a user template (Docker > Add Container > LumaLod-RSNode)
#   4. with --build: builds the image locally from this folder as martynyuu/realityscan:local
#      and points the installed template at that tag (for testing a branch before CI publishes)
#
# Usage:  bash install-unraid.sh [--build] [path/to/realityscan.deb]
set -euo pipefail
cd "$(dirname "$0")"

IMAGE_LOCAL=martynyuu/realityscan:local
TEMPLATE_DIR=/boot/config/plugins/dockerMan/templates-user
APPDATA=/mnt/user/appdata/lumalod-rsnode

ok()   { echo "  [ok]   $*"; }
warn() { echo "  [warn] $*"; }
die()  { echo "  [fail] $*" >&2; exit 1; }

BUILD=0
DEB=""
for arg in "$@"; do
  case "$arg" in
    --build) BUILD=1 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) DEB="$arg" ;;
  esac
done

echo "== Checks"
[ -d /boot/config ] || die "not on Unraid (/boot/config missing)"
if command -v nvidia-smi >/dev/null; then
  ok "$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | head -1)"
else
  die "nvidia-smi missing - install the NVIDIA Driver plugin"
fi
if docker info 2>/dev/null | grep -qi 'runtimes:.*nvidia'; then
  ok "docker runtime nvidia"
else
  die "no nvidia runtime in docker - NVIDIA Driver plugin installed and Docker restarted?"
fi
if compgen -G '/etc/vulkan/icd.d/*.json' >/dev/null; then
  ok "Vulkan ICD: $(echo /etc/vulkan/icd.d/*.json)"
else
  warn "no /etc/vulkan/icd.d/*.json - install the Vulkan Support plugin (Martynyuu/unraid-vulkan)"
fi

echo "== appdata ($APPDATA)"
mkdir -p "$APPDATA/installer" "$APPDATA/config" "$APPDATA/realityscan" "$APPDATA/data"
ok "installer/ config/ realityscan/ data/"
[ -n "$DEB" ] || DEB="$(find . -maxdepth 1 -name '*.deb' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)"
if [ -n "$DEB" ]; then
  [ -f "$DEB" ] || die "$DEB not found"
  cp -u "$DEB" "$APPDATA/installer/"
  ok "installer: $(basename "$DEB")"
elif ! compgen -G "$APPDATA/installer/*.deb" >/dev/null; then
  warn "no .deb yet - download RealityScan for Linux (realityscan.com/en-US/linux) into $APPDATA/installer"
fi

echo "== Template"
mkdir -p "$TEMPLATE_DIR"
dest="$TEMPLATE_DIR/my-LumaLod-RSNode.xml"
if [ -f "$dest" ]; then
  warn "$dest exists (your saved settings) - left unchanged; delete it to reinstall the template"
else
  cp unraid-template.xml "$dest"
  ok "$dest"
fi

if [ "$BUILD" = 1 ]; then
  echo "== Build $IMAGE_LOCAL"
  docker build -t "$IMAGE_LOCAL" .
  ok "image built"
  sed -i "s#<Repository>[^<]*</Repository>#<Repository>$IMAGE_LOCAL</Repository>#" "$dest"
  ok "template now uses $IMAGE_LOCAL (set Repository back to martynyuu/realityscan:latest after publishing)"
fi

cat <<EOF

Next steps in the Unraid GUI:
  1. Docker > Add Container > Template: LumaLod-RSNode
  2. First start: Mode = login, set a VNC password > Apply.
     Open http://<unraid-ip>:6080/vnc.html, sign in to Epic in RealityScan, close it.
  3. Edit the container: Mode = rsnode, clear the VNC password > Apply.
  4. Bearer for Studio:  docker exec LumaLod-RSNode rsnode-token
EOF
