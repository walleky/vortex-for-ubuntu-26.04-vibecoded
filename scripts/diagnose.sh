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
SKYRIM_DESKTOP="$DATA_HOME/applications/proton-vortex-skyrim-se.desktop"
IMPORT_DESKTOP="$DATA_HOME/applications/proton-vortex-import.desktop"

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
check_file "$NXM_DESKTOP" "NXM desktop file"
check_file "$SKYRIM_DESKTOP" "Skyrim SE desktop file"
check_file "$IMPORT_DESKTOP" "archive import desktop file"

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
