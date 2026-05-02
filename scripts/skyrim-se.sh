#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

APP_ID="proton-vortex"
SKYRIM_APP_ID="489830"
SKSE_PAGE="https://skse.silverlock.org/"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
APP_HOME="$DATA_HOME/$APP_ID"
APP_CACHE="$CACHE_HOME/$APP_ID"
CONFIG_FILE="$APP_HOME/config.env"
SKSE_CACHE="$APP_CACHE/skse"

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

load_config() {
  if [[ ! -r "$CONFIG_FILE" ]]; then
    die "Config not found at $CONFIG_FILE. Run install.sh first."
  fi

  # shellcheck source=/dev/null
  . "$CONFIG_FILE"

  if [[ -z "${STEAM_ROOT:-}" || -z "${PROTON_DIR:-}" ]]; then
    die "Config is incomplete. Rerun install.sh."
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

find_skyrim_game_dir() {
  local library
  local manifest
  local installdir
  local game_dir

  if [[ -n "${SKYRIM_SE_GAME_DIR:-}" && -f "$SKYRIM_SE_GAME_DIR/SkyrimSE.exe" ]]; then
    printf '%s\n' "$SKYRIM_SE_GAME_DIR"
    return 0
  fi

  while IFS= read -r library; do
    [[ -n "$library" ]] || continue
    manifest="$library/steamapps/appmanifest_${SKYRIM_APP_ID}.acf"
    if [[ -r "$manifest" ]]; then
      installdir="$(acf_value "$manifest" installdir)"
      game_dir="$library/steamapps/common/$installdir"
      if [[ -f "$game_dir/SkyrimSE.exe" ]]; then
        printf '%s\n' "$game_dir"
        return 0
      fi
    fi
  done < <(steam_libraries "$STEAM_ROOT" | awk '!seen[$0]++')

  return 1
}

find_skyrim_library_root() {
  local game_dir="$1"
  local suffix="/steamapps/common/"

  case "$game_dir" in
    *"$suffix"*)
      printf '%s\n' "${game_dir%%$suffix*}"
      ;;
    *)
      return 1
      ;;
  esac
}

find_skyrim_compat_data() {
  local game_dir="$1"
  local library

  if [[ -n "${SKYRIM_SE_COMPAT_DATA:-}" ]]; then
    printf '%s\n' "$SKYRIM_SE_COMPAT_DATA"
    return 0
  fi

  library="$(find_skyrim_library_root "$game_dir")"
  printf '%s\n' "$library/steamapps/compatdata/$SKYRIM_APP_ID"
}

extractor_command() {
  if have 7zz; then
    printf '%s\n' "7zz"
  elif have 7z; then
    printf '%s\n' "7z"
  elif have bsdtar; then
    printf '%s\n' "bsdtar"
  fi
}

install_extractor_if_needed() {
  local extractor
  extractor="$(extractor_command || true)"

  if [[ -n "$extractor" ]]; then
    return 0
  fi

  if have apt-get && have sudo; then
    say "Installing a 7z extractor for SKSE..."
    sudo apt-get update
    sudo apt-get install -y 7zip || sudo apt-get install -y p7zip-full || sudo apt-get install -y libarchive-tools
    return 0
  fi

  if have apt-get && [[ "$(id -u)" == "0" ]]; then
    say "Installing a 7z extractor for SKSE..."
    apt-get update
    apt-get install -y 7zip || apt-get install -y p7zip-full || apt-get install -y libarchive-tools
    return 0
  fi

  die "No 7z extractor was found. Install 7zip, p7zip-full, or libarchive-tools, then rerun this command."
}

latest_skse_url() {
  local flavor="${1:-ae}"

  curl -fsSL "$SKSE_PAGE" | python3 -c '
import re
import sys
from urllib.parse import urljoin

flavor = sys.argv[1].lower()
html = sys.stdin.read()
patterns = {
    "ae": r"Current Anniversary Edition build.*?href=\"([^\"]+\.7z)\"",
    "gog": r"Current GOG Anniversary Edition build.*?href=\"([^\"]+\.7z)\"",
    "se": r"Current Special Edition build.*?href=\"([^\"]+\.7z)\"",
    "vr": r"Current VR build.*?href=\"([^\"]+\.7z)\"",
}

pattern = patterns.get(flavor)
if pattern is None:
    raise SystemExit(f"Unknown SKSE flavor: {flavor}")

match = re.search(pattern, html, re.IGNORECASE | re.DOTALL)
if not match:
    raise SystemExit(f"Could not find SKSE {flavor} download link.")

print(urljoin("https://skse.silverlock.org/", match.group(1)))
' "$flavor"
}

download_skse() {
  local flavor="${1:-ae}"
  local url
  local archive

  mkdir -p "$SKSE_CACHE"
  url="$(latest_skse_url "$flavor")"
  archive="$SKSE_CACHE/${url##*/}"

  if [[ -s "$archive" ]]; then
    say_err "Using cached SKSE archive: $archive"
  else
    say_err "Downloading SKSE from $SKSE_PAGE"
    curl -fL --retry 3 --retry-delay 2 -o "$archive" "$url"
  fi

  printf '%s\n' "$archive"
}

extract_skse() {
  local archive="$1"
  local dest="$2"
  local extractor

  extractor="$(extractor_command)"
  [[ -n "$extractor" ]] || die "No extractor command available."

  mkdir -p "$dest"

  case "$extractor" in
    7zz|7z)
      "$extractor" x -y "-o$dest" "$archive" >/dev/null
      ;;
    bsdtar)
      bsdtar -xf "$archive" -C "$dest"
      ;;
    *)
      die "Unsupported extractor: $extractor"
      ;;
  esac
}

install_skse_files() {
  local archive="$1"
  local game_dir="$2"
  local temp_dir
  local top_dir

  temp_dir="$(mktemp -d)"
  trap 'rm -rf -- "$temp_dir"; trap - RETURN' RETURN

  extract_skse "$archive" "$temp_dir"
  top_dir="$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d -name 'skse*' -print -quit)"
  [[ -n "$top_dir" ]] || die "The SKSE archive did not contain the expected top-level folder."

  cp -f "$top_dir"/skse64_*.dll "$game_dir"/
  cp -f "$top_dir"/skse64_loader.exe "$game_dir"/
  cp -f "$top_dir"/skse64_steam_loader.dll "$game_dir"/

  if [[ -d "$top_dir/Data" ]]; then
    mkdir -p "$game_dir/Data"
    cp -a "$top_dir/Data/." "$game_dir/Data/"
  fi
}

skse_status() {
  local game_dir="$1"

  if [[ -f "$game_dir/skse64_loader.exe" ]]; then
    say "SKSE loader: $game_dir/skse64_loader.exe"
  else
    say "SKSE loader: not installed"
  fi

  find "$game_dir" -maxdepth 1 -type f -name 'skse64_*.dll' -printf 'SKSE dll:    %f\n' 2>/dev/null | sort || true
}

install_skse() {
  local flavor="${SKSE_FLAVOR:-ae}"
  local game_dir
  local archive

  game_dir="$(find_skyrim_game_dir)" || die "Skyrim Special Edition was not found in Steam. Install it in Steam, run it once, then rerun this command."
  install_extractor_if_needed
  archive="$(download_skse "$flavor")"
  install_skse_files "$archive" "$game_dir"

  say "Installed SKSE64 ($flavor) into:"
  say "  $game_dir"
  skse_status "$game_dir"
}

launch_skse() {
  local game_dir
  local compat_data

  game_dir="$(find_skyrim_game_dir)" || die "Skyrim Special Edition was not found in Steam."
  compat_data="$(find_skyrim_compat_data "$game_dir")"

  if [[ ! -f "$game_dir/skse64_loader.exe" ]]; then
    say "SKSE is not installed yet. Installing it now..."
    install_skse
  fi

  mkdir -p "$compat_data"

  cd "$game_dir"
  STEAM_COMPAT_DATA_PATH="$compat_data" \
  STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT" \
  STEAM_COMPAT_APP_ID="$SKYRIM_APP_ID" \
  SteamAppId="$SKYRIM_APP_ID" \
  "$PROTON_DIR/proton" waitforexitandrun "$game_dir/skse64_loader.exe"
}

diagnose() {
  local game_dir
  local compat_data

  say "Skyrim SE helper"
  say "  steam root:  ${STEAM_ROOT:-not set}"
  say "  proton:      ${PROTON_DIR:-not set}"

  if game_dir="$(find_skyrim_game_dir)"; then
    compat_data="$(find_skyrim_compat_data "$game_dir")"
    say "  game dir:    $game_dir"
    say "  compatdata:  $compat_data"
    skse_status "$game_dir"
  else
    say "  game dir:    not found"
  fi
}

usage() {
  cat <<'EOF_HELP'
Usage:
  proton-vortex-skyrim-se install-skse
  proton-vortex-skyrim-se launch-skse
  proton-vortex-skyrim-se diagnose

Environment:
  SKSE_FLAVOR=ae   Latest Steam Skyrim SE / AE executable, currently 1.6.1170
  SKSE_FLAVOR=se   Downgraded Steam executable 1.5.97
EOF_HELP
}

main() {
  load_config

  case "${1:-diagnose}" in
    install-skse|install)
      install_skse
      ;;
    launch-skse|launch|play)
      launch_skse
      ;;
    diagnose|status)
      diagnose
      ;;
    --help|-h|help)
      usage
      ;;
    *)
      usage
      return 2
      ;;
  esac
}

main "$@"
