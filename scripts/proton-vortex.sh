#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

APP_ID="proton-vortex"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
APP_HOME="$DATA_HOME/$APP_ID"
CONFIG_FILE="$APP_HOME/config.env"
INTAKE_HELPER="$APP_HOME/mod-intake.py"
LOG_DIR="$APP_HOME/logs"
NXM_DESKTOP="$DATA_HOME/applications/proton-vortex-nxm.desktop"
APP_DESKTOP_DIR="$DATA_HOME/applications"

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

ok() {
  printf '[ok] %s\n' "$*"
}

warn() {
  printf '[warn] %s\n' "$*"
}

fail() {
  printf '[fail] %s\n' "$*"
}

desktop_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

current_launcher_path() {
  local launcher
  launcher="$(command -v proton-vortex 2>/dev/null || true)"
  if [[ -n "$launcher" ]]; then
    printf '%s\n' "$launcher"
  elif [[ "$0" == */* ]]; then
    readlink -f "$0" 2>/dev/null || printf '%s\n' "$0"
  else
    printf '%s/proton-vortex\n' "$BIN_HOME"
  fi
}

skyrim_helper_path() {
  local helper
  helper="$(command -v proton-vortex-skyrim-se 2>/dev/null || true)"
  if [[ -n "$helper" ]]; then
    printf '%s\n' "$helper"
  else
    printf '%s/proton-vortex-skyrim-se\n' "$BIN_HOME"
  fi
}

write_desktop_files() {
  local launcher
  local helper
  local launcher_exec

  launcher="$(current_launcher_path)"
  helper="$(skyrim_helper_path)"
  launcher_exec="$(desktop_quote "$launcher")"
  mkdir -p "$APP_DESKTOP_DIR"

  cat >"$APP_DESKTOP_DIR/proton-vortex.desktop" <<EOF_DESKTOP
[Desktop Entry]
Type=Application
Name=Vortex (Proton)
Comment=Run Nexus Mods Vortex through Steam Proton
Categories=Game;Utility;
Keywords=Vortex;Nexus;Mods;Skyrim;SKSE;
Exec=$launcher_exec
Terminal=false
Icon=proton-vortex
NoDisplay=false
StartupWMClass=vortex.exe
StartupNotify=true
Actions=PreflightLaunchSKSE;LaunchSKSE;FixStaging;

[Desktop Action PreflightLaunchSKSE]
Name=Preflight then Launch Skyrim SE SKSE
Exec=$(desktop_quote "$helper") preflight-launch

[Desktop Action LaunchSKSE]
Name=Launch Skyrim SE SKSE
Exec=$(desktop_quote "$helper") launch-skse

[Desktop Action FixStaging]
Name=Fix Skyrim SE Staging
Exec=$(desktop_quote "$helper") fix-staging
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
Keywords=Skyrim;SKSE;Vortex;Mods;
Exec=$(desktop_quote "$helper") preflight-launch
Terminal=false
Icon=proton-vortex-skyrim-se
NoDisplay=false
StartupWMClass=skse64_loader.exe
StartupNotify=true
EOF_DESKTOP

  cat >"$APP_DESKTOP_DIR/proton-vortex-import.desktop" <<EOF_DESKTOP
[Desktop Entry]
Type=Application
Name=Import Mod with Vortex (Proton)
Comment=Import a local mod archive into Vortex through Proton
Categories=Game;Utility;
Keywords=Vortex;Nexus;Mods;Archive;Import;
MimeType=application/zip;application/x-7z-compressed;application/vnd.rar;application/x-rar;application/x-rar-compressed;application/gzip;application/x-tar;
Exec=$launcher_exec import %u
Terminal=false
Icon=proton-vortex-import
NoDisplay=false
StartupNotify=true
EOF_DESKTOP

  chmod 644 \
    "$APP_DESKTOP_DIR/proton-vortex.desktop" \
    "$APP_DESKTOP_DIR/proton-vortex-nxm.desktop" \
    "$APP_DESKTOP_DIR/proton-vortex-skyrim-se.desktop" \
    "$APP_DESKTOP_DIR/proton-vortex-import.desktop"
}

refresh_desktop_integration() {
  if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$APP_DESKTOP_DIR/proton-vortex.desktop" || true
    desktop-file-validate "$APP_DESKTOP_DIR/proton-vortex-nxm.desktop" || true
    desktop-file-validate "$APP_DESKTOP_DIR/proton-vortex-skyrim-se.desktop" || true
    desktop-file-validate "$APP_DESKTOP_DIR/proton-vortex-import.desktop" || true
  fi
  if command -v xdg-mime >/dev/null 2>&1 && [[ -f "$NXM_DESKTOP" ]]; then
    xdg-mime default proton-vortex-nxm.desktop x-scheme-handler/nxm || true
    xdg-mime default proton-vortex-nxm.desktop x-scheme-handler/nxm-protocol || true
  fi
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APP_DESKTOP_DIR" >/dev/null 2>&1 || true
  fi
  if command -v xdg-desktop-menu >/dev/null 2>&1; then
    xdg-desktop-menu forceupdate >/dev/null 2>&1 || true
  fi
  touch "$APP_DESKTOP_DIR" 2>/dev/null || true
}

prune_logs() {
  local keep="${PROTON_VORTEX_LOG_KEEP:-30}"
  local old_log

  [[ "$keep" =~ ^[0-9]+$ ]] || keep=30
  ((keep > 0)) || return 0
  [[ -d "$LOG_DIR" ]] || return 0

  while IFS= read -r old_log; do
    [[ -n "$old_log" ]] || continue
    rm -f -- "$old_log"
  done < <(find "$LOG_DIR" -maxdepth 1 -type f -name 'vortex-*.log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk -v keep="$keep" 'NR > keep {$1=""; sub(/^ /, ""); print}')
}

load_config() {
  local env_disable_gpu="${PROTON_VORTEX_DISABLE_GPU:-}"
  local env_performance="${PROTON_VORTEX_PERFORMANCE:-}"
  local env_scale="${PROTON_VORTEX_SCALE:-}"
  local env_winedebug="${PROTON_VORTEX_WINEDEBUG-}"

  if [[ ! -r "$CONFIG_FILE" ]]; then
    die "Config not found at $CONFIG_FILE. Run install.sh first."
  fi

  # shellcheck source=/dev/null
  . "$CONFIG_FILE"

  if [[ -z "${STEAM_ROOT:-}" || -z "${PROTON_DIR:-}" || -z "${COMPAT_DATA:-}" ]]; then
    die "Config is incomplete. Rerun install.sh."
  fi
  PROTON_APP_ID="${PROTON_APP_ID:-0}"
  VORTEX_GAME_ID="${VORTEX_GAME_ID:-}"
  PROTON_VORTEX_DISABLE_GPU="${env_disable_gpu:-${PROTON_VORTEX_DISABLE_GPU:-1}}"
  PROTON_VORTEX_PERFORMANCE="${env_performance:-${PROTON_VORTEX_PERFORMANCE:-0}}"
  PROTON_VORTEX_SCALE="${env_scale:-${PROTON_VORTEX_SCALE:-1.5}}"
  PROTON_VORTEX_WINEDEBUG="${env_winedebug:-${PROTON_VORTEX_WINEDEBUG:--all}}"
  PROTON_VORTEX_DRIVE_LETTER="${PROTON_VORTEX_DRIVE_LETTER:-s}"
  VORTEX_SKYRIMSE_STAGING_DIR="${VORTEX_SKYRIMSE_STAGING_DIR:-}"
  VORTEX_DOWNLOADS_DIR="${VORTEX_DOWNLOADS_DIR:-}"
  VORTEX_SKYRIMSE_GAME_WIN_PATH="${VORTEX_SKYRIMSE_GAME_WIN_PATH:-}"
  VORTEX_SKYRIMSE_STAGING_WIN_PATH="${VORTEX_SKYRIMSE_STAGING_WIN_PATH:-}"
  VORTEX_DOWNLOADS_WIN_PATH="${VORTEX_DOWNLOADS_WIN_PATH:-}"
  INSTALL_SOURCE_DIR="${INSTALL_SOURCE_DIR:-}"

  if [[ ! -x "$PROTON_DIR/proton" ]]; then
    die "Proton executable not found at $PROTON_DIR/proton. Rerun install.sh or update $CONFIG_FILE."
  fi
}

linux_path_to_windows_hint() {
  local path="$1"
  printf 'Z:%s\n' "$path" | sed 's#/#\\#g'
}

require_prefix() {
  if [[ ! -d "$COMPAT_DATA/pfx/drive_c" ]]; then
    die "No Proton prefix found at $COMPAT_DATA/pfx. Rerun install.sh so it can create the prefix, or run Skyrim once in Steam if you want to use Skyrim's own prefix."
  fi
}

find_vortex_exe() {
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

run_vortex() {
  local vortex_exe="$1"
  shift
  local electron_flags=()
  local log_file
  local status

  if [[ "$PROTON_VORTEX_DISABLE_GPU" == "1" ]]; then
    electron_flags+=(--disable-gpu --disable-gpu-compositing --disable-direct-composition --disable-accelerated-2d-canvas)
  fi
  if [[ "$PROTON_VORTEX_PERFORMANCE" == "1" ]]; then
    electron_flags+=(--disable-background-timer-throttling --disable-renderer-backgrounding --disable-features=CalculateNativeWinOcclusion)
  fi
  if [[ -n "${PROTON_VORTEX_SCALE:-}" && "$PROTON_VORTEX_SCALE" != "0" ]]; then
    if [[ "$PROTON_VORTEX_SCALE" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      electron_flags+=(--high-dpi-support=1 --force-device-scale-factor="$PROTON_VORTEX_SCALE")
    else
      say_err "Warning: PROTON_VORTEX_SCALE must be a number or 0; got '$PROTON_VORTEX_SCALE'."
    fi
  fi

  mkdir -p "$LOG_DIR"
  prune_logs
  log_file="$(mktemp "$LOG_DIR/vortex-$(date +%Y%m%d-%H%M%S).XXXXXX.log")" || die "Could not create a Vortex log file in $LOG_DIR"
  say_err "Vortex log: $log_file"

  set +e
  STEAM_COMPAT_DATA_PATH="$COMPAT_DATA" \
  STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT" \
  STEAM_COMPAT_APP_ID="$PROTON_APP_ID" \
  SteamAppId="$PROTON_APP_ID" \
  WINEDEBUG="$PROTON_VORTEX_WINEDEBUG" \
  "$PROTON_DIR/proton" waitforexitandrun "$vortex_exe" "${electron_flags[@]}" "$@" >>"$log_file" 2>&1
  status=$?
  set -e

  if ((status != 0)); then
    say_err "Vortex exited with code $status. See log: $log_file"
  fi
  prune_logs
  return "$status"
}

run_intake() {
  local vortex_exe="$1"
  local value="$2"
  local resolved=()
  local resolved_file
  local mode
  local payload

  if [[ ! -r "$INTAKE_HELPER" ]]; then
    die "Mod intake helper not found at $INTAKE_HELPER. Rerun install.sh."
  fi

  resolved_file="$(mktemp "${TMPDIR:-/tmp}/proton-vortex-intake.XXXXXX")" || die "Could not create a temporary intake file."
  if ! python3 "$INTAKE_HELPER" resolve "$value" >"$resolved_file"; then
    rm -f "$resolved_file"
    die "Mod intake failed for: $value"
  fi
  mapfile -t resolved <"$resolved_file"
  rm -f "$resolved_file"

  mode="${resolved[0]:-}"
  payload="${resolved[1]:-$value}"
  [[ -n "$mode" ]] || die "Mod intake returned no action for: $value"

  case "$mode" in
    install|install-url)
      run_vortex "$vortex_exe" --install "$payload"
      ;;
    download)
      run_vortex "$vortex_exe" --download "$payload"
      ;;
    raw)
      run_vortex "$vortex_exe" "$payload"
      ;;
    *)
      die "Unknown intake result: $mode"
      ;;
  esac
}

print_info() {
  local vortex_exe
  vortex_exe="$(find_vortex_exe || true)"

  say "Proton Vortex"
  say "  app home:      $APP_HOME"
  say "  install src:   ${INSTALL_SOURCE_DIR:-unknown}"
  say "  config:        $CONFIG_FILE"
  say "  steam root:    $STEAM_ROOT"
  say "  proton:        $PROTON_DIR"
  say "  compat data:   $COMPAT_DATA"
  say "  skyrim dir:    ${SKYRIM_SE_GAME_DIR:-not detected}"
  say "  vortex game:   ${VORTEX_GAME_ID:-not forced}"
  if [[ -d "$COMPAT_DATA/pfx/drive_c" ]]; then
    say "  prefix:        ready"
  else
    say "  prefix:        missing ($COMPAT_DATA/pfx)"
  fi
  say "  proton app id: ${PROTON_APP_ID:-0}"
  say "  disable gpu:   $PROTON_VORTEX_DISABLE_GPU"
  say "  performance:   $PROTON_VORTEX_PERFORMANCE"
  say "  ui scale:      ${PROTON_VORTEX_SCALE:-1.5}"
  say "  winedebug:     $PROTON_VORTEX_WINEDEBUG"
  say "  drive hint:    ${PROTON_VORTEX_DRIVE_LETTER^^}:"
  say "  skyrim game:   ${VORTEX_SKYRIMSE_GAME_WIN_PATH:-not prepared}"
  say "  staging hint:  ${VORTEX_SKYRIMSE_STAGING_WIN_PATH:-not prepared}"
  say "  downloads:     ${VORTEX_DOWNLOADS_WIN_PATH:-not prepared}"
  say "  vortex exe:    ${vortex_exe:-not found}"
  say "  intake helper: $INTAKE_HELPER"
  say "  logs:          $LOG_DIR"

  if command -v xdg-mime >/dev/null 2>&1; then
    say "  nxm handler:   $(xdg-mime query default x-scheme-handler/nxm || true)"
  fi
}

vortex_roaming_dir() {
  local pfx="$COMPAT_DATA/pfx"
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

ensure_support_dirs() {
  local include_vortex="${1:-0}"
  local roaming

  mkdir -p "$LOG_DIR" "$APP_HOME/downloads/external" "$APP_HOME/downloads/nexus"

  if [[ "$include_vortex" == "1" && -d "$COMPAT_DATA/pfx/drive_c" ]]; then
    roaming="$(vortex_roaming_dir)"
    mkdir -p "$roaming/downloads"
    if [[ -n "$VORTEX_GAME_ID" ]]; then
      mkdir -p "$roaming/$VORTEX_GAME_ID/mods"
    fi
  fi
}

same_device() {
  local left="$1"
  local right="$2"
  [[ -e "$left" && -e "$right" ]] || return 1
  [[ "$(stat -c %d "$left" 2>/dev/null)" == "$(stat -c %d "$right" 2>/dev/null)" ]]
}

doctor() {
  local fix="${1:-}"
  local status=0
  local vortex_exe=""
  local handler=""
  local roaming=""
  local staging=""
  local staged_count=""
  local free_space=""
  local picker_help=""
  local skse_bat=""
  local linked=0

  if [[ "$fix" == "--fix" ]]; then
    ensure_support_dirs 1
    write_desktop_files
    refresh_desktop_integration
  fi

  say "Proton Vortex doctor"

  [[ -r "$CONFIG_FILE" ]] && ok "config: $CONFIG_FILE" || { fail "config missing: $CONFIG_FILE"; status=1; }
  [[ -x "$PROTON_DIR/proton" ]] && ok "proton: $PROTON_DIR" || { fail "proton missing: $PROTON_DIR/proton"; status=1; }
  [[ -d "$COMPAT_DATA/pfx/drive_c" ]] && ok "prefix: $COMPAT_DATA/pfx" || { fail "prefix missing: $COMPAT_DATA/pfx"; status=1; }

  vortex_exe="$(find_vortex_exe || true)"
  [[ -n "$vortex_exe" ]] && ok "Vortex.exe: $vortex_exe" || { fail "Vortex.exe not found; rerun bash install.sh"; status=1; }

  if [[ -n "${SKYRIM_SE_GAME_DIR:-}" && -f "$SKYRIM_SE_GAME_DIR/SkyrimSE.exe" ]]; then
    ok "Skyrim SE: $SKYRIM_SE_GAME_DIR"
    ok "Skyrim Vortex path hint: $(linux_path_to_windows_hint "$SKYRIM_SE_GAME_DIR")"
    if [[ -n "${VORTEX_SKYRIMSE_GAME_WIN_PATH:-}" ]]; then
      ok "Skyrim simple drive path: $VORTEX_SKYRIMSE_GAME_WIN_PATH"
    fi
    [[ -d "$SKYRIM_SE_GAME_DIR/Data" ]] && ok "Skyrim Data folder: $SKYRIM_SE_GAME_DIR/Data" || { warn "Skyrim Data folder missing. Run Skyrim once from Steam, then rerun install.sh."; status=1; }
    if [[ -f "$SKYRIM_SE_GAME_DIR/skse64_loader.exe" ]]; then
      ok "SKSE loader: $SKYRIM_SE_GAME_DIR/skse64_loader.exe"
    else
      warn "SKSE loader missing. Run: proton-vortex-skyrim-se install-skse"
      status=1
    fi
  else
    warn "Skyrim SE not detected in config. Install/run Skyrim in Steam, then rerun bash install.sh."
    status=1
  fi

  if [[ -n "${SKYRIM_SE_COMPAT_DATA:-}" && "$COMPAT_DATA" == "$SKYRIM_SE_COMPAT_DATA" ]]; then
    ok "link: Vortex and Skyrim SE share the same Proton prefix"
    linked=1
  elif [[ -n "${SKYRIM_SE_COMPAT_DATA:-}" ]]; then
    warn "link: Vortex prefix differs from Skyrim SE prefix. Vortex may not see the same Windows environment."
    warn "      Vortex: $COMPAT_DATA"
    warn "      Skyrim: $SKYRIM_SE_COMPAT_DATA"
    status=1
  else
    warn "link: Skyrim SE compatdata is not recorded."
    status=1
  fi

  [[ "${VORTEX_GAME_ID:-}" == "skyrimse" ]] && ok "Vortex game id: skyrimse" || { warn "Vortex game id is '${VORTEX_GAME_ID:-not set}', expected skyrimse."; status=1; }

  if command -v xdg-mime >/dev/null 2>&1; then
    handler="$(xdg-mime query default x-scheme-handler/nxm || true)"
    [[ "$handler" == "proton-vortex-nxm.desktop" ]] && ok "nxm handler: $handler" || { warn "nxm handler is '${handler:-unset}'. Run: proton-vortex doctor --fix"; status=1; }
  else
    warn "xdg-mime missing; browser NXM links cannot be checked."
    status=1
  fi

  [[ -d "$LOG_DIR" ]] && ok "logs: $LOG_DIR" || warn "logs directory is not created yet; it will be created on next Vortex launch or by doctor --fix"

  if [[ -n "${VORTEX_SKYRIMSE_STAGING_DIR:-}" ]]; then
    [[ -d "$VORTEX_SKYRIMSE_STAGING_DIR" ]] && ok "prepared staging: $VORTEX_SKYRIMSE_STAGING_DIR" || { warn "prepared staging missing: $VORTEX_SKYRIMSE_STAGING_DIR"; status=1; }
    [[ -n "${VORTEX_SKYRIMSE_STAGING_WIN_PATH:-}" ]] && ok "prepared staging in Vortex: $VORTEX_SKYRIMSE_STAGING_WIN_PATH"
  fi
  if [[ -n "${VORTEX_DOWNLOADS_DIR:-}" ]]; then
    [[ -d "$VORTEX_DOWNLOADS_DIR" ]] && ok "prepared downloads: $VORTEX_DOWNLOADS_DIR" || { warn "prepared downloads missing: $VORTEX_DOWNLOADS_DIR"; status=1; }
    [[ -n "${VORTEX_DOWNLOADS_WIN_PATH:-}" ]] && ok "prepared downloads in Vortex: $VORTEX_DOWNLOADS_WIN_PATH"
  fi
  if [[ -d "$COMPAT_DATA/pfx/drive_c/users/steamuser/Desktop" ]]; then
    picker_help="$COMPAT_DATA/pfx/drive_c/users/steamuser/Desktop/PROTON_VORTEX_PATHS.txt"
    skse_bat="$COMPAT_DATA/pfx/drive_c/users/steamuser/Desktop/Launch Skyrim SE SKSE.bat"
    [[ -f "$picker_help" ]] && ok "Proton picker helper: $picker_help" || { warn "Proton picker helper missing; run: proton-vortex-skyrim-se fix-staging"; status=1; }
    [[ -f "$skse_bat" ]] && ok "Vortex SKSE batch helper: $skse_bat" || { warn "Vortex SKSE batch helper missing; run: proton-vortex-skyrim-se fix-staging"; status=1; }
  fi

  if [[ -n "$VORTEX_GAME_ID" && -d "$COMPAT_DATA/pfx/drive_c" ]]; then
    roaming="$(vortex_roaming_dir)"
    staging="$roaming/$VORTEX_GAME_ID/mods"
    [[ -d "$staging" ]] && ok "suggested staging folder: $staging" || warn "suggested staging folder missing: $staging (doctor --fix can create it, or Vortex can create its own staging folder)"
    if [[ -d "$staging" ]]; then
      staged_count="$(find "$staging" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d '[:space:]')"
      if [[ "${staged_count:-0}" != "0" ]]; then
        ok "staged mod folders: $staged_count"
      else
        warn "staged mod folders: 0. Downloads may exist, but Vortex still needs mods installed/enabled/deployed."
      fi
    fi
    if [[ -n "${SKYRIM_SE_GAME_DIR:-}" && -d "$SKYRIM_SE_GAME_DIR" && -d "$staging" ]]; then
      if same_device "$SKYRIM_SE_GAME_DIR" "$staging"; then
        ok "staging and Skyrim are on the same filesystem"
      else
        warn "staging and Skyrim appear to be on different filesystems; Vortex hardlink deployment may fail."
        status=1
      fi
    fi
  fi

  if [[ -n "${SKYRIM_SE_GAME_DIR:-}" && -d "$SKYRIM_SE_GAME_DIR" && -n "${VORTEX_SKYRIMSE_STAGING_DIR:-}" && -d "$VORTEX_SKYRIMSE_STAGING_DIR" ]]; then
    if same_device "$SKYRIM_SE_GAME_DIR" "$VORTEX_SKYRIMSE_STAGING_DIR"; then
      ok "prepared staging and Skyrim are on the same filesystem"
    else
      warn "prepared staging and Skyrim are on different filesystems; run: proton-vortex-skyrim-se fix-staging"
      status=1
    fi
  fi

  if [[ -n "${SKYRIM_SE_GAME_DIR:-}" && -d "$SKYRIM_SE_GAME_DIR" ]]; then
    free_space="$(df -h "$SKYRIM_SE_GAME_DIR" 2>/dev/null | awk 'NR==2 {print $4}')"
    [[ -n "$free_space" ]] && ok "free space near Skyrim: $free_space"
  fi

  say ""
  say "Collection preflight:"
  say "  - Vortex must be logged into Nexus."
  say "  - Vortex should manage Skyrim Special Edition."
  say "  - Use Hardlink Deployment when Vortex asks."
  say "  - In Vortex, downloaded mods still need Installed, Enabled, Plugins enabled, then Deploy Mods."
  say "  - If Vortex shows two Skyrims, manage the one whose path matches the Skyrim Vortex path hint above."
  say "  - If the Windows file picker shows C: and Z:, use the simple drive path above instead of creating folders at bare Z:\\."
  say "  - If Vortex says the staging folder is not writable, run: proton-vortex-skyrim-se fix-staging"
  say "  - If character voices are gone, run: proton-vortex-skyrim-se audio-check"
  say "  - If Deploy Mods fails, run: proton-vortex-skyrim-se hardlink-test"
  say "  - Nexus Free accounts may still require manual collection download clicks."
  if ((linked == 1)); then
    say "  - Best launch path for modded play: proton-vortex-skyrim-se preflight-launch"
  fi

  return "$status"
}

show_last_log() {
  local log_file
  log_file="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'vortex-*.log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1 {$1=\"\"; sub(/^ /, \"\"); print}')"
  [[ -n "$log_file" ]] || die "No Vortex logs found in $LOG_DIR"
  say "$log_file"
  tail -n "${PROTON_VORTEX_LOG_LINES:-80}" "$log_file"
}

choose_import_file() {
  local file

  if command -v zenity >/dev/null 2>&1; then
    file="$(zenity --file-selection \
      --title="Choose a mod archive for Vortex" \
      --file-filter="Mod archives | *.zip *.7z *.rar *.tar *.gz *.tgz" \
      --file-filter="All files | *" 2>/dev/null || true)"
    [[ -n "$file" ]] && printf '%s\n' "$file"
    return 0
  fi

  if command -v kdialog >/dev/null 2>&1; then
    file="$(kdialog --getopenfilename "${HOME:-/}" "*.zip *.7z *.rar *.tar *.gz *.tgz | Mod archives" 2>/dev/null || true)"
    [[ -n "$file" ]] && printf '%s\n' "$file"
    return 0
  fi

  return 1
}

self_update() {
  if [[ -z "$INSTALL_SOURCE_DIR" || ! -d "$INSTALL_SOURCE_DIR/.git" ]]; then
    die "Self-update needs a git clone source directory. Use: git pull && bash install.sh"
  fi
  command -v git >/dev/null 2>&1 || die "git is not installed."
  if [[ -n "$(git -C "$INSTALL_SOURCE_DIR" status --porcelain)" ]]; then
    die "Self-update stopped because $INSTALL_SOURCE_DIR has local changes. Commit/stash them, or run git status there and update manually."
  fi
  git -C "$INSTALL_SOURCE_DIR" pull --ff-only
  bash "$INSTALL_SOURCE_DIR/install.sh"
}

repair_vortex_install() {
  if [[ -z "$INSTALL_SOURCE_DIR" || ! -f "$INSTALL_SOURCE_DIR/install.sh" ]]; then
    die "Vortex repair needs the original install source folder. Use: FORCE_REINSTALL=1 bash install.sh from the project folder."
  fi

  say "Repairing Vortex installation registry/uninstall metadata by reinstalling Vortex over itself."
  say "This keeps Vortex AppData, downloads, staging folders, profiles, and mod lists intact."
  FORCE_REINSTALL=1 SKSE_AUTO_UPDATE="${SKSE_AUTO_UPDATE:-0}" bash "$INSTALL_SOURCE_DIR/install.sh"
}

main() {
  load_config

  case "${1:-}" in
    --print-info|--diagnose)
      print_info
      return 0
      ;;
    --help|-h)
      cat <<'EOF_HELP'
Usage:
  proton-vortex
  proton-vortex 'nxm://...'
  proton-vortex /path/to/mod.7z
  proton-vortex 'https://example.com/mod.zip'
  proton-vortex import /path/to/mod.zip
  proton-vortex doctor
  proton-vortex doctor --fix
  proton-vortex linked
  proton-vortex preflight
  proton-vortex preflight-launch [--force]
  proton-vortex last-log
  proton-vortex self-update
  proton-vortex repair-vortex
  proton-vortex --print-info

Normal Nexus NXM files are sent to Vortex's native download-and-install flow.
Collections go straight to Vortex's collection workflow.
EOF_HELP
      return 0
      ;;
    api-key|nexus-key)
      shift
      python3 "$INTAKE_HELPER" api-key "$@"
      return 0
      ;;
    api|nexus-api)
      shift
      python3 "$INTAKE_HELPER" api "$@"
      return 0
      ;;
    doctor)
      shift
      doctor "${1:-}"
      return $?
      ;;
    preflight)
      doctor
      return $?
      ;;
    preflight-launch|launch-skse|play-skse)
      shift
      "$(skyrim_helper_path)" preflight-launch "$@"
      return $?
      ;;
    linked|link-status)
      doctor
      return $?
      ;;
    last-log|logs)
      show_last_log
      return 0
      ;;
    self-update|update)
      self_update
      return 0
      ;;
    repair-vortex|reinstall-vortex|fix-uninstall-key|uninstall-key)
      repair_vortex_install
      return 0
      ;;
  esac

  local vortex_exe
  local selected=""
  require_prefix
  vortex_exe="$(find_vortex_exe || true)"
  if [[ -z "$vortex_exe" ]]; then
    die "Vortex.exe was not found in $COMPAT_DATA. Rerun install.sh."
  fi

  if [[ "${1:-}" == "import" ]]; then
    shift
    if [[ -z "${1:-}" ]]; then
      selected="$(choose_import_file || true)"
      if [[ -z "$selected" ]]; then
        say_err "No archive selected. Opening Vortex instead."
        if [[ -n "$VORTEX_GAME_ID" ]]; then
          run_vortex "$vortex_exe" --game "$VORTEX_GAME_ID"
        else
          run_vortex "$vortex_exe"
        fi
        return 0
      fi
      set -- "$selected"
    fi
    run_intake "$vortex_exe" "$1"
    return 0
  fi

  if [[ "${1:-}" == nxm:* || "${1:-}" == http://* || "${1:-}" == https://* || "${1:-}" == file://* || -e "${1:-}" ]]; then
    run_intake "$vortex_exe" "$1"
    return 0
  fi

  if [[ $# -eq 0 && -n "$VORTEX_GAME_ID" ]]; then
    run_vortex "$vortex_exe" --game "$VORTEX_GAME_ID"
  else
    run_vortex "$vortex_exe" "$@"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
