#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

APP_ID="proton-vortex"
APP_NAME="Vortex (Proton)"
SKYRIM_APP_ID="489830"
GITHUB_API="https://api.github.com/repos/Nexus-Mods/Vortex/releases/latest"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
APP_HOME="$DATA_HOME/$APP_ID"
APP_CACHE="$CACHE_HOME/$APP_ID"
APP_DESKTOP_DIR="$DATA_HOME/applications"
CONFIG_FILE="$APP_HOME/config.env"
APP_COMPAT_DATA="$APP_HOME/compatdata"
COMPAT_DATA="$APP_COMPAT_DATA"
PROTON_APP_ID="${PROTON_APP_ID:-$SKYRIM_APP_ID}"
LAUNCHER="$BIN_HOME/proton-vortex"
SKYRIM_HELPER="$BIN_HOME/proton-vortex-skyrim-se"
INTAKE_HELPER="$APP_HOME/mod-intake.py"

say() {
  printf '%s\n' "$*"
}

say_err() {
  printf '%s\n' "$*" >&2
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

check_platform() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    die "This installer must be run on Ubuntu/Linux."
  fi

  if [[ -r /proc/version ]] && grep -qi microsoft /proc/version; then
    die "WSL is not supported for Proton Vortex. Run this on the Ubuntu desktop install that has Steam and Proton."
  fi
}

install_missing_packages() {
  local missing=()
  local cmd

  for cmd in curl python3 xdg-mime; do
    if ! have "$cmd"; then
      missing+=("$cmd")
    fi
  done

  if ((${#missing[@]} == 0)); then
    return 0
  fi

  if have apt-get && have sudo; then
    say "Installing needed Ubuntu packages: curl python3 xdg-utils ca-certificates desktop-file-utils"
    sudo apt-get update
    sudo apt-get install -y curl python3 xdg-utils ca-certificates desktop-file-utils
    return 0
  fi

  if have apt-get && [[ "$(id -u)" == "0" ]]; then
    say "Installing needed Ubuntu packages: curl python3 xdg-utils ca-certificates desktop-file-utils"
    apt-get update
    apt-get install -y curl python3 xdg-utils ca-certificates desktop-file-utils
    return 0
  fi

  die "Missing commands: ${missing[*]}. Install curl, python3, and xdg-utils, then rerun this installer."
}

find_steam_root() {
  local candidates=(
    "${STEAM_ROOT:-}"
    "$HOME/.steam/root"
    "$HOME/.steam/steam"
    "$HOME/.local/share/Steam"
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
  )
  local root

  for root in "${candidates[@]}"; do
    if [[ -n "$root" && -d "$root/steamapps" ]]; then
      cd "$root" && pwd -P
      return 0
    fi
  done

  die "Steam was not found. Install Steam, run it once, install Proton, then rerun this installer. You can also set STEAM_ROOT=/path/to/Steam."
}

is_flatpak_steam_root() {
  local steam_root="$1"
  case "$steam_root" in
    "$HOME/.var/app/com.valvesoftware.Steam/"*|*/.var/app/com.valvesoftware.Steam/.local/share/Steam)
      return 0
      ;;
  esac
  return 1
}

collect_proton_bins() {
  local steam_root="$1"
  local search_roots=(
    "$steam_root/compatibilitytools.d"
    "$steam_root/steamapps/common"
    "$HOME/.steam/root/compatibilitytools.d"
    "$HOME/.local/share/Steam/compatibilitytools.d"
  )
  local root

  if [[ "${ALLOW_FLATPAK_STEAM:-0}" == "1" ]]; then
    search_roots+=("$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/compatibilitytools.d")
  fi

  if [[ -n "${PROTON_PATH:-}" && -x "$PROTON_PATH/proton" ]]; then
    printf '%s\n' "$PROTON_PATH/proton"
  fi

  for root in "${search_roots[@]}"; do
    if [[ -d "$root" ]]; then
      find "$root" -maxdepth 3 -type f -name proton -perm -u+x 2>/dev/null
    fi
  done
}

choose_proton_dir() {
  local steam_root="$1"
  local proton_bins=()
  local bin
  local selected=""

  mapfile -t proton_bins < <(collect_proton_bins "$steam_root" | awk '!seen[$0]++')

  if ((${#proton_bins[@]} == 0)); then
    die "No Proton installation was found. In Steam, install Proton Experimental or a current Proton version, then rerun this installer."
  fi

  for bin in "${proton_bins[@]}"; do
    case "$bin" in
      *GE-Proton*/*|*Proton-GE*/*)
        selected="$bin"
        ;;
    esac
  done

  if [[ -z "$selected" ]]; then
    for bin in "${proton_bins[@]}"; do
      case "$bin" in
        *"Proton Experimental"/*)
          selected="$bin"
          ;;
      esac
    done
  fi

  if [[ -z "$selected" ]]; then
    selected="$(printf '%s\n' "${proton_bins[@]}" | sort -V | tail -n 1)"
  fi

  dirname "$selected"
}

steam_libraries() {
  local steam_root="$1"
  local library_file="$steam_root/steamapps/libraryfolders.vdf"

  printf '%s\n' "$steam_root"

  if [[ -r "$library_file" ]]; then
    awk -F '"' '/"path"[[:space:]]*"/ {print $4}' "$library_file"
  fi
}

acf_value() {
  local file="$1"
  local key="$2"
  awk -F '"' -v key="$key" '$2 == key {print $4; exit}' "$file"
}

find_skyrim_se() {
  local steam_root="$1"
  local library
  local manifest
  local installdir
  local game_dir

  while IFS= read -r library; do
    [[ -n "$library" ]] || continue
    manifest="$library/steamapps/appmanifest_${SKYRIM_APP_ID}.acf"
    if [[ -r "$manifest" ]]; then
      installdir="$(acf_value "$manifest" installdir)"
      game_dir="$library/steamapps/common/$installdir"
      if [[ -f "$game_dir/SkyrimSE.exe" ]]; then
        printf '%s\t%s\t%s\n' "$game_dir" "$library" "$library/steamapps/compatdata/$SKYRIM_APP_ID"
        return 0
      fi
    fi
  done < <(steam_libraries "$steam_root" | awk '!seen[$0]++')

  return 1
}

latest_vortex_installer_url() {
  curl -fsSL "$GITHUB_API" | python3 -c '
import json
import sys

release = json.load(sys.stdin)
assets = release.get("assets", [])

def score(asset):
    name = asset.get("name", "").lower()
    url = asset.get("browser_download_url", "")
    if not url or not name.endswith(".exe"):
        return -1
    points = 0
    if "setup" in name:
        points += 10
    if "installer" in name:
        points += 5
    if "vortex" in name:
        points += 3
    if "blockmap" in name or "delta" in name:
        return -1
    return points

ranked = sorted(((score(asset), asset) for asset in assets), reverse=True, key=lambda item: item[0])
for points, asset in ranked:
    if points >= 0:
        print(asset["browser_download_url"])
        raise SystemExit(0)

raise SystemExit("No Vortex .exe installer asset was found in the latest GitHub release.")
'
}

download_vortex_installer() {
  local url
  local file

  url="$(latest_vortex_installer_url)"
  file="$APP_CACHE/${url##*/}"

  mkdir -p "$APP_CACHE"

  if [[ -s "$file" ]]; then
    say_err "Using cached Vortex installer: $file"
  else
    say_err "Downloading Vortex installer..."
    curl -fL --retry 3 --retry-delay 2 -o "$file" "$url"
  fi

  printf '%s\n' "$file"
}

write_config() {
  local steam_root="$1"
  local proton_dir="$2"

  mkdir -p "$APP_HOME" "$COMPAT_DATA"
  cat >"$CONFIG_FILE" <<EOF_CONFIG
# Written by proton-vortex install.sh
STEAM_ROOT=$(printf '%q' "$steam_root")
PROTON_DIR=$(printf '%q' "$proton_dir")
COMPAT_DATA=$(printf '%q' "$COMPAT_DATA")
APP_HOME=$(printf '%q' "$APP_HOME")
SKYRIM_SE_GAME_DIR=$(printf '%q' "${SKYRIM_SE_GAME_DIR:-}")
SKYRIM_SE_LIBRARY_ROOT=$(printf '%q' "${SKYRIM_SE_LIBRARY_ROOT:-}")
SKYRIM_SE_COMPAT_DATA=$(printf '%q' "${SKYRIM_SE_COMPAT_DATA:-}")
PROTON_APP_ID=$(printf '%q' "$PROTON_APP_ID")
EOF_CONFIG
}

install_launcher() {
  mkdir -p "$BIN_HOME" "$APP_HOME"
  cp "$SCRIPT_DIR/scripts/proton-vortex.sh" "$LAUNCHER"
  cp "$SCRIPT_DIR/scripts/skyrim-se.sh" "$SKYRIM_HELPER"
  cp "$SCRIPT_DIR/scripts/mod-intake.py" "$INTAKE_HELPER"
  chmod +x "$LAUNCHER"
  chmod +x "$SKYRIM_HELPER"
  chmod +x "$INTAKE_HELPER"
}

desktop_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

write_desktop_files() {
  local launcher_exec
  launcher_exec="$(desktop_quote "$LAUNCHER")"
  mkdir -p "$APP_DESKTOP_DIR"

  cat >"$APP_DESKTOP_DIR/proton-vortex.desktop" <<EOF_DESKTOP
[Desktop Entry]
Type=Application
Name=$APP_NAME
Comment=Run Nexus Mods Vortex through Steam Proton
Categories=Game;Utility;
Exec=$launcher_exec
Terminal=false
Icon=applications-games
StartupNotify=true
EOF_DESKTOP

  cat >"$APP_DESKTOP_DIR/proton-vortex-nxm.desktop" <<EOF_DESKTOP
[Desktop Entry]
Type=Application
Name=Vortex NXM Handler
Comment=Open Nexus Mods NXM links in Vortex through Proton
Categories=Game;Network;
MimeType=x-scheme-handler/nxm;x-scheme-handler/nxm-protocol;
Exec=$launcher_exec %u
Terminal=false
Icon=applications-internet
NoDisplay=true
StartupNotify=true
EOF_DESKTOP

  cat >"$APP_DESKTOP_DIR/proton-vortex-skyrim-se.desktop" <<EOF_DESKTOP
[Desktop Entry]
Type=Application
Name=Skyrim SE SKSE (Proton)
Comment=Launch Skyrim Special Edition through SKSE64 and Proton
Categories=Game;
Exec=$(desktop_quote "$SKYRIM_HELPER") launch-skse
Terminal=false
Icon=applications-games
StartupNotify=true
EOF_DESKTOP

  cat >"$APP_DESKTOP_DIR/proton-vortex-import.desktop" <<EOF_DESKTOP
[Desktop Entry]
Type=Application
Name=Import Mod with Vortex (Proton)
Comment=Import a local mod archive into Vortex through Proton
Categories=Game;Utility;
MimeType=application/zip;application/x-7z-compressed;application/vnd.rar;application/x-rar;application/x-rar-compressed;application/gzip;application/x-tar;
Exec=$launcher_exec import %u
Terminal=false
Icon=package-x-generic
NoDisplay=false
StartupNotify=true
EOF_DESKTOP

  if have desktop-file-validate; then
    desktop-file-validate "$APP_DESKTOP_DIR/proton-vortex.desktop" || true
    desktop-file-validate "$APP_DESKTOP_DIR/proton-vortex-nxm.desktop" || true
    desktop-file-validate "$APP_DESKTOP_DIR/proton-vortex-skyrim-se.desktop" || true
    desktop-file-validate "$APP_DESKTOP_DIR/proton-vortex-import.desktop" || true
  fi

  if have update-desktop-database; then
    update-desktop-database "$APP_DESKTOP_DIR" >/dev/null 2>&1 || true
  fi
}

register_nxm_handler() {
  xdg-mime default proton-vortex-nxm.desktop x-scheme-handler/nxm
  xdg-mime default proton-vortex-nxm.desktop x-scheme-handler/nxm-protocol || true
}

setup_skyrim_se() {
  if [[ -z "${SKYRIM_SE_GAME_DIR:-}" ]]; then
    return 0
  fi

  say "Setting up SKSE64 for Skyrim Special Edition..."
  if "$SKYRIM_HELPER" install-skse; then
    say "SKSE64 setup is complete."
  else
    say "SKSE64 automatic setup did not complete. You can retry with:"
    say "  proton-vortex-skyrim-se install-skse"
  fi
}

find_installed_vortex() {
  local pfx="$COMPAT_DATA/pfx"
  local candidates=(
    "$pfx/drive_c/users/steamuser/AppData/Local/Programs/Vortex/Vortex.exe"
    "$pfx/drive_c/users/$USER/AppData/Local/Programs/Vortex/Vortex.exe"
    "$pfx/drive_c/Program Files/Vortex/Vortex.exe"
    "$pfx/drive_c/Program Files (x86)/Vortex/Vortex.exe"
  )
  local candidate

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if [[ -d "$pfx/drive_c" ]]; then
    find "$pfx/drive_c" -iname Vortex.exe -type f -print -quit 2>/dev/null
  fi
}

run_proton_command() {
  local proton_dir="$1"
  shift

  STEAM_COMPAT_DATA_PATH="$COMPAT_DATA" \
  STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT" \
  STEAM_COMPAT_APP_ID="$PROTON_APP_ID" \
  SteamAppId="$PROTON_APP_ID" \
  "$proton_dir/proton" "$@"
}

run_with_proton() {
  local proton_dir="$1"
  shift

  run_proton_command "$proton_dir" waitforexitandrun "$@"
}

ensure_proton_prefix() {
  local proton_dir="$1"

  mkdir -p "$COMPAT_DATA"

  if [[ -d "$COMPAT_DATA/pfx/drive_c" ]]; then
    return 0
  fi

  say "Creating Proton prefix: $COMPAT_DATA"
  if ! run_proton_command "$proton_dir" run wineboot -u; then
    say "First Proton prefix bootstrap command failed; trying Proton's waitforexit path..."
    if ! run_proton_command "$proton_dir" waitforexitandrun wineboot -u; then
      die "Proton could not bootstrap the prefix at $COMPAT_DATA."
    fi
  fi

  if [[ ! -d "$COMPAT_DATA/pfx/drive_c" ]]; then
    die "Proton did not create $COMPAT_DATA/pfx. If this is Skyrim's prefix, run Skyrim once in Steam, then rerun install.sh."
  fi
}

install_vortex() {
  local proton_dir="$1"
  local installer
  local vortex_exe

  vortex_exe="$(find_installed_vortex || true)"
  if [[ -n "$vortex_exe" && "${FORCE_REINSTALL:-0}" != "1" ]]; then
    say "Vortex is already installed: $vortex_exe"
    return 0
  fi

  installer="$(download_vortex_installer)"
  say "Installing Vortex into Proton prefix: $COMPAT_DATA"

  if ! run_with_proton "$proton_dir" "$installer" /S; then
    say "Silent install did not complete. Opening the normal installer..."
    run_with_proton "$proton_dir" "$installer"
  fi

  vortex_exe="$(find_installed_vortex || true)"
  if [[ -z "$vortex_exe" ]]; then
    die "Vortex did not appear in the Proton prefix after install. Try rerunning with FORCE_REINSTALL=1 bash install.sh."
  fi

  say "Installed Vortex: $vortex_exe"
}

main() {
  check_platform
  install_missing_packages

  STEAM_ROOT="$(find_steam_root)"
  if is_flatpak_steam_root "$STEAM_ROOT"; then
    if [[ "${ALLOW_FLATPAK_STEAM:-0}" != "1" ]]; then
      die "Flatpak Steam was detected at $STEAM_ROOT, but this installer runs Proton from the host and cannot reliably use Flatpak's Steam runtime. Install the normal Steam package or set STEAM_ROOT to a native Steam install. Advanced users can retry with ALLOW_FLATPAK_STEAM=1."
    fi
    say "Warning: Flatpak Steam support is experimental because Proton may need to run inside the Flatpak runtime."
  fi

  PROTON_DIR="$(choose_proton_dir "$STEAM_ROOT")"
  SKYRIM_SE_GAME_DIR=""
  SKYRIM_SE_LIBRARY_ROOT=""
  SKYRIM_SE_COMPAT_DATA=""

  if skyrim_info="$(find_skyrim_se "$STEAM_ROOT")"; then
    IFS=$'\t' read -r SKYRIM_SE_GAME_DIR SKYRIM_SE_LIBRARY_ROOT SKYRIM_SE_COMPAT_DATA <<<"$skyrim_info"
    if [[ "${VORTEX_STANDALONE_PREFIX:-0}" != "1" ]]; then
      COMPAT_DATA="$SKYRIM_SE_COMPAT_DATA"
      PROTON_APP_ID="$SKYRIM_APP_ID"
    fi
  fi

  say "Steam:  $STEAM_ROOT"
  say "Proton: $PROTON_DIR"
  if [[ -n "$SKYRIM_SE_GAME_DIR" ]]; then
    say "Skyrim: $SKYRIM_SE_GAME_DIR"
    say "Prefix: $COMPAT_DATA"
  fi

  write_config "$STEAM_ROOT" "$PROTON_DIR"
  install_launcher
  ensure_proton_prefix "$PROTON_DIR"
  install_vortex "$PROTON_DIR"
  write_desktop_files
  register_nxm_handler
  setup_skyrim_se

  say ""
  say "Done. Launch '$APP_NAME' from your app menu, or run:"
  say "  proton-vortex"
  say ""
  say "NXM handler:"
  say "  $(xdg-mime query default x-scheme-handler/nxm || true)"
  say ""
  say "For a quick health check:"
  say "  bash '$SCRIPT_DIR/scripts/diagnose.sh'"

  if [[ -n "$SKYRIM_SE_GAME_DIR" ]]; then
    say ""
    say "Skyrim SE:"
    say "  Launch SKSE: proton-vortex-skyrim-se launch-skse"
    say "  Update SKSE: proton-vortex-skyrim-se install-skse"
  fi
}

main "$@"
