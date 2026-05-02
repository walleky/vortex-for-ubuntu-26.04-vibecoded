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

normalize_drive_letter() {
  local letter="${1:-s}"
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

  letter="$(normalize_drive_letter "${PROTON_VORTEX_DRIVE_LETTER:-s}")"
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

load_config() {
  if [[ ! -r "$CONFIG_FILE" ]]; then
    die "Config not found at $CONFIG_FILE. Run install.sh first."
  fi

  # shellcheck source=/dev/null
  . "$CONFIG_FILE"

  if [[ -z "${STEAM_ROOT:-}" || -z "${PROTON_DIR:-}" ]]; then
    die "Config is incomplete. Rerun install.sh."
  fi

  PROTON_VORTEX_WINEDEBUG="${PROTON_VORTEX_WINEDEBUG:--all}"
  PROTON_VORTEX_DRIVE_LETTER="$(normalize_drive_letter "${PROTON_VORTEX_DRIVE_LETTER:-s}")"
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

skyrim_library_root() {
  local game_dir="$1"

  if [[ -n "${SKYRIM_SE_LIBRARY_ROOT:-}" && -d "$SKYRIM_SE_LIBRARY_ROOT/steamapps" ]]; then
    printf '%s\n' "$SKYRIM_SE_LIBRARY_ROOT"
    return 0
  fi

  find_skyrim_library_root "$game_dir"
}

vortex_base_dir_for_library() {
  local library="$1"
  printf '%s\n' "${VORTEX_SKYRIMSE_BASE_DIR:-$library/VortexMods}"
}

vortex_prepared_staging_dir() {
  local library="$1"
  local base
  base="$(vortex_base_dir_for_library "$library")"
  printf '%s\n' "${VORTEX_SKYRIMSE_STAGING_DIR:-$base/skyrimse/mods}"
}

vortex_prepared_downloads_dir() {
  local library="$1"
  local base
  base="$(vortex_base_dir_for_library "$library")"
  printf '%s\n' "${VORTEX_DOWNLOADS_DIR:-$base/downloads}"
}

skyrim_runtime_version() {
  local exe="$1"

  [[ -f "$exe" ]] || return 1
  python3 - "$exe" <<'PY'
import re
import sys
from pathlib import Path

data = Path(sys.argv[1]).read_bytes()
keys = ("ProductVersion", "FileVersion")

for key in keys:
    needle = key.encode("utf-16le")
    start = 0
    while True:
        idx = data.find(needle, start)
        if idx == -1:
            break
        chunk = data[idx:idx + 512]
        try:
            text = chunk.decode("utf-16le", errors="ignore")
        except Exception:
            start = idx + len(needle)
            continue
        parts = [part.strip() for part in text.split("\x00") if part.strip()]
        try:
            key_index = parts.index(key)
        except ValueError:
            key_index = 0
        for part in parts[key_index + 1:]:
            match = re.search(r"\b(\d+\.\d+\.\d+(?:\.\d+)?)\b", part)
            if match:
                print(match.group(1))
                raise SystemExit(0)
        start = idx + len(needle)

raise SystemExit(1)
PY
}

recommended_skse_flavor() {
  local game_dir="$1"
  local runtime="${2:-}"

  if [[ -z "$runtime" ]]; then
    runtime="$(skyrim_runtime_version "$game_dir/SkyrimSE.exe" 2>/dev/null || true)"
  fi

  case "$runtime" in
    1.5.97|1.5.97.*)
      printf '%s\n' "se"
      ;;
    1.6.1179|1.6.1179.*)
      printf '%s\n' "gog"
      ;;
    1.6.*)
      printf '%s\n' "ae"
      ;;
    *)
      printf '%s\n' "ae"
      ;;
  esac
}

skse_flavor_label() {
  case "$1" in
    se)
      printf '%s\n' "Special Edition SKSE 2.0.20 for SkyrimSE.exe 1.5.97"
      ;;
    ae)
      printf '%s\n' "Anniversary Edition SKSE for Steam SkyrimSE.exe 1.6.x"
      ;;
    gog)
      printf '%s\n' "GOG Anniversary Edition SKSE for SkyrimSE.exe 1.6.1179"
      ;;
    vr)
      printf '%s\n' "VR SKSE"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

expected_skse_runtime_dll() {
  local runtime="$1"
  local runtime_base

  [[ -n "$runtime" ]] || return 1
  runtime_base="$runtime"
  if [[ "$runtime_base" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\.0$ ]]; then
    runtime_base="${BASH_REMATCH[1]}"
  fi

  printf 'skse64_%s.dll\n' "${runtime_base//./_}"
}

update_config_value() {
  local key="$1"
  local value="$2"
  local quoted
  local replacement
  local tmp

  [[ -r "$CONFIG_FILE" ]] || return 0
  quoted="$(printf '%q' "$value")"
  replacement="$key=$quoted"
  tmp="$(mktemp "${TMPDIR:-/tmp}/proton-vortex-config.XXXXXX")" || die "Could not create temporary config file."

  awk -v key="$key" -v replacement="$replacement" '
    BEGIN { done = 0 }
    index($0, key "=") == 1 {
      print replacement
      done = 1
      next
    }
    { print }
    END {
      if (done == 0) {
        print replacement
      }
    }
  ' "$CONFIG_FILE" >"$tmp"

  mv "$tmp" "$CONFIG_FILE"
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

link_picker_shortcut() {
  local link_path="$1"
  local target_path="$2"
  local label="$3"

  mkdir -p "$(dirname -- "$link_path")" "$target_path"

  if [[ -L "$link_path" || ! -e "$link_path" ]]; then
    ln -sfn "$target_path" "$link_path"
    return 0
  fi

  say "Leaving existing picker shortcut alone because it already exists: $link_path ($label)"
}

prefix_user_dirs() {
  local pfx="$1"
  local candidate
  local candidates=(
    "$pfx/drive_c/users/steamuser"
    "$pfx/drive_c/users/$USER"
  )

  for candidate in "$pfx"/drive_c/users/*; do
    candidates+=("$candidate")
  done

  for candidate in "${candidates[@]}"; do
    [[ -d "$candidate" ]] || continue
    case "$(basename -- "$candidate")" in
      Public|"All Users")
        continue
        ;;
    esac
    printf '%s\n' "$candidate"
  done | awk '!seen[$0]++'
}

write_picker_readme() {
  local file="$1"
  local game_win="$2"
  local staging_win="$3"
  local downloads_win="$4"

  cat >"$file" <<EOF_PICKER
Use these paths in Vortex:

Game folder:
$game_win

Mod Staging Folder:
$staging_win

Downloads Folder:
$downloads_win

Vortex SKSE tool, if automatic repair cannot patch Vortex:
Target:
C:\windows\system32\cmd.exe

Command Line:
/d /c "$game_win\Launch Skyrim SE SKSE.cmd"

Start In:
$game_win

Avoid choosing bare Z:\\. Z: is the whole Linux filesystem and many places are not writable.
EOF_PICKER
}

write_skse_launcher_cmd() {
  local file="$1"
  local game_win="$2"

  cat >"$file" <<EOF_BAT
@echo off
set "GAME_DIR=$game_win"
pushd "%GAME_DIR%"
if not exist "SkyrimSE.exe" (
  echo SkyrimSE.exe was not found in %CD%
  echo Vortex is launching SKSE from the wrong game folder.
  pause
  exit /b 1
)
if not exist "skse64_loader.exe" (
  echo skse64_loader.exe was not found in %CD%
  echo Run proton-vortex-skyrim-se install-skse, then try again.
  pause
  exit /b 1
)
"%GAME_DIR%\\skse64_loader.exe"
set "SKSE_EXIT=%ERRORLEVEL%"
popd
exit /b %SKSE_EXIT%
EOF_BAT
}

write_skse_game_launcher_cmd() {
  local file="$1"

  cat >"$file" <<'EOF_BAT'
@echo off
pushd "%~dp0"
if not exist "SkyrimSE.exe" (
  echo SkyrimSE.exe was not found in %CD%
  echo This batch file must live in the Skyrim Special Edition game folder.
  pause
  exit /b 1
)
if not exist "skse64_loader.exe" (
  echo skse64_loader.exe was not found in %CD%
  echo Run proton-vortex-skyrim-se install-skse, then try again.
  pause
  exit /b 1
)
".\skse64_loader.exe"
set "SKSE_EXIT=%ERRORLEVEL%"
popd
exit /b %SKSE_EXIT%
EOF_BAT
}

write_skse_launcher_bat() {
  write_skse_launcher_cmd "$@"
}

write_skse_game_launcher_bat() {
  write_skse_game_launcher_cmd "$@"
}

create_vortex_picker_helpers() {
  local pfx="$1"
  local base_dir="$2"
  local staging_dir="$3"
  local downloads_dir="$4"
  local game_dir="$5"
  local game_win="$6"
  local staging_win="$7"
  local downloads_win="$8"
  local user_dir
  local desktop
  local docs

  while IFS= read -r user_dir; do
    desktop="$user_dir/Desktop"
    docs="$user_dir/Documents"
    mkdir -p "$desktop" "$docs"

    link_picker_shortcut "$desktop/VortexMods Steam Library" "$base_dir" "VortexMods base"
    link_picker_shortcut "$desktop/Vortex Staging Skyrim SE" "$staging_dir" "Skyrim SE staging"
    link_picker_shortcut "$desktop/Vortex Downloads" "$downloads_dir" "Vortex downloads"
    link_picker_shortcut "$desktop/Skyrim Special Edition" "$game_dir" "Skyrim SE game folder"

    write_picker_readme "$desktop/PROTON_VORTEX_PATHS.txt" "$game_win" "$staging_win" "$downloads_win"
    write_picker_readme "$docs/PROTON_VORTEX_PATHS.txt" "$game_win" "$staging_win" "$downloads_win"
    write_skse_launcher_cmd "$desktop/Launch Skyrim SE SKSE.cmd" "$game_win"
    write_skse_game_launcher_cmd "$game_dir/Launch Skyrim SE SKSE.cmd"
    write_skse_launcher_bat "$desktop/Launch Skyrim SE SKSE.bat" "$game_win"
    write_skse_game_launcher_bat "$game_dir/Launch Skyrim SE SKSE.bat"
  done < <(prefix_user_dirs "$pfx")
}

same_device() {
  local left="$1"
  local right="$2"
  [[ -e "$left" && -e "$right" ]] || return 1
  [[ "$(stat -c %d "$left" 2>/dev/null)" == "$(stat -c %d "$right" 2>/dev/null)" ]]
}

vortex_roaming_dir() {
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

vortex_staging_dir() {
  local compat_data="$1"
  local game_id="${VORTEX_GAME_ID:-skyrimse}"
  printf '%s/%s/mods\n' "$(vortex_roaming_dir "$compat_data")" "$game_id"
}

find_vortex_exe() {
  local compat_data="${1:-$COMPAT_DATA}"
  local pfx="$compat_data/pfx"
  local candidate
  local candidates=(
    "$pfx/drive_c/users/steamuser/AppData/Local/Programs/Vortex/Vortex.exe"
    "$pfx/drive_c/users/$USER/AppData/Local/Programs/Vortex/Vortex.exe"
    "$pfx/drive_c/Program Files/Vortex/Vortex.exe"
    "$pfx/drive_c/Program Files (x86)/Vortex/Vortex.exe"
  )

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

json_string() {
  python3 - "$1" <<'PY'
import json
import sys

print(json.dumps(sys.argv[1]))
PY
}

json_array() {
  python3 - "$@" <<'PY'
import json
import sys

print(json.dumps(sys.argv[1:]))
PY
}

vortex_cli_set_many() {
  local vortex_exe="$1"
  shift
  local output
  local status

  if [[ $# -eq 0 ]]; then
    return 0
  fi

  set +e
  output="$(
    STEAM_COMPAT_DATA_PATH="$COMPAT_DATA" \
    STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT" \
    STEAM_COMPAT_APP_ID="${PROTON_APP_ID:-$SKYRIM_APP_ID}" \
    SteamAppId="${PROTON_APP_ID:-$SKYRIM_APP_ID}" \
    WINEDEBUG="$PROTON_VORTEX_WINEDEBUG" \
    "$PROTON_DIR/proton" waitforexitandrun "$vortex_exe" "$@" 2>&1
  )"
  status=$?
  set -e

  if ((status != 0)) || grep -Eiq 'database is locked|another instance|failed|error|locked' <<<"$output"; then
    say "Vortex state repair did not complete."
    if [[ -n "$output" ]]; then
      say "$output"
    fi
    say "Close Vortex completely, then rerun: proton-vortex-skyrim-se fix-skse-launcher"
    return 1
  fi

  return 0
}

repair_vortex_skse_state() {
  local game_win="$1"
  local vortex_exe
  local skse_exe_win
  local cmd_exe_win="C:\\windows\\system32\\cmd.exe"
  local launch_cmd_win="$game_win\\Launch Skyrim SE SKSE.cmd"
  local set_args=()

  vortex_exe="$(find_vortex_exe "$COMPAT_DATA" || true)"
  if [[ -z "$vortex_exe" ]]; then
    say "Vortex.exe was not found, so I could not patch Vortex's SKSE tool automatically."
    return 1
  fi

  skse_exe_win="$game_win\\skse64_loader.exe"
  say "Patching Vortex's Skyrim SE path and SKSE launcher state..."
  say "  Vortex.exe: $vortex_exe"
  say "  Game path:  $game_win"

  set_args+=("--set" "settings.gameMode.discovered.skyrimse.path=$(json_string "$game_win")")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.pathSetManually=true")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.store=$(json_string "steam")")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.executable=$(json_string "SkyrimSE.exe")")

  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.skse64.id=$(json_string "skse64")")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.skse64.name=$(json_string "Skyrim Script Extender 64")")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.skse64.shortName=$(json_string "SKSE64")")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.skse64.path=$(json_string "$skse_exe_win")")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.skse64.workingDirectory=$(json_string "$game_win")")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.skse64.parameters=[]")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.skse64.hidden=false")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.skse64.custom=false")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.skse64.relative=true")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.skse64.exclusive=true")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.skse64.defaultPrimary=true")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.skse64.detach=true")

  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.proton-vortex-skse.id=$(json_string "proton-vortex-skse")")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.proton-vortex-skse.name=$(json_string "Skyrim SE SKSE Proton Fixed")")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.proton-vortex-skse.shortName=$(json_string "SKSE")")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.proton-vortex-skse.path=$(json_string "$cmd_exe_win")")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.proton-vortex-skse.workingDirectory=$(json_string "$game_win")")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.proton-vortex-skse.parameters=$(json_array "/d" "/c" "$launch_cmd_win")")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.proton-vortex-skse.hidden=false")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.proton-vortex-skse.custom=true")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.proton-vortex-skse.shell=false")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.proton-vortex-skse.detach=false")
  set_args+=("--set" "settings.gameMode.discovered.skyrimse.tools.proton-vortex-skse.defaultPrimary=true")
  set_args+=("--set" "settings.interface.primaryTool.skyrimse=$(json_string "proton-vortex-skse")")

  vortex_cli_set_many "$vortex_exe" "${set_args[@]}"
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

archive_contains_basename() {
  local archive="$1"
  local wanted="$2"
  local extractor

  extractor="$(extractor_command)"
  [[ -n "$extractor" ]] || die "No extractor command available."

  case "$extractor" in
    7zz|7z)
      "$extractor" l -ba "$archive" 2>/dev/null
      ;;
    bsdtar)
      bsdtar -tf "$archive" 2>/dev/null
      ;;
    *)
      die "Unsupported extractor: $extractor"
      ;;
  esac | awk -v wanted="$wanted" '
    {
      line = $0
      gsub(/\\/, "/", line)
      n = split(line, parts, "/")
      tail = parts[n]
      split(tail, fields, /[[:space:]]+/)
      if (tail == wanted || fields[length(fields)] == wanted) {
        found = 1
      }
    }
    END {
      exit(found ? 0 : 1)
    }
  '
}

validate_skse_archive_for_runtime() {
  local archive="$1"
  local runtime="$2"
  local expected_dll

  [[ -n "$runtime" ]] || return 0
  expected_dll="$(expected_skse_runtime_dll "$runtime")" || return 0

  if archive_contains_basename "$archive" "$expected_dll"; then
    say "SKSE archive matches Skyrim runtime: $expected_dll"
    return 0
  fi

  die "Downloaded SKSE archive does not contain $expected_dll for SkyrimSE.exe runtime $runtime. Your game runtime and SKSE flavor do not match; run proton-vortex-skyrim-se diagnose, then retry with the right SKSE_FLAVOR or update/downgrade Skyrim to a supported runtime."
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
  local runtime
  local expected_dll
  local flavor

  if [[ -f "$game_dir/skse64_loader.exe" ]]; then
    say "SKSE loader: $game_dir/skse64_loader.exe"
  else
    say "SKSE loader: not installed"
  fi

  runtime="$(skyrim_runtime_version "$game_dir/SkyrimSE.exe" 2>/dev/null || true)"
  if [[ -n "$runtime" ]]; then
    flavor="$(recommended_skse_flavor "$game_dir" "$runtime")"
    say "Skyrim runtime: $runtime"
    say "Recommended SKSE: $flavor ($(skse_flavor_label "$flavor"))"
    expected_dll="$(expected_skse_runtime_dll "$runtime")"
    if [[ -f "$game_dir/$expected_dll" ]]; then
      say "SKSE runtime dll: $expected_dll"
    else
      say "SKSE runtime dll: missing $expected_dll"
      say "Fix: run proton-vortex-skyrim-se install-skse"
    fi
  else
    say "Skyrim runtime: unknown"
    say "Recommended SKSE: ae fallback unless you know this is downgraded SkyrimSE.exe 1.5.97"
  fi

  find "$game_dir" -maxdepth 1 -type f -name 'skse64_*.dll' -printf 'SKSE dll:    %f\n' 2>/dev/null | sort || true
}

find_plugins_txt() {
  local compat_data="$1"
  local user_dir
  local candidates=(
    "$compat_data/pfx/drive_c/users/steamuser/AppData/Local/Skyrim Special Edition/plugins.txt"
    "$compat_data/pfx/drive_c/users/$USER/AppData/Local/Skyrim Special Edition/plugins.txt"
  )

  for user_dir in "$compat_data"/pfx/drive_c/users/*/AppData/Local/Skyrim\ Special\ Edition/plugins.txt; do
    candidates+=("$user_dir")
  done

  for user_dir in "${candidates[@]}"; do
    if [[ -f "$user_dir" ]]; then
      printf '%s\n' "$user_dir"
      return 0
    fi
  done

  return 1
}

count_data_plugins() {
  local data_dir="$1"
  [[ -d "$data_dir" ]] || { printf '0\n'; return 0; }
  find "$data_dir" -maxdepth 1 -type f \( -iname '*.esm' -o -iname '*.esp' -o -iname '*.esl' \) 2>/dev/null | wc -l | tr -d '[:space:]'
}

count_enabled_plugins_txt() {
  local plugins_txt="$1"
  [[ -f "$plugins_txt" ]] || { printf '0\n'; return 0; }
  grep -E '^\*.*\.(esm|esp|esl)$' "$plugins_txt" 2>/dev/null | wc -l | tr -d '[:space:]'
}

voice_archive_count() {
  local data_dir="$1"
  [[ -d "$data_dir" ]] || { printf '0\n'; return 0; }
  find "$data_dir" -maxdepth 1 -type f -iname 'Skyrim - Voices*.bsa' 2>/dev/null | wc -l | tr -d '[:space:]'
}

deployment_status() {
  local game_dir
  local library
  local compat_data
  local data_dir
  local prepared_staging
  local prepared_downloads
  local plugins_txt=""
  local data_plugins
  local enabled_plugins
  local voices

  game_dir="$(find_skyrim_game_dir)" || die "Skyrim Special Edition was not found in Steam."
  library="$(skyrim_library_root "$game_dir")" || die "Could not determine Skyrim's Steam library root."
  compat_data="$(find_skyrim_compat_data "$game_dir")"
  data_dir="$game_dir/Data"
  prepared_staging="$(vortex_prepared_staging_dir "$library")"
  prepared_downloads="$(vortex_prepared_downloads_dir "$library")"

  say "Skyrim SE deployment/audio check"
  say "  game dir:   $game_dir"
  say "  data dir:   $data_dir"
  say "  prefix:     $compat_data"
  say "  default staging:  $(vortex_staging_dir "$compat_data")"
  say "  prepared staging: $prepared_staging"
  say "  prepared downloads: $prepared_downloads"
  if [[ -d "$library" ]]; then
    say "  Proton drive hint: ${PROTON_VORTEX_DRIVE_LETTER^^}:\\ maps to $library"
    say "  Vortex game path:  $(windows_path_hint "$library" "$game_dir")"
    say "  Vortex staging:    $(windows_path_hint "$library" "$prepared_staging")"
  fi

  if [[ -d "$data_dir" ]]; then
    say "  Data folder: present"
  else
    say "  Data folder: missing"
    say "  Fix: run Skyrim once from Steam, then rerun bash install.sh"
    return 1
  fi

  voices="$(voice_archive_count "$data_dir")"
  if [[ "$voices" != "0" ]]; then
    say "  voice BSA:  present ($voices)"
    find "$data_dir" -maxdepth 1 -type f -iname 'Skyrim - Voices*.bsa' -printf '    %f\n' 2>/dev/null | sort
  else
    say "  voice BSA:  missing"
    say "  Fix: in Steam, verify Skyrim Special Edition files and check the game language."
  fi

  [[ -f "$data_dir/Skyrim - Sounds.bsa" ]] && say "  sounds BSA: present" || say "  sounds BSA: missing"

  data_plugins="$(count_data_plugins "$data_dir")"
  say "  plugin files in Data: $data_plugins"

  if plugins_txt="$(find_plugins_txt "$compat_data")"; then
    enabled_plugins="$(count_enabled_plugins_txt "$plugins_txt")"
    say "  plugins.txt: $plugins_txt"
    say "  enabled plugins in plugins.txt: $enabled_plugins"
  else
    say "  plugins.txt: not found"
    say "  Fix: launch Skyrim once, then deploy in Vortex."
  fi

  if [[ "${data_plugins:-0}" -le 5 ]]; then
    say "  note: Data has few plugin files. This can be normal for texture-only mods, but if you expected plugins, Vortex may not have deployed them."
  fi

  if [[ -d "$prepared_staging" ]]; then
    if same_device "$data_dir" "$prepared_staging"; then
      say "  prepared staging/Data filesystem: same"
    else
      say "  prepared staging/Data filesystem: different"
      say "  Fix: run proton-vortex-skyrim-se fix-staging and keep Vortex staging on the same filesystem as Skyrim."
    fi
  else
    say "  prepared staging folder: not found yet"
    say "  Fix: run proton-vortex-skyrim-se fix-staging"
  fi

  say ""
  say "Vortex checklist:"
  say "  1. Use the Skyrim entry matching: $(windows_path_hint "$library" "$game_dir")"
  say "  2. Mods tab: Installed and Enabled"
  say "  3. Plugins tab: plugins Enabled"
  say "  4. Click Deploy Mods"
  say "  5. Launch: proton-vortex-skyrim-se launch-skse"
  say "  6. If Vortex says staging is not writable, run: proton-vortex-skyrim-se fix-staging"
  say "  7. If Deploy Mods fails, run: proton-vortex-skyrim-se hardlink-test \"$prepared_staging\""
}

hardlink_test() {
  local requested_staging="${1:-}"
  local game_dir
  local library
  local data_dir
  local staging_dir
  local source_file
  local target_file

  game_dir="$(find_skyrim_game_dir)" || die "Skyrim Special Edition was not found in Steam."
  library="$(skyrim_library_root "$game_dir")" || die "Could not determine Skyrim's Steam library root."
  data_dir="$game_dir/Data"
  if [[ -n "$requested_staging" ]]; then
    staging_dir="$requested_staging"
  elif [[ -n "${VORTEX_SKYRIMSE_STAGING_DIR:-}" ]]; then
    staging_dir="$VORTEX_SKYRIMSE_STAGING_DIR"
  else
    staging_dir="$(vortex_prepared_staging_dir "$library")"
  fi

  [[ -d "$data_dir" ]] || die "Skyrim Data folder missing: $data_dir"
  mkdir -p "$staging_dir"

  source_file="$(mktemp "$staging_dir/.proton-vortex-hardlink-source.XXXXXX")" || die "Could not create test file in staging folder: $staging_dir"
  target_file="$data_dir/.proton-vortex-hardlink-test"
  if [[ -e "$target_file" ]]; then
    rm -f -- "$source_file"
    die "Test target already exists, refusing to overwrite: $target_file"
  fi

  cleanup_hardlink_test() {
    trap - RETURN
    rm -f -- "${source_file:-}" "${target_file:-}"
  }
  trap cleanup_hardlink_test RETURN

  printf 'proton-vortex hardlink test\n' >"$source_file"

  say "Hardlink deployment test"
  say "  staging: $staging_dir"
  say "  data:    $data_dir"
  if [[ -n "$requested_staging" ]]; then
    say "  source:  custom staging folder"
  elif [[ "$staging_dir" == "$(vortex_prepared_staging_dir "$library")" ]]; then
    say "  source:  prepared Steam-library staging folder"
  else
    say "  source:  expected Vortex skyrimse staging folder"
  fi

  if ! same_device "$staging_dir" "$data_dir"; then
    say "  result:  fail"
    say "  reason:  staging and Skyrim Data are on different filesystems"
    say "  fix:     in Vortex Settings > Mods, set staging to a folder on the same filesystem as Skyrim"
    return 1
  fi

  if ln "$source_file" "$target_file" 2>/dev/null; then
    if [[ "$(stat -c %i "$source_file" 2>/dev/null)" == "$(stat -c %i "$target_file" 2>/dev/null)" ]]; then
      say "  result:  ok"
      say "  meaning: hardlink deployment should be possible here"
      return 0
    fi
    say "  result:  fail"
    say "  reason:  test link was created but did not share the same inode"
    return 1
  fi

  say "  result:  fail"
  say "  reason:  Linux could not create a hardlink into Skyrim Data"
  say "  fixes:   close Skyrim/Vortex, check folder permissions, and keep staging on the same filesystem as Skyrim"
  return 1
}

fix_staging() {
  local game_dir
  local library
  local compat_data
  local pfx
  local dosdevices
  local drive_link
  local roaming
  local default_staging
  local default_downloads
  local staging_dir
  local downloads_dir
  local game_win
  local staging_win
  local downloads_win
  local test_file
  local base_dir

  game_dir="$(find_skyrim_game_dir)" || die "Skyrim Special Edition was not found in Steam."
  library="$(skyrim_library_root "$game_dir")" || die "Could not determine Skyrim's Steam library root."
  compat_data="$(find_skyrim_compat_data "$game_dir")"
  pfx="$compat_data/pfx"
  [[ -d "$pfx/drive_c" ]] || die "Proton prefix missing at $pfx. Run Skyrim once from Steam, then rerun bash install.sh."

  staging_dir="$(vortex_prepared_staging_dir "$library")"
  downloads_dir="$(vortex_prepared_downloads_dir "$library")"

  mkdir -p "$staging_dir" "$downloads_dir"

  test_file="$staging_dir/.proton-vortex-write-test"
  printf 'ok\n' >"$test_file" || die "Cannot write to prepared staging folder: $staging_dir"
  rm -f -- "$test_file"

  test_file="$downloads_dir/.proton-vortex-write-test"
  printf 'ok\n' >"$test_file" || die "Cannot write to prepared downloads folder: $downloads_dir"
  rm -f -- "$test_file"

  dosdevices="$pfx/dosdevices"
  mkdir -p "$dosdevices"
  drive_link="$dosdevices/$PROTON_VORTEX_DRIVE_LETTER:"
  if [[ -L "$drive_link" || ! -e "$drive_link" ]]; then
    ln -sfn "$library" "$drive_link"
  else
    say "Warning: Proton drive $PROTON_VORTEX_DRIVE_LETTER: already exists and is not a symlink: $drive_link"
  fi

  roaming="$(vortex_roaming_dir "$compat_data")"
  default_staging="$roaming/${VORTEX_GAME_ID:-skyrimse}/mods"
  default_downloads="$roaming/downloads"
  link_empty_or_missing_dir "$default_staging" "$staging_dir" "default Skyrim SE staging folder"
  link_empty_or_missing_dir "$default_downloads" "$downloads_dir" "default Vortex downloads folder"

  game_win="$(windows_path_hint "$library" "$game_dir")"
  staging_win="$(windows_path_hint "$library" "$staging_dir")"
  downloads_win="$(windows_path_hint "$library" "$downloads_dir")"
  base_dir="$(vortex_base_dir_for_library "$library")"
  create_vortex_picker_helpers "$pfx" "$base_dir" "$staging_dir" "$downloads_dir" "$game_dir" "$game_win" "$staging_win" "$downloads_win"

  say "Prepared writable Vortex folders"
  say "  Linux staging:   $staging_dir"
  say "  Linux downloads: $downloads_dir"
  say "  Proton drive:    ${PROTON_VORTEX_DRIVE_LETTER^^}: maps to $library"
  say "  Picker help:     C:\\users\\steamuser\\Desktop\\PROTON_VORTEX_PATHS.txt"
  say "  SKSE helper:     C:\\users\\steamuser\\Desktop\\Launch Skyrim SE SKSE.cmd"
  say ""
  say "Use these inside Vortex if it asks for folders:"
  say "  Game folder:        $game_win"
  say "  Mod Staging Folder: $staging_win"
  say "  Downloads Folder:   $downloads_win"
  say ""
  say "Do not create folders at bare Z:\\. In Proton, Z: is your whole Linux filesystem and many parts are not writable."
  say "If Vortex says the destination folder has to be empty, run: proton-vortex-skyrim-se empty-staging"
  say "If Vortex already has a wrong Skyrim entry, manage the entry whose game folder matches the Game folder above."
  say ""
  hardlink_test "$staging_dir"
}

empty_staging() {
  local game_dir
  local library
  local compat_data
  local pfx
  local dosdevices
  local drive_link
  local base_dir
  local staging_parent
  local staging_dir
  local downloads_dir
  local game_win
  local staging_win
  local downloads_win
  local test_file
  local stamp
  local suffix=""
  local attempt=0

  game_dir="$(find_skyrim_game_dir)" || die "Skyrim Special Edition was not found in Steam."
  library="$(skyrim_library_root "$game_dir")" || die "Could not determine Skyrim's Steam library root."
  compat_data="$(find_skyrim_compat_data "$game_dir")"
  pfx="$compat_data/pfx"
  [[ -d "$pfx/drive_c" ]] || die "Proton prefix missing at $pfx. Run Skyrim once from Steam, then rerun bash install.sh."

  base_dir="$(vortex_base_dir_for_library "$library")"
  staging_parent="$base_dir/skyrimse"
  downloads_dir="$(vortex_prepared_downloads_dir "$library")"
  mkdir -p "$staging_parent" "$downloads_dir"

  stamp="$(date +%Y%m%d-%H%M%S)"
  while :; do
    staging_dir="$staging_parent/empty-staging-$stamp$suffix"
    [[ ! -e "$staging_dir" ]] && break
    attempt=$((attempt + 1))
    suffix="-$attempt"
  done

  mkdir -p "$staging_dir"
  if ! directory_empty "$staging_dir"; then
    die "Fresh staging folder is unexpectedly not empty: $staging_dir"
  fi

  test_file="$staging_dir/.proton-vortex-write-test"
  printf 'ok\n' >"$test_file" || die "Cannot write to fresh staging folder: $staging_dir"
  rm -f -- "$test_file"

  dosdevices="$pfx/dosdevices"
  mkdir -p "$dosdevices"
  drive_link="$dosdevices/$PROTON_VORTEX_DRIVE_LETTER:"
  if [[ -L "$drive_link" || ! -e "$drive_link" ]]; then
    ln -sfn "$library" "$drive_link"
  else
    say "Warning: Proton drive $PROTON_VORTEX_DRIVE_LETTER: already exists and is not a symlink: $drive_link"
  fi

  game_win="$(windows_path_hint "$library" "$game_dir")"
  staging_win="$(windows_path_hint "$library" "$staging_dir")"
  downloads_win="$(windows_path_hint "$library" "$downloads_dir")"

  hardlink_test "$staging_dir"

  VORTEX_SKYRIMSE_STAGING_DIR="$staging_dir"
  VORTEX_SKYRIMSE_STAGING_WIN_PATH="$staging_win"
  update_config_value VORTEX_SKYRIMSE_STAGING_DIR "$staging_dir"
  update_config_value VORTEX_SKYRIMSE_STAGING_WIN_PATH "$staging_win"

  create_vortex_picker_helpers "$pfx" "$base_dir" "$staging_dir" "$downloads_dir" "$game_dir" "$game_win" "$staging_win" "$downloads_win"

  say ""
  say "Fresh empty Vortex staging folder created"
  say "  Linux folder: $staging_dir"
  say "  Vortex path:  $staging_win"
  say ""
  say "Use this in Vortex Settings > Mods > Mod Staging Folder when it says the destination has to be empty:"
  say "  $staging_win"
  say ""
  say "This did not delete or move your old staging folder. If Vortex offers to move existing mods into this empty folder, allow it."
}

fix_skse_launcher() {
  local game_dir
  local library
  local compat_data
  local pfx
  local dosdevices
  local drive_link
  local base_dir
  local staging_dir
  local downloads_dir
  local game_win
  local staging_win
  local downloads_win

  game_dir="$(find_skyrim_game_dir)" || die "Skyrim Special Edition was not found in Steam."
  library="$(skyrim_library_root "$game_dir")" || die "Could not determine Skyrim's Steam library root."
  compat_data="$(find_skyrim_compat_data "$game_dir")"
  pfx="$compat_data/pfx"
  [[ -d "$pfx/drive_c" ]] || die "Proton prefix missing at $pfx. Run Skyrim once from Steam, then rerun bash install.sh."

  if [[ ! -f "$game_dir/skse64_loader.exe" ]]; then
    say "SKSE is not installed yet. Installing it now..."
    install_skse
  fi
  [[ -f "$game_dir/SkyrimSE.exe" ]] || die "SkyrimSE.exe is missing from the detected game folder: $game_dir"

  dosdevices="$pfx/dosdevices"
  mkdir -p "$dosdevices"
  drive_link="$dosdevices/$PROTON_VORTEX_DRIVE_LETTER:"
  if [[ -L "$drive_link" || ! -e "$drive_link" ]]; then
    ln -sfn "$library" "$drive_link"
  else
    say "Warning: Proton drive $PROTON_VORTEX_DRIVE_LETTER: already exists and is not a symlink: $drive_link"
  fi

  base_dir="$(vortex_base_dir_for_library "$library")"
  staging_dir="$(vortex_prepared_staging_dir "$library")"
  downloads_dir="$(vortex_prepared_downloads_dir "$library")"
  mkdir -p "$base_dir" "$staging_dir" "$downloads_dir"

  game_win="$(windows_path_hint "$library" "$game_dir")"
  staging_win="$(windows_path_hint "$library" "$staging_dir")"
  downloads_win="$(windows_path_hint "$library" "$downloads_dir")"
  create_vortex_picker_helpers "$pfx" "$base_dir" "$staging_dir" "$downloads_dir" "$game_dir" "$game_win" "$staging_win" "$downloads_win"
  repair_vortex_skse_state "$game_win" || return 1

  say "Repaired SKSE launch helpers"
  say "  Game folder:      $game_win"
  say "  Vortex tool file: $game_win\\Launch Skyrim SE SKSE.cmd"
  say "  Desktop helper:   C:\\users\\steamuser\\Desktop\\Launch Skyrim SE SKSE.cmd"
  say ""
  say "Vortex was patched to use the Proton-safe SKSE launcher as the primary tool."
  say "If you still edit it manually in Vortex, use:"
  say "  Target:       C:\\windows\\system32\\cmd.exe"
  say "  Command Line: /d /c \"$game_win\\Launch Skyrim SE SKSE.cmd\""
  say "  Start in:     $game_win"
  say ""
  say "Guaranteed Linux launch path:"
  say "  proton-vortex-skyrim-se launch-skse"
}

audio_fix() {
  local game_dir
  local compat_data

  game_dir="$(find_skyrim_game_dir)" || die "Skyrim Special Edition was not found in Steam."
  compat_data="$(find_skyrim_compat_data "$game_dir")"
  [[ -d "$compat_data/pfx" ]] || die "Proton prefix missing at $compat_data/pfx. Run Skyrim once in Steam, then rerun this command."

  say "This installs the xact audio component into Skyrim SE's Proton prefix."
  say "It is meant for the Linux/Proton issue where music/effects work but NPC voices are silent."

  if have protontricks; then
    protontricks "$SKYRIM_APP_ID" xact
  elif have winetricks; then
    WINEPREFIX="$compat_data/pfx" winetricks --force xact
  else
    die "Install protontricks or winetricks first. On Ubuntu try: sudo apt install protontricks winetricks"
  fi
}

install_skse() {
  local flavor="${SKSE_FLAVOR:-}"
  local game_dir
  local archive
  local runtime

  game_dir="$(find_skyrim_game_dir)" || die "Skyrim Special Edition was not found in Steam. Install it in Steam, run it once, then rerun this command."
  runtime="$(skyrim_runtime_version "$game_dir/SkyrimSE.exe" 2>/dev/null || true)"
  if [[ -z "$flavor" || "$flavor" == "auto" ]]; then
    flavor="$(recommended_skse_flavor "$game_dir" "$runtime")"
  fi

  if [[ -n "$runtime" ]]; then
    say "Detected SkyrimSE.exe runtime: $runtime"
  else
    say "Warning: could not detect SkyrimSE.exe runtime; defaulting SKSE flavor to '$flavor'."
  fi
  say "Using SKSE flavor: $flavor ($(skse_flavor_label "$flavor"))"

  install_extractor_if_needed
  archive="$(download_skse "$flavor")"
  validate_skse_archive_for_runtime "$archive" "$runtime"
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
  WINEDEBUG="$PROTON_VORTEX_WINEDEBUG" \
  "$PROTON_DIR/proton" waitforexitandrun "$game_dir/skse64_loader.exe"
}

diagnose() {
  local game_dir
  local compat_data
  local picker_help
  local skse_bat
  local skse_cmd
  local game_skse_bat
  local game_skse_cmd

  say "Skyrim SE helper"
  say "  steam root:  ${STEAM_ROOT:-not set}"
  say "  proton:      ${PROTON_DIR:-not set}"

  if game_dir="$(find_skyrim_game_dir)"; then
    compat_data="$(find_skyrim_compat_data "$game_dir")"
    say "  game dir:    $game_dir"
    say "  compatdata:  $compat_data"
    skse_status "$game_dir"
    picker_help="$compat_data/pfx/drive_c/users/steamuser/Desktop/PROTON_VORTEX_PATHS.txt"
    skse_bat="$compat_data/pfx/drive_c/users/steamuser/Desktop/Launch Skyrim SE SKSE.bat"
    skse_cmd="$compat_data/pfx/drive_c/users/steamuser/Desktop/Launch Skyrim SE SKSE.cmd"
    if [[ -f "$picker_help" ]]; then
      say "  picker help: $picker_help"
    else
      say "  picker help: missing; run proton-vortex-skyrim-se fix-staging"
    fi
    if [[ -f "$skse_cmd" ]]; then
      say "  Vortex SKSE helper: $skse_cmd"
    elif [[ -f "$skse_bat" ]]; then
      say "  Vortex SKSE helper: $skse_bat"
    else
      say "  Vortex SKSE helper: missing; run proton-vortex-skyrim-se fix-staging"
    fi
    game_skse_bat="$game_dir/Launch Skyrim SE SKSE.bat"
    game_skse_cmd="$game_dir/Launch Skyrim SE SKSE.cmd"
    if [[ -f "$game_skse_cmd" ]]; then
      say "  Game-folder SKSE helper: $game_skse_cmd"
    elif [[ -f "$game_skse_bat" ]]; then
      say "  Game-folder SKSE helper: $game_skse_bat"
    else
      say "  Game-folder SKSE helper: missing; run proton-vortex-skyrim-se fix-skse-launcher"
    fi
    say ""
    say "To verify SKSE in-game:"
    say "  1. Launch: proton-vortex-skyrim-se launch-skse"
    say "  2. Open the Skyrim console with ~"
    say "  3. Run: getskseversion"
    say "  If Vortex says SKSE could not find SkyrimSE.exe: proton-vortex-skyrim-se fix-skse-launcher"
    say ""
    say "To check deployment/audio:"
    say "  proton-vortex-skyrim-se deployment"
    say "  proton-vortex-skyrim-se fix-staging"
    say "  proton-vortex-skyrim-se empty-staging"
    say "  proton-vortex-skyrim-se hardlink-test"
    say "  proton-vortex-skyrim-se audio-check"
  else
    say "  game dir:    not found"
  fi
}

usage() {
  cat <<'EOF_HELP'
Usage:
  proton-vortex-skyrim-se install-skse
  proton-vortex-skyrim-se launch-skse
  proton-vortex-skyrim-se fix-skse-launcher
  proton-vortex-skyrim-se force-vortex-skse
  proton-vortex-skyrim-se diagnose
  proton-vortex-skyrim-se deployment
  proton-vortex-skyrim-se fix-staging
  proton-vortex-skyrim-se empty-staging
  proton-vortex-skyrim-se hardlink-test [staging-folder]
  proton-vortex-skyrim-se audio-check
  proton-vortex-skyrim-se audio-fix

Environment:
  SKSE_FLAVOR=auto Default behavior; detect SkyrimSE.exe runtime
  SKSE_FLAVOR=ae   Steam Skyrim SE / AE executable 1.6.x
  SKSE_FLAVOR=se   Downgraded Steam executable 1.5.97; SKSE 2.0.20
  SKSE_FLAVOR=gog  GOG executable 1.6.1179
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
    fix-skse-launcher|force-vortex-skse|skse-launcher|repair-skse-launcher|vortex-skse)
      fix_skse_launcher
      ;;
    diagnose|status)
      diagnose
      ;;
    deployment|deploy-check|audio-check)
      deployment_status
      ;;
    fix-staging|staging-fix|prepare-staging|paths)
      fix_staging
      ;;
    empty-staging|fresh-staging|new-staging|create-empty-staging)
      empty_staging
      ;;
    hardlink-test|deploy-test)
      shift
      hardlink_test "${1:-}"
      ;;
    audio-fix|fix-audio|fix-voices)
      audio_fix
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
