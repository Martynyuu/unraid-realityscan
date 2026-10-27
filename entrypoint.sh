#!/usr/bin/env bash
# Entry point of the RealityScan render node container (LumaLod Studio).
#
# The mode comes from the first argument, else from $MODE (set in the Unraid template),
# else "rsnode":
#   rsnode     RSNode.exe under RealityScan's bundled Wine, port $RSNODE_PORT (default 30010),
#              session sandboxes on the /data volume (-dataRoot).
#   login      RealityScan GUI on the virtual display, for the one-off Epic sign-in. Needs
#              VNC_PASSWORD; open http://<host>:6080/vnc.html (noVNC) or a VNC client on :5900.
#   remote     Epic's documented Remote Command Plugin setup (-setInstanceName + -delegateTo
#              ... -RsRemoteStartREST http://0.0.0.0:$REMOTE_PORT). Optional; not what Studio uses.
#   inventory  Diagnostics (install, RSNode.exe, Wine prefix, GPU, Vulkan, CUDA under Wine), then exit.
#   bash       Interactive shell with a TTY; without one the container idles so the Unraid
#              console (">_") can be used.
#   <other>    Executed as-is.
#
# RealityScan itself is NOT part of the image (the .deb is behind an Epic login and not
# redistributable). Put the .deb into the folder mapped to /installer; it is extracted into
# /opt/realityscan (a volume) on first start and again only when the .deb changes.
set -euo pipefail

RS_ROOT="${RS_ROOT:-/opt/realityscan}"
WINE="$RS_ROOT/bin/wine"
INSTALLER_DIR="${INSTALLER_DIR:-/installer}"
MARKER="$RS_ROOT/.rsnode-installed"
STATE_DIR="${STATE_DIR:-/tmp/rsnode}"
HOST_ICD_DIR="${HOST_ICD_DIR:-/host/vulkan/icd.d}"

export HOME="${HOME:-/config}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-root}"
export WINEDEBUG="${WINEDEBUG:--all}"
RSNODE_PORT="${RSNODE_PORT:-30010}"
RSNODE_DATA="${RSNODE_DATA:-/data/sessions}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
REMOTE_PORT="${REMOTE_PORT:-1234}"

log() { printf '[rsnode] %s\n' "$*"; }
die() { local code="$1"; shift; printf '[rsnode] ERROR: %s\n' "$*" >&2; exit "$code"; }

mkdir -p "$STATE_DIR" "$XDG_RUNTIME_DIR" "$HOME"
chmod 700 "$XDG_RUNTIME_DIR"

# ---------------------------------------------------------------- RealityScan install

# Newest *.deb in the installer folder, or $INSTALLER_DEB if set.
find_deb() {
  if [ -n "${INSTALLER_DEB:-}" ]; then
    [ -f "$INSTALLER_DEB" ] && printf '%s\n' "$INSTALLER_DEB"
    return 0
  fi
  [ -d "$INSTALLER_DIR" ] || return 0
  find "$INSTALLER_DIR" -maxdepth 1 -type f -name '*.deb' -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr | head -1 | cut -d' ' -f2-
}

marker_get() { [ -f "$MARKER" ] && sed -n "s/^$1=//p" "$MARKER" | head -1; }

# Warn about packages the .deb declares as dependencies that the image does not have.
# The image ships the runtime libraries from Epic's Docker page; this catches drift.
check_deps() {
  local deb="$1" deps item alt name ok missing=()
  deps="$(dpkg-deb -f "$deb" Depends 2>/dev/null || true)"
  [ -n "$deps" ] || { log "package declares no Depends"; return 0; }
  IFS=',' read -ra items <<<"$deps"
  for item in "${items[@]}"; do
    ok=0
    IFS='|' read -ra alts <<<"$item"
    for alt in "${alts[@]}"; do
      name="$(sed -E 's/\(.*\)//; s/:any//; s/[[:space:]]//g' <<<"$alt")"
      if dpkg-query -W -f='${Status}' "$name" 2>/dev/null | grep -q 'ok installed'; then ok=1; break; fi
    done
    [ "$ok" = 1 ] || missing+=("$(xargs <<<"$item")")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    log "WARNING: dependencies declared by the package but not in the image (virtual packages show up here too):"
    printf '[rsnode]   %s\n' "${missing[@]}"
  else
    log "all declared dependencies are present"
  fi
}

install_deb() {
  local deb="$1" sha="$2" stamp="$3" stage="$RS_ROOT/.stage" version outside
  mkdir -p "$RS_ROOT"
  # Refuse to wipe a folder that is not ours (wrong host path mapped to /opt/realityscan).
  if [ -n "$(ls -A "$RS_ROOT" 2>/dev/null)" ] && [ ! -f "$MARKER" ] && [ ! -e "$WINE" ] && [ ! -d "$stage" ]; then
    die 3 "$RS_ROOT is not empty and does not look like a RealityScan install - refusing to overwrite it. Map 'RealityScan install' to an empty folder."
  fi
  version="$(dpkg-deb -f "$deb" Package Version 2>/dev/null | awk -F': ' '{printf "%s ", $2}')"
  log "installing $(basename "$deb") (${version% }) into $RS_ROOT"
  check_deps "$deb"

  # Extract next to the old install (same volume, no copy through the container layer),
  # then swap. Maintainer scripts are not run: the package is unpacked, not dpkg-installed,
  # so nothing outside /opt/realityscan is touched and the install survives container recreation.
  rm -rf "$stage"
  mkdir -p "$stage"
  dpkg-deb -x "$deb" "$stage"
  if [ ! -x "$stage/opt/realityscan/bin/wine" ]; then
    rm -rf "$stage"
    die 3 "$(basename "$deb") does not contain opt/realityscan/bin/wine - is this the RealityScan for Linux package?"
  fi
  outside="$(cd "$stage" && find . -type f ! -path './opt/realityscan/*' | head -20)"
  if [ -n "$outside" ]; then
    log "files in the package outside /opt/realityscan (not installed):"
    printf '%s\n' "$outside" | sed 's/^/[rsnode]   /'
  fi
  if dpkg-deb -I "$deb" postinst >/dev/null 2>&1; then
    log "note: the package has a postinst script, which an extract-only install does not run (see MODE=inventory)"
  fi

  rm -f "$MARKER"
  find "$RS_ROOT" -mindepth 1 -maxdepth 1 ! -name .stage -exec rm -rf {} +
  find "$stage/opt/realityscan" -mindepth 1 -maxdepth 1 -exec mv -t "$RS_ROOT" {} +
  rm -rf "$stage"
  printf 'deb=%s\nstamp=%s\nsha256=%s\nversion=%s\ninstalled=%s\n' \
    "$(basename "$deb")" "$stamp" "$sha" "${version% }" "$(date -u +%FT%TZ)" >"$MARKER"
  log "installed"
}

# Install or update RealityScan from the mounted .deb when it is missing or the .deb changed.
ensure_installed() {
  local deb stamp sha
  deb="$(find_deb)"
  if [ -z "$deb" ]; then
    [ -x "$WINE" ] && { log "RealityScan: $(marker_get version || true) (no .deb in $INSTALLER_DIR, keeping the installed one)"; return 0; }
    die 3 "RealityScan is not installed and there is no .deb in $INSTALLER_DIR. Download RealityScan for Linux (.deb, Epic login: https://www.realityscan.com/en-US/linux) and put it into the folder mapped to $INSTALLER_DIR."
  fi
  stamp="$(stat -c '%s %Y' "$deb") $(basename "$deb")"
  if [ -f "$MARKER" ] && [ -x "$WINE" ]; then
    if [ "$(marker_get stamp)" = "$stamp" ]; then
      log "RealityScan: $(marker_get version) (up to date with $(basename "$deb"))"
      return 0
    fi
    log "installer changed (size/mtime), comparing checksum ..."
    sha="$(sha256sum "$deb" | cut -d' ' -f1)"
    if [ "$(marker_get sha256)" = "$sha" ]; then
      sed -i "s/^stamp=.*/stamp=$stamp/" "$MARKER"
      log "RealityScan: $(marker_get version) (same checksum, nothing to do)"
      return 0
    fi
  else
    sha="$(sha256sum "$deb" | cut -d' ' -f1)"
  fi
  install_deb "$deb" "$sha" "$stamp"
}

# Windows executables inside the bundled prefix (or, failing that, anywhere under the install
# or the user's prefix in $HOME/.realityscan).
find_exe() {
  local name="$1" dir hit
  hit="$RS_ROOT/support/realityscan/drive_c/Program Files/Epic Games/RealityScan/$name"
  [ -f "$hit" ] && { printf '%s\n' "$hit"; return 0; }
  for dir in "$RS_ROOT" "$HOME/.realityscan"; do
    [ -d "$dir" ] || continue
    hit="$(find "$dir" -iname "$name" -type f 2>/dev/null | head -1)"
    [ -n "$hit" ] && { printf '%s\n' "$hit"; return 0; }
  done
  return 0
}

# ---------------------------------------------------------------- GPU / display

# Vulkan ICD. With --runtime=nvidia and capabilities incl. graphics the NVIDIA toolkit injects
# the driver libraries and usually the ICD manifest. The host's /etc/vulkan/icd.d (Vulkan Support
# plugin) is mounted at $HOST_ICD_DIR as a fallback. A manifest with an absolute library_path
# that does not exist in this container (e.g. Unraid's /usr/lib64/...) is rewritten to the bare
# file name so the loader resolves it through the injected libraries.
setup_vulkan() {
  local j lib base out="$STATE_DIR/icd.d" files=() seen=" "
  if [ -n "${VK_ICD_FILENAMES:-}${VK_DRIVER_FILES:-}" ]; then
    log "Vulkan: using VK_ICD_FILENAMES/VK_DRIVER_FILES from the environment"
    return 0
  fi
  mkdir -p "$out"
  for j in /etc/vulkan/icd.d/nvidia*.json /usr/share/vulkan/icd.d/nvidia*.json "$HOST_ICD_DIR"/*.json; do
    [ -f "$j" ] || continue
    base="$(basename "$j")"
    case "$seen" in *" $base "*) continue ;; esac
    seen="$seen$base "
    lib="$(sed -n 's/.*"library_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$j" | head -1)"
    if [ "${lib#/}" != "$lib" ] && [ ! -e "$lib" ]; then
      sed "s#\"library_path\"[[:space:]]*:[[:space:]]*\"[^\"]*\"#\"library_path\": \"$(basename "$lib")\"#" "$j" >"$out/$base"
      log "Vulkan ICD $j: $lib not in the container, using $(basename "$lib") from the library path"
    else
      cp "$j" "$out/$base"
      log "Vulkan ICD $j -> ${lib:-?}"
    fi
    files+=("$out/$base")
  done
  if [ "${#files[@]}" -eq 0 ]; then
    log "WARNING: no Vulkan ICD manifest found (NVIDIA runtime with NVIDIA_DRIVER_CAPABILITIES=all, or the Vulkan Support plugin + the /etc/vulkan/icd.d mount)"
    return 0
  fi
  VK_ICD_FILENAMES="$(IFS=:; printf '%s' "${files[*]}")"
  export VK_ICD_FILENAMES VK_DRIVER_FILES="$VK_ICD_FILENAMES"
}

# RealityScan needs an X display even when headless; Unraid has none, so start Xvfb.
# If DISPLAY is passed in (X11 forwarding from a Linux desktop), that display is used instead.
start_display() {
  if [ -n "${DISPLAY:-}" ]; then
    log "using DISPLAY=$DISPLAY from the environment"
    return 0
  fi
  export DISPLAY=:99
  rm -f /tmp/.X99-lock /tmp/.X11-unix/X99
  Xvfb "$DISPLAY" -screen 0 "${SCREEN_GEOMETRY:-1920x1080x24}" -nolisten tcp >"$STATE_DIR/xvfb.log" 2>&1 &
  local _
  for _ in $(seq 1 50); do
    [ -S /tmp/.X11-unix/X99 ] && { log "Xvfb on $DISPLAY"; return 0; }
    sleep 0.2
  done
  cat "$STATE_DIR/xvfb.log" >&2 || true
  die 5 "Xvfb did not start"
}

# VNC + noVNC only when VNC_PASSWORD is set (read at runtime, never baked into the image).
start_vnc() {
  if [ -z "${VNC_PASSWORD:-}" ]; then
    log "VNC/noVNC off (VNC_PASSWORD is empty)"
    return 0
  fi
  [ "${#VNC_PASSWORD}" -le 8 ] || log "note: VNC authentication only uses the first 8 characters of VNC_PASSWORD"
  local pw="$STATE_DIR/vncpasswd"
  (umask 077; printf '%s\n' "$VNC_PASSWORD" >"$pw")
  # rm: makes x11vnc delete the file after reading it; the password never appears in argv.
  x11vnc -display "$DISPLAY" -forever -shared -rfbport "$VNC_PORT" -passwdfile "rm:$pw" \
    -noxdamage -quiet >"$STATE_DIR/x11vnc.log" 2>&1 &
  websockify --web /usr/share/novnc "$NOVNC_PORT" "localhost:$VNC_PORT" >"$STATE_DIR/novnc.log" 2>&1 &
  unset VNC_PASSWORD
  log "VNC on :$VNC_PORT, noVNC on http://<host>:$NOVNC_PORT/vnc.html"
}

# Optional loopback relay, see README "Studio cannot read the bearer".
start_relay() {
  [ -n "${RSNODE_RELAY_PORT:-}" ] || return 0
  socat "TCP-LISTEN:$RSNODE_RELAY_PORT,fork,reuseaddr" "TCP:127.0.0.1:$RSNODE_PORT" >"$STATE_DIR/relay.log" 2>&1 &
  log "WARNING: relay :$RSNODE_RELAY_PORT -> 127.0.0.1:$RSNODE_PORT is on. RSNode sees relay callers as loopback,"
  log "WARNING: so /node/connection hands the bearer to anyone who can reach this port. Trusted LAN only."
}

# ---------------------------------------------------------------- process handling

child=""
stopping=0
on_term() {
  stopping=1
  log "stopping"
  [ -n "$child" ] && kill -TERM "$child" 2>/dev/null || true
}
trap on_term TERM INT

# Run a command in the background and wait for it, so TERM from tini reaches the trap.
run_wait() {
  local rc=0
  "$@" &
  child=$!
  wait "$child" || rc=$?
  while kill -0 "$child" 2>/dev/null; do wait "$child" || rc=$?; done
  child=""
  return "$rc"
}

# Some Wine launchers return while the Windows process keeps running; follow the process.
wait_exe_gone() {
  local name="$1"
  while [ "$stopping" = 0 ] && pgrep -f "$name" >/dev/null 2>&1; do sleep 5; done
}

# ---------------------------------------------------------------- modes

mode_rsnode() {
  ensure_installed
  local exe win_data rc extra=()
  exe="${RSNODE_EXE:-$(find_exe RSNode.exe)}"
  [ -n "$exe" ] || die 3 "RSNode.exe not found under $RS_ROOT or $HOME/.realityscan (run MODE=inventory)"
  setup_vulkan
  start_display
  start_vnc
  mkdir -p "$RSNODE_DATA"
  # Wine maps / to drive Z:, so /data/sessions becomes Z:\data\sessions.
  win_data="${RSNODE_DATAROOT_WIN:-Z:${RSNODE_DATA//\//\\}}"
  # RSNODE_ARGS: space-separated, no quoting (e.g. -allowedHosts tower.lan;tower).
  read -ra extra <<<"${RSNODE_ARGS:-}"
  start_relay
  log "RSNode: $exe"
  log "port $RSNODE_PORT, dataRoot $win_data, extra args: ${RSNODE_ARGS:-<none>}"
  log "bearer for Studio: docker exec <container> rsnode-token"
  while :; do
    rc=0
    run_wait "$WINE" "$exe" -hostAddress 0.0.0.0 -port "$RSNODE_PORT" -dataRoot "$win_data" "${extra[@]}" || rc=$?
    wait_exe_gone RSNode.exe
    [ "$stopping" = 1 ] && exit 0
    [ "${RSNODE_RESTART:-1}" = 1 ] || exit "$rc"
    log "RSNode exited (rc=$rc), restarting in 10 s (RSNODE_RESTART=0 disables this)"
    sleep 10
  done
}

mode_login() {
  [ -n "${VNC_PASSWORD:-}" ] || die 4 "MODE=login needs a VNC password (the sign-in happens on the virtual display). Set 'VNC password' in the template."
  ensure_installed
  setup_vulkan
  start_display
  start_vnc
  log "Open http://<unraid-ip>:$NOVNC_PORT/vnc.html, sign in to your Epic account in RealityScan,"
  log "check Settings > GPUs, close RealityScan, then set MODE=rsnode and clear the VNC password."
  local rc=0
  if [ -x "$RS_ROOT/bin/realityscan" ]; then
    run_wait "$RS_ROOT/bin/realityscan" || rc=$?
  else
    local exe; exe="$(find_exe RealityScan.exe)"
    [ -n "$exe" ] || die 3 "neither $RS_ROOT/bin/realityscan nor RealityScan.exe found"
    run_wait "$WINE" "$exe" || rc=$?
  fi
  wait_exe_gone RealityScan.exe
  log "RealityScan closed (rc=$rc). Sign-in data is in $HOME (persistent). Next: MODE=rsnode."
}

# Epic's "Remote Command Plugin in Docker" sample, kept as an option.
mode_remote() {
  ensure_installed
  local exe con args1=() args2=()
  exe="${RS_EXE:-$(find_exe RealityScan.exe)}"
  [ -n "$exe" ] || die 3 "RealityScan.exe not found"
  con="${CON_NAME:-rsnode}"
  read -ra args1 <<<"${RS_ARGS:-}"
  read -ra args2 <<<"${RSREMOTE_ARGS:--RsRemoteStartREST http://0.0.0.0:$REMOTE_PORT}"
  setup_vulkan
  start_display
  start_vnc
  log "Remote Command Plugin: instance '$con', delegate args: ${args2[*]}"
  "$WINE" --start "$exe" -setInstanceName "$con" "${args1[@]}" &
  child=$!
  # Epic: RealityScan needs time to load fonts and plugins before delegation.
  sleep "${REMOTE_DELEGATE_DELAY:-10}"
  "$WINE" --start "$exe" -delegateTo "$con" "${args2[@]}" || log "WARNING: delegate call returned $?"
  local rc=0
  wait "$child" || rc=$?
  wait_exe_gone RealityScan.exe
  exit "$rc"
}

# shellcheck disable=SC2012  # human-readable listings
mode_inventory() {
  set +e
  local deb exe
  echo "== Image"
  echo "HOME=$HOME  RSNODE_PORT=$RSNODE_PORT  RSNODE_DATA=$RSNODE_DATA"
  echo "== Installer ($INSTALLER_DIR)"
  deb="$(find_deb)"
  if [ -n "$deb" ]; then
    ls -la "$deb"
    dpkg-deb -f "$deb" Package Version Architecture Installed-Size Depends
    echo "-- top-level paths in the package:"
    dpkg-deb -c "$deb" | awk '{print $6}' | cut -d/ -f2-4 | sort -u | head -30
    echo "-- maintainer scripts:"
    for s in preinst postinst prerm postrm; do
      dpkg-deb -I "$deb" "$s" >/dev/null 2>&1 && { echo "--- $s"; dpkg-deb -I "$deb" "$s" | head -60; }
    done
    check_deps "$deb"
  else
    echo "no .deb"
  fi
  echo "== Install ($RS_ROOT)"
  [ -f "$MARKER" ] && cat "$MARKER" || echo "no install marker"
  ls -la "$RS_ROOT/bin" 2>&1 | head -40
  [ -f "$WINE" ] && { echo "-- $WINE starts with:"; head -c 300 "$WINE" | head -3; echo; }
  echo "RSNode.exe:       $(find_exe RSNode.exe)"
  echo "RealityScan.exe:  $(find_exe RealityScan.exe)"
  echo "== Wine prefixes"
  ls -la "$HOME/.realityscan" 2>&1 | head -20
  du -sh "$HOME/.realityscan" "$RS_ROOT/support" 2>/dev/null
  echo "== GPU"
  echo "NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES:-}  NVIDIA_DRIVER_CAPABILITIES=${NVIDIA_DRIVER_CAPABILITIES:-}"
  command -v nvidia-smi >/dev/null && nvidia-smi -L || echo "nvidia-smi not available (no --runtime=nvidia?)"
  ls -la /dev/dri 2>/dev/null
  echo "== Vulkan"
  ls -la /etc/vulkan/icd.d /usr/share/vulkan/icd.d "$HOST_ICD_DIR" 2>&1
  setup_vulkan
  echo "VK_ICD_FILENAMES=${VK_ICD_FILENAMES:-<loader default>}"
  timeout 60 vulkaninfo --summary 2>&1 | head -40
  if [ -x "$WINE" ]; then
    start_display
    echo "== CUDA under Wine"
    exe="$(find_exe CudaDeviceQuery.exe)"
    if [ -n "$exe" ]; then
      timeout 180 "$WINE" "$exe" 2>&1 | tail -25
    else
      timeout 180 "$WINE" CudaDeviceQuery.exe 2>&1 | tail -25
    fi
  fi
  echo "== done"
}

CMD="${1:-${MODE:-rsnode}}"
[ $# -gt 0 ] && shift
printf '%s\n' "$CMD" >"$STATE_DIR/mode"
log "mode: $CMD"

case "$CMD" in
  rsnode) mode_rsnode ;;
  login|gui) mode_login ;;
  remote) mode_remote ;;
  inventory) mode_inventory ;;
  bash|shell)
    if [ -t 0 ]; then exec /bin/bash; fi
    log "no TTY: idling. Use the container console (Unraid: Docker > container icon > Console)."
    exec sleep infinity
    ;;
  *) exec "$CMD" "$@" ;;
esac
