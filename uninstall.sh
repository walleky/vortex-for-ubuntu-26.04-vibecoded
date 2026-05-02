#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

APP_ID="proton-vortex"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
APP_HOME="$DATA_HOME/$APP_ID"
APP_CACHE="$CACHE_HOME/$APP_ID"
APP_DESKTOP_DIR="$DATA_HOME/applications"
LAUNCHER="$BIN_HOME/proton-vortex"
SKYRIM_HELPER="$BIN_HOME/proton-vortex-skyrim-se"

printf 'Removing Proton Vortex launchers...\n'
rm -f "$LAUNCHER"
rm -f "$SKYRIM_HELPER"
rm -f "$APP_DESKTOP_DIR/proton-vortex.desktop"
rm -f "$APP_DESKTOP_DIR/proton-vortex-nxm.desktop"
rm -f "$APP_DESKTOP_DIR/proton-vortex-skyrim-se.desktop"
rm -f "$APP_DESKTOP_DIR/proton-vortex-import.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APP_DESKTOP_DIR" >/dev/null 2>&1 || true
fi

printf 'Keep installed Vortex prefix and cache at:\n'
printf '  %s\n' "$APP_HOME"
printf '  %s\n' "$APP_CACHE"
printf 'Remove them too? [y/N] '
read -r answer

case "$answer" in
  y|Y|yes|YES)
    rm -rf -- "$APP_HOME" "$APP_CACHE"
    printf 'Removed Proton Vortex data.\n'
    ;;
  *)
    printf 'Kept Proton Vortex data.\n'
    ;;
esac
