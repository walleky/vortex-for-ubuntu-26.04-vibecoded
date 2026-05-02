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

Avoid choosing bare Z:\\. Z: is the whole Linux filesystem and many places are not writable.
EOF_PICKER
}

write_skse_launcher_bat() {
  local file="$1"
  local game_win="$2"

  cat >"$file" <<EOF_BAT
@echo off
cd /d "$game_win"
start "" "skse64_loader.exe"
EOF_BAT
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
    write_skse_launcher_bat "$desktop/Launch Skyrim SE SKSE.bat" "$game_win"
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
  say "  SKSE helper:     C:\\users\\steamuser\\Desktop\\Launch Skyrim SE SKSE.bat"
  say ""
  say "Use these inside Vortex if it asks for folders:"
  say "  Game folder:        $game_win"
  say "  Mod Staging Folder: $staging_win"
  say "  Downloads Folder:   $downloads_win"
  say ""
  say "Do not create folders at bare Z:\\. In Proton, Z: is your whole Linux filesystem and many parts are not writable."
  say "If Vortex already has a wrong Skyrim entry, manage the entry whose game folder matches the Game folder above."
  say ""
  hardlink_test "$staging_dir"
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
  WINEDEBUG="$PROTON_VORTEX_WINEDEBUG" \
  "$PROTON_DIR/proton" waitforexitandrun "$game_dir/skse64_loader.exe"
}

diagnose() {
  local game_dir
  local compat_data
  local picker_help
  local skse_bat

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
    if [[ -f "$picker_help" ]]; then
      say "  picker help: $picker_help"
    else
      say "  picker help: missing; run proton-vortex-skyrim-se fix-staging"
    fi
    if [[ -f "$skse_bat" ]]; then
      say "  Vortex SKSE helper: $skse_bat"
    else
      say "  Vortex SKSE helper: missing; run proton-vortex-skyrim-se fix-staging"
    fi
    say ""
    say "To verify SKSE in-game:"
    say "  1. Launch: proton-vortex-skyrim-se launch-skse"
    say "  2. Open the Skyrim console with ~"
    say "  3. Run: getskseversion"
    say ""
    say "To check deployment/audio:"
    say "  proton-vortex-skyrim-se deployment"
    say "  proton-vortex-skyrim-se fix-staging"
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
  proton-vortex-skyrim-se diagnose
  proton-vortex-skyrim-se deployment
  proton-vortex-skyrim-se fix-staging
  proton-vortex-skyrim-se hardlink-test [staging-folder]
  proton-vortex-skyrim-se audio-check
  proton-vortex-skyrim-se audio-fix

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
    deployment|deploy-check|audio-check)
      deployment_status
      ;;
    fix-staging|staging-fix|prepare-staging|paths)
      fix_staging
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
