#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

APP_ID="proton-vortex"
APP_NAME="Vortex (Proton)"
SKYRIM_APP_ID="489830"
SKYRIM_VORTEX_GAME_ID="skyrimse"
GITHUB_API="https://api.github.com/repos/Nexus-Mods/Vortex/releases/latest"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
APP_HOME="$DATA_HOME/$APP_ID"
APP_CACHE="$CACHE_HOME/$APP_ID"
APP_DESKTOP_DIR="$DATA_HOME/applications"
APP_ICON_DIR="$DATA_HOME/icons/hicolor/scalable/apps"
CONFIG_FILE="$APP_HOME/config.env"
APP_COMPAT_DATA="$APP_HOME/compatdata"
COMPAT_DATA="$APP_COMPAT_DATA"
PROTON_APP_ID="${PROTON_APP_ID:-$SKYRIM_APP_ID}"
PROTON_VORTEX_DPI="${PROTON_VORTEX_DPI:-120}"
PROTON_VORTEX_SCALE="${PROTON_VORTEX_SCALE:-1.5}"
PROTON_VORTEX_PERFORMANCE="${PROTON_VORTEX_PERFORMANCE:-0}"
PROTON_VORTEX_WINEDEBUG="${PROTON_VORTEX_WINEDEBUG:--all}"
PROTON_VORTEX_DRIVE_LETTER="${PROTON_VORTEX_DRIVE_LETTER:-s}"
VORTEX_GAME_ID="${VORTEX_GAME_ID:-}"
VORTEX_SKYRIMSE_BASE_DIR="${VORTEX_SKYRIMSE_BASE_DIR:-}"
VORTEX_SKYRIMSE_STAGING_DIR="${VORTEX_SKYRIMSE_STAGING_DIR:-}"
VORTEX_DOWNLOADS_DIR="${VORTEX_DOWNLOADS_DIR:-}"
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

canonical_dir() {
  (cd "$1" && pwd -P)
}

normalize_drive_letter() {
  local letter="$1"
  letter="$(printf '%s' "$letter" | tr '[:upper:]' '[:lower:]')"
  case "$letter" in
    [a-z])
      printf '%s\n' "$letter"
      ;;
    *)
      printf 's\n'
      ;;
  esac
}

path_relative_to() {
  local base="$1"
  local path="$2"

  case "$path" in
    "$base")
      printf '%s\n' ""
      ;;
    "$base"/*)
      printf '%s\n' "${path#"$base"/}"
      ;;
    *)
      return 1
      ;;
  esac
}

windows_path_from_library() {
  local library="$1"
  local path="$2"
  local letter
  local rel

  letter="$(normalize_drive_letter "$PROTON_VORTEX_DRIVE_LETTER")"
  rel="$(path_relative_to "$library" "$path")" || return 1
  rel="${rel//\//\\}"
  printf '%s:\\%s\n' "$(printf '%s' "$letter" | tr '[:lower:]' '[:upper:]')" "$rel"
}

linux_path_to_z_hint() {
  local path="$1"
  printf 'Z:%s\n' "$path" | sed 's#/#\\#g'
}

windows_path_hint() {
  local library="$1"
  local path="$2"

  windows_path_from_library "$library" "$path" 2>/dev/null || linux_path_to_z_hint "$path"
}

directory_empty() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  [[ -z "$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]
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
      canonical_dir "$root"
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

  for root in "${search_roots[@]}"; do
    if [[ -d "$root" ]]; then
      find "$root" -maxdepth 3 -type f -name proton -perm -u+x 2>/dev/null
    fi
  done
}

proton_tool_name() {
  basename -- "$(dirname -- "$1")"
}

select_latest_proton_bin() {
  local bin
  for bin in "$@"; do
    printf '%s\t%s\n' "$(proton_tool_name "$bin")" "$bin"
  done | sort -t $'\t' -V -k1,1 | tail -n 1 | cut -f2-
}

choose_proton_dir() {
  local steam_root="$1"
  local proton_bins=()
  local bin
  local name
  local selected=""
  local experimental=()
  local official=()
  local hotfix=()
  local ge=()
  local other=()

  if [[ -n "${PROTON_PATH:-}" ]]; then
    if [[ -x "$PROTON_PATH/proton" ]]; then
      canonical_dir "$PROTON_PATH"
      return 0
    fi
    if [[ -x "$PROTON_PATH" && "$(basename -- "$PROTON_PATH")" == "proton" ]]; then
      canonical_dir "$(dirname -- "$PROTON_PATH")"
      return 0
    fi
    die "PROTON_PATH is set but does not point to a Proton directory or proton executable: $PROTON_PATH"
  fi

  mapfile -t proton_bins < <(collect_proton_bins "$steam_root" | awk '!seen[$0]++')

  if ((${#proton_bins[@]} == 0)); then
    die "No Proton installation was found. In Steam, install Proton Experimental or a current Proton version, then rerun this installer."
  fi

  for bin in "${proton_bins[@]}"; do
    name="$(proton_tool_name "$bin")"
    case "$name" in
      *"Proton Experimental"*|*"Proton - Experimental"*)
        experimental+=("$bin")
        ;;
      *"Proton Hotfix"*)
        hotfix+=("$bin")
        ;;
      GE-Proton*|Proton-GE*|*GE-Proton*|*Proton-GE*)
        ge+=("$bin")
        ;;
      Proton\ [0-9]*|Proton-[0-9]*|proton-[0-9]*)
        official+=("$bin")
        ;;
      *Proton*|*proton*)
        other+=("$bin")
        ;;
    esac
  done

  if [[ "${PROTON_PREFER_GE:-0}" == "1" && ${#ge[@]} -gt 0 ]]; then
    selected="$(select_latest_proton_bin "${ge[@]}")"
  elif ((${#experimental[@]} > 0)); then
    selected="$(select_latest_proton_bin "${experimental[@]}")"
  elif ((${#official[@]} > 0)); then
    selected="$(select_latest_proton_bin "${official[@]}")"
  elif ((${#hotfix[@]} > 0)); then
    selected="$(select_latest_proton_bin "${hotfix[@]}")"
  elif ((${#ge[@]} > 0)); then
    selected="$(select_latest_proton_bin "${ge[@]}")"
  elif ((${#other[@]} > 0)); then
    selected="$(select_latest_proton_bin "${other[@]}")"
  fi

  if [[ -z "$selected" ]]; then
    selected="$(select_latest_proton_bin "${proton_bins[@]}")"
  fi

  canonical_dir "$(dirname -- "$selected")"
}

proton_major_version() {
  local name="$1"
  if [[ "$name" =~ ([0-9]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf '0\n'
  fi
}

warn_if_old_proton() {
  local proton_dir="$1"
  local min_major="${PROTON_MIN_MAJOR:-10}"
  local name
  local major

  name="$(basename -- "$proton_dir")"
  major="$(proton_major_version "$name")"

  if [[ "$major" != "0" && "$major" -lt "$min_major" ]]; then
    say "Warning: selected Proton looks old: $name"
    say "For Skyrim SE, install Proton Experimental or the newest official Proton in Steam, then rerun install.sh."
    say "You can force a specific Proton with PROTON_PATH=/path/to/Proton bash install.sh."
  fi
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
INSTALL_SOURCE_DIR=$(printf '%q' "$SCRIPT_DIR")
SKYRIM_SE_GAME_DIR=$(printf '%q' "${SKYRIM_SE_GAME_DIR:-}")
SKYRIM_SE_LIBRARY_ROOT=$(printf '%q' "${SKYRIM_SE_LIBRARY_ROOT:-}")
SKYRIM_SE_COMPAT_DATA=$(printf '%q' "${SKYRIM_SE_COMPAT_DATA:-}")
PROTON_APP_ID=$(printf '%q' "$PROTON_APP_ID")
PROTON_VORTEX_DPI=$(printf '%q' "$PROTON_VORTEX_DPI")
PROTON_VORTEX_SCALE=$(printf '%q' "$PROTON_VORTEX_SCALE")
PROTON_VORTEX_PERFORMANCE=$(printf '%q' "$PROTON_VORTEX_PERFORMANCE")
PROTON_VORTEX_WINEDEBUG=$(printf '%q' "$PROTON_VORTEX_WINEDEBUG")
PROTON_VORTEX_DRIVE_LETTER=$(printf '%q' "$PROTON_VORTEX_DRIVE_LETTER")
VORTEX_GAME_ID=$(printf '%q' "${VORTEX_GAME_ID:-}")
VORTEX_SKYRIMSE_BASE_DIR=$(printf '%q' "${VORTEX_SKYRIMSE_BASE_DIR:-}")
VORTEX_SKYRIMSE_STAGING_DIR=$(printf '%q' "${VORTEX_SKYRIMSE_STAGING_DIR:-}")
VORTEX_DOWNLOADS_DIR=$(printf '%q' "${VORTEX_DOWNLOADS_DIR:-}")
VORTEX_SKYRIMSE_GAME_WIN_PATH=$(printf '%q' "${VORTEX_SKYRIMSE_GAME_WIN_PATH:-}")
VORTEX_SKYRIMSE_STAGING_WIN_PATH=$(printf '%q' "${VORTEX_SKYRIMSE_STAGING_WIN_PATH:-}")
VORTEX_DOWNLOADS_WIN_PATH=$(printf '%q' "${VORTEX_DOWNLOADS_WIN_PATH:-}")
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

install_icons() {
  mkdir -p "$APP_ICON_DIR"

  cat >"$APP_ICON_DIR/proton-vortex.svg" <<'EOF_ICON'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="24" fill="#1f2937"/>
  <path d="M64 14 110 38v52L64 114 18 90V38z" fill="#2563eb"/>
  <path d="M64 25 98 43v38L64 99 30 81V43z" fill="#0f172a"/>
  <path d="M41 42h17l7 35 8-35h16L75 88H55z" fill="#f8fafc"/>
  <path d="M30 81 64 99 98 81v9L64 108 30 90z" fill="#38bdf8"/>
</svg>
EOF_ICON

  cat >"$APP_ICON_DIR/proton-vortex-skyrim-se.svg" <<'EOF_ICON'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="24" fill="#111827"/>
  <path d="M64 12 100 31v66L64 116 28 97V31z" fill="#334155"/>
  <path d="M64 24 88 38v46L64 102 40 84V38z" fill="#e5e7eb"/>
  <path d="M64 34 75 59l27 3-20 18 6 27-24-14-24 14 6-27-20-18 27-3z" fill="#2563eb"/>
  <path d="M64 42 72 61l20 2-15 13 5 20-18-11-18 11 5-20-15-13 20-2z" fill="#f8fafc"/>
</svg>
EOF_ICON

  cat >"$APP_ICON_DIR/proton-vortex-import.svg" <<'EOF_ICON'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="24" fill="#172554"/>
  <path d="M30 34h68v60H30z" rx="10" fill="#dbeafe"/>
  <path d="M42 48h44v10H42zm0 18h44v10H42z" fill="#1d4ed8"/>
  <path d="M64 18v45" stroke="#38bdf8" stroke-width="12" stroke-linecap="round"/>
  <path d="m45 46 19 19 19-19" fill="none" stroke="#38bdf8" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
EOF_ICON

  if have gtk-update-icon-cache; then
    gtk-update-icon-cache -f -t "$DATA_HOME/icons/hicolor" >/dev/null 2>&1 || true
  fi
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
Icon=proton-vortex
StartupWMClass=Vortex.exe
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
Icon=proton-vortex
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
Icon=proton-vortex-skyrim-se
StartupWMClass=skse64_loader.exe
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
Icon=proton-vortex-import
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

prepare_skyrim_vortex_paths() {
  local write_test

  if [[ -z "${SKYRIM_SE_GAME_DIR:-}" || -z "${SKYRIM_SE_LIBRARY_ROOT:-}" ]]; then
    return 0
  fi

  PROTON_VORTEX_DRIVE_LETTER="$(normalize_drive_letter "$PROTON_VORTEX_DRIVE_LETTER")"
  VORTEX_SKYRIMSE_BASE_DIR="${VORTEX_SKYRIMSE_BASE_DIR:-$SKYRIM_SE_LIBRARY_ROOT/VortexMods}"
  VORTEX_SKYRIMSE_STAGING_DIR="${VORTEX_SKYRIMSE_STAGING_DIR:-$VORTEX_SKYRIMSE_BASE_DIR/skyrimse/mods}"
  VORTEX_DOWNLOADS_DIR="${VORTEX_DOWNLOADS_DIR:-$VORTEX_SKYRIMSE_BASE_DIR/downloads}"

  mkdir -p "$VORTEX_SKYRIMSE_STAGING_DIR" "$VORTEX_DOWNLOADS_DIR"

  write_test="$VORTEX_SKYRIMSE_STAGING_DIR/.proton-vortex-write-test"
  if ! printf 'ok\n' >"$write_test"; then
    die "Cannot write to Vortex staging folder: $VORTEX_SKYRIMSE_STAGING_DIR"
  fi
  rm -f -- "$write_test"

  write_test="$VORTEX_DOWNLOADS_DIR/.proton-vortex-write-test"
  if ! printf 'ok\n' >"$write_test"; then
    die "Cannot write to Vortex downloads folder: $VORTEX_DOWNLOADS_DIR"
  fi
  rm -f -- "$write_test"

  VORTEX_SKYRIMSE_GAME_WIN_PATH="$(windows_path_hint "$SKYRIM_SE_LIBRARY_ROOT" "$SKYRIM_SE_GAME_DIR")"
  VORTEX_SKYRIMSE_STAGING_WIN_PATH="$(windows_path_hint "$SKYRIM_SE_LIBRARY_ROOT" "$VORTEX_SKYRIMSE_STAGING_DIR")"
  VORTEX_DOWNLOADS_WIN_PATH="$(windows_path_hint "$SKYRIM_SE_LIBRARY_ROOT" "$VORTEX_DOWNLOADS_DIR")"
}

link_empty_or_missing_dir() {
  local link_path="$1"
  local target_path="$2"
  local label="$3"

  mkdir -p "$(dirname -- "$link_path")" "$target_path"

  if [[ -L "$link_path" ]]; then
    ln -sfn "$target_path" "$link_path"
    return 0
  fi

  if [[ -e "$link_path" && ! -d "$link_path" ]]; then
    say "Leaving existing $label alone because it is not a directory: $link_path"
    return 0
  fi

  if [[ -d "$link_path" ]]; then
    if directory_empty "$link_path"; then
      rmdir "$link_path"
    else
      say "Leaving existing non-empty $label alone: $link_path"
      say "  New recommended path: $target_path"
      return 0
    fi
  fi

  ln -s "$target_path" "$link_path"
}

vortex_roaming_dir_for_prefix() {
  local compat_data="$1"
  local pfx="$compat_data/pfx"
  local candidate
  local candidates=(
    "$pfx/drive_c/users/steamuser/AppData/Roaming/Vortex"
    "$pfx/drive_c/users/$USER/AppData/Roaming/Vortex"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -d "$(dirname -- "$candidate")" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf '%s\n' "$pfx/drive_c/users/steamuser/AppData/Roaming/Vortex"
}

configure_skyrim_vortex_storage() {
  local pfx="$COMPAT_DATA/pfx"
  local dosdevices="$pfx/dosdevices"
  local drive_link
  local roaming
  local default_staging
  local default_downloads

  if [[ -z "${SKYRIM_SE_GAME_DIR:-}" || -z "${SKYRIM_SE_LIBRARY_ROOT:-}" ]]; then
    return 0
  fi

  prepare_skyrim_vortex_paths

  mkdir -p "$dosdevices"
  drive_link="$dosdevices/$PROTON_VORTEX_DRIVE_LETTER:"
  if [[ -L "$drive_link" || ! -e "$drive_link" ]]; then
    ln -sfn "$SKYRIM_SE_LIBRARY_ROOT" "$drive_link"
  else
    say "Warning: Proton drive $PROTON_VORTEX_DRIVE_LETTER: already exists and is not a symlink: $drive_link"
  fi

  roaming="$(vortex_roaming_dir_for_prefix "$COMPAT_DATA")"
  default_staging="$roaming/${VORTEX_GAME_ID:-$SKYRIM_VORTEX_GAME_ID}/mods"
  default_downloads="$roaming/downloads"

  link_empty_or_missing_dir "$default_staging" "$VORTEX_SKYRIMSE_STAGING_DIR" "default Skyrim SE staging folder"
  link_empty_or_missing_dir "$default_downloads" "$VORTEX_DOWNLOADS_DIR" "default Vortex downloads folder"

  say "Prepared Vortex folders:"
  say "  Mod staging: $VORTEX_SKYRIMSE_STAGING_WIN_PATH"
  say "  Downloads:   $VORTEX_DOWNLOADS_WIN_PATH"
  say "  Game folder: $VORTEX_SKYRIMSE_GAME_WIN_PATH"
}

setup_skyrim_se() {
  if [[ -z "${SKYRIM_SE_GAME_DIR:-}" ]]; then
    return 0
  fi

  if [[ -f "$SKYRIM_SE_GAME_DIR/skse64_loader.exe" && "${SKSE_AUTO_UPDATE:-0}" != "1" ]]; then
    say "SKSE64 already exists in Skyrim SE; leaving it alone during wrapper update."
    say "To update SKSE64 later, run: proton-vortex-skyrim-se install-skse"
    say "To force SKSE64 during install, run: SKSE_AUTO_UPDATE=1 bash install.sh"
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

configure_prefix_ui() {
  local proton_dir="$1"

  if [[ "${PROTON_VORTEX_DPI:-0}" == "0" ]]; then
    return 0
  fi
  if [[ -z "${PROTON_VORTEX_DPI:-}" || "$PROTON_VORTEX_DPI" == *[!0-9]* ]]; then
    say "Warning: PROTON_VORTEX_DPI must be a number or 0; got '$PROTON_VORTEX_DPI'. Skipping DPI registry change."
    return 0
  fi

  say "Setting Windows DPI scale for Vortex UI: $PROTON_VORTEX_DPI"
  if ! run_proton_command "$proton_dir" run reg add 'HKCU\Control Panel\Desktop' /v Win8DpiScaling /t REG_DWORD /d 1 /f >/dev/null; then
    say "Warning: could not set Win8DpiScaling in the Proton prefix."
  fi
  if ! run_proton_command "$proton_dir" run reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d "$PROTON_VORTEX_DPI" /f >/dev/null; then
    say "Warning: could not set DPI scale in the Proton prefix."
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
  warn_if_old_proton "$PROTON_DIR"
  SKYRIM_SE_GAME_DIR=""
  SKYRIM_SE_LIBRARY_ROOT=""
  SKYRIM_SE_COMPAT_DATA=""

  if skyrim_info="$(find_skyrim_se "$STEAM_ROOT")"; then
    IFS=$'\t' read -r SKYRIM_SE_GAME_DIR SKYRIM_SE_LIBRARY_ROOT SKYRIM_SE_COMPAT_DATA <<<"$skyrim_info"
    if [[ "${VORTEX_STANDALONE_PREFIX:-0}" != "1" ]]; then
      COMPAT_DATA="$SKYRIM_SE_COMPAT_DATA"
      PROTON_APP_ID="$SKYRIM_APP_ID"
      VORTEX_GAME_ID="${VORTEX_GAME_ID:-$SKYRIM_VORTEX_GAME_ID}"
    fi
    prepare_skyrim_vortex_paths
  fi

  say "Steam:  $STEAM_ROOT"
  say "Proton: $PROTON_DIR"
  if [[ -n "$SKYRIM_SE_GAME_DIR" ]]; then
    say "Skyrim: $SKYRIM_SE_GAME_DIR"
    say "Prefix: $COMPAT_DATA"
  fi

  write_config "$STEAM_ROOT" "$PROTON_DIR"
  install_launcher
  install_icons
  ensure_proton_prefix "$PROTON_DIR"
  configure_skyrim_vortex_storage
  write_config "$STEAM_ROOT" "$PROTON_DIR"
  configure_prefix_ui "$PROTON_DIR"
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
    say "  Vortex staging: ${VORTEX_SKYRIMSE_STAGING_WIN_PATH:-not prepared}"
    say "  Vortex downloads: ${VORTEX_DOWNLOADS_WIN_PATH:-not prepared}"
    say "  Vortex game path: ${VORTEX_SKYRIMSE_GAME_WIN_PATH:-not prepared}"
    say "  Launch SKSE: proton-vortex-skyrim-se launch-skse"
    say "  Update SKSE: proton-vortex-skyrim-se install-skse"
    say "  Fix staging: proton-vortex-skyrim-se fix-staging"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
