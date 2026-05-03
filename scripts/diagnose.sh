#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

APP_ID="proton-vortex"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
APP_HOME="$DATA_HOME/$APP_ID"
CONFIG_FILE="$APP_HOME/config.env"
LAUNCHER="$BIN_HOME/proton-vortex"
SKYRIM_HELPER="$BIN_HOME/proton-vortex-skyrim-se"
INTAKE_HELPER="$APP_HOME/mod-intake.py"
NXM_DESKTOP="$DATA_HOME/applications/proton-vortex-nxm.desktop"
VORTEX_DESKTOP="$DATA_HOME/applications/proton-vortex.desktop"
SKYRIM_DESKTOP="$DATA_HOME/applications/proton-vortex-skyrim-se.desktop"
IMPORT_DESKTOP="$DATA_HOME/applications/proton-vortex-import.desktop"
VORTEX_ICON="$DATA_HOME/icons/hicolor/scalable/apps/proton-vortex.svg"
SKYRIM_ICON="$DATA_HOME/icons/hicolor/scalable/apps/proton-vortex-skyrim-se.svg"

ok() {
  printf '[ok] %s\n' "$*"
}

warn() {
  printf '[warn] %s\n' "$*"
}

fail() {
  printf '[fail] %s\n' "$*"
}

check_file() {
  local path="$1"
  local label="$2"
  if [[ -e "$path" ]]; then
    ok "$label: $path"
  else
    fail "$label missing: $path"
  fi
}

check_command() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "command found: $cmd"
  else
    fail "command missing: $cmd"
  fi
}

check_command bash
check_command curl
check_command python3
check_command xdg-mime

check_file "$CONFIG_FILE" "config"
check_file "$LAUNCHER" "launcher"
check_file "$SKYRIM_HELPER" "Skyrim SE helper"
check_file "$INTAKE_HELPER" "mod intake helper"
check_file "$VORTEX_DESKTOP" "Vortex desktop file"
check_file "$NXM_DESKTOP" "NXM desktop file"
check_file "$SKYRIM_DESKTOP" "Skyrim SE desktop file"
check_file "$IMPORT_DESKTOP" "archive import desktop file"
check_file "$VORTEX_ICON" "Vortex app icon"
check_file "$SKYRIM_ICON" "Skyrim SE app icon"

if [[ -r "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  . "$CONFIG_FILE"
  if [[ -n "${COMPAT_DATA:-}" ]]; then
    if [[ -d "$COMPAT_DATA/pfx/drive_c" ]]; then
      ok "Proton prefix exists: $COMPAT_DATA/pfx"
    else
      fail "Proton prefix missing: $COMPAT_DATA/pfx"
      warn "Fix: rerun bash install.sh. If this is Skyrim's prefix, launching Skyrim once from Steam also creates it."
    fi
  fi
  if [[ -n "${SKYRIM_SE_GAME_DIR:-}" && -f "$SKYRIM_SE_GAME_DIR/SkyrimSE.exe" ]]; then
    ok "Skyrim SE detected: $SKYRIM_SE_GAME_DIR"
  else
    warn "Skyrim SE was not recorded in config. Rerun bash install.sh after installing Skyrim SE in Steam."
  fi
  if [[ -n "${VORTEX_GAME_ID:-}" ]]; then
    ok "Vortex game id: $VORTEX_GAME_ID"
  else
    warn "Vortex game id is not forced. Expected skyrimse when Skyrim SE is detected."
  fi
  if [[ -n "${PROTON_VORTEX_DPI:-}" ]]; then
    ok "Vortex/Wine dialog DPI setting: $PROTON_VORTEX_DPI"
  fi
  if [[ -n "${PROTON_VORTEX_SCALE:-}" ]]; then
    ok "Vortex Electron scale factor: $PROTON_VORTEX_SCALE"
  fi
  if [[ -n "${PROTON_VORTEX_DISABLE_GPU:-}" ]]; then
    ok "Vortex GPU-safe rendering: $PROTON_VORTEX_DISABLE_GPU"
  fi
  if [[ -n "${PROTON_VORTEX_PERFORMANCE:-}" ]]; then
    ok "Vortex performance mode: $PROTON_VORTEX_PERFORMANCE"
  fi
  if [[ -n "${PROTON_VORTEX_DRIVE_LETTER:-}" ]]; then
    ok "Vortex simple drive letter: ${PROTON_VORTEX_DRIVE_LETTER^^}:"
  fi
  if [[ -r "$VORTEX_DESKTOP" ]]; then
    if grep -q '^StartupWMClass=vortex\.exe$' "$VORTEX_DESKTOP"; then
      ok "Vortex dock window class: vortex.exe"
    else
      warn "Vortex dock window class is not the current value. Rerun: bash install.sh"
    fi
    if grep -q '^Actions=LaunchSKSE;FixStaging;$' "$VORTEX_DESKTOP"; then
      ok "Vortex dock actions: Launch SKSE and Fix Staging"
    else
      warn "Vortex dock actions missing. Rerun: bash install.sh"
    fi
  fi
  if [[ -n "${VORTEX_SKYRIMSE_STAGING_DIR:-}" ]]; then
    if [[ -d "$VORTEX_SKYRIMSE_STAGING_DIR" ]]; then
      ok "Prepared Skyrim staging folder: $VORTEX_SKYRIMSE_STAGING_DIR"
    else
      warn "Prepared Skyrim staging folder missing: $VORTEX_SKYRIMSE_STAGING_DIR"
    fi
  fi
  if [[ -n "${VORTEX_DOWNLOADS_DIR:-}" ]]; then
    if [[ -d "$VORTEX_DOWNLOADS_DIR" ]]; then
      ok "Prepared Vortex downloads folder: $VORTEX_DOWNLOADS_DIR"
    else
      warn "Prepared Vortex downloads folder missing: $VORTEX_DOWNLOADS_DIR"
    fi
  fi
  if [[ -n "${COMPAT_DATA:-}" && -d "$COMPAT_DATA/pfx/drive_c/users/steamuser/Desktop" ]]; then
    picker_help="$COMPAT_DATA/pfx/drive_c/users/steamuser/Desktop/PROTON_VORTEX_PATHS.txt"
    skse_bat="$COMPAT_DATA/pfx/drive_c/users/steamuser/Desktop/Launch Skyrim SE SKSE.bat"
    if [[ -f "$picker_help" ]]; then
      ok "Proton file picker helper: $picker_help"
    else
      warn "Proton file picker helper missing. Run: proton-vortex-skyrim-se fix-staging"
    fi
    if [[ -f "$skse_bat" ]]; then
      ok "Vortex SKSE batch helper: $skse_bat"
    else
      warn "Vortex SKSE batch helper missing. Run: proton-vortex-skyrim-se fix-staging"
    fi
  fi
  if [[ -n "${SKYRIM_SE_COMPAT_DATA:-}" && -n "${COMPAT_DATA:-}" && "$COMPAT_DATA" == "$SKYRIM_SE_COMPAT_DATA" ]]; then
    ok "Vortex and Skyrim SE share Proton prefix"
  else
    warn "Vortex and Skyrim SE prefix sharing was not confirmed. Run: proton-vortex linked"
  fi
fi

if [[ -x "$LAUNCHER" ]]; then
  "$LAUNCHER" --print-info || true
fi

if [[ -x "$SKYRIM_HELPER" ]]; then
  "$SKYRIM_HELPER" diagnose || true
fi

if command -v xdg-mime >/dev/null 2>&1; then
  handler="$(xdg-mime query default x-scheme-handler/nxm || true)"
  if [[ "$handler" == "proton-vortex-nxm.desktop" ]]; then
    ok "nxm:// is registered to proton-vortex-nxm.desktop"
  else
    warn "nxm:// handler is '$handler'. Re-register with: xdg-mime default proton-vortex-nxm.desktop x-scheme-handler/nxm"
  fi
fi

if [[ -x "$LAUNCHER" ]]; then
  "$LAUNCHER" api-key status || true
fi

printf '\nBrowser test:\n'
printf "  Click a Nexus Mods 'Mod Manager Download' button, then choose Vortex NXM Handler when prompted.\n"
printf "  Click a Nexus Mods collection 'Add Collection' button the same way.\n"
printf "  From a terminal, quote the URL: proton-vortex 'nxm://...'\n"
printf "  For non-Nexus archives: proton-vortex import /path/to/mod.zip\n"
printf "\nRepair/preflight:\n"
printf "  proton-vortex doctor --fix\n"
printf "  proton-vortex linked\n"
printf "  proton-vortex preflight\n"
printf "  If Vortex says no uninstall key: proton-vortex repair-vortex\n"
printf "  If Vortex is tiny: PROTON_VORTEX_SCALE=1.5 proton-vortex\n"
printf "  If Vortex is invisible/choppy/blank: PROTON_VORTEX_DISABLE_GPU=1 bash install.sh\n"
printf "\nSKSE and deployment:\n"
printf "  proton-vortex-skyrim-se install-skse\n"
printf "  proton-vortex-skyrim-se preflight-launch\n"
printf "  proton-vortex-skyrim-se fix-skse-launcher\n"
printf "  proton-vortex-skyrim-se deployment\n"
printf "  proton-vortex-skyrim-se fix-staging\n"
printf "  proton-vortex-skyrim-se empty-staging\n"
printf "  proton-vortex-skyrim-se hardlink-test\n"
printf "  proton-vortex-skyrim-se audio-check\n"
printf "  In Skyrim console, run: getskseversion\n"
printf "  In Vortex: Mods enabled, Plugins enabled, then Deploy Mods\n"
printf "  If only voices are silent: proton-vortex-skyrim-se audio-fix\n"
printf "  If Vortex is choppy while downloading: PROTON_VORTEX_PERFORMANCE=1 proton-vortex\n"
printf "  proton-vortex last-log\n"
