#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

APP_ID="proton-vortex"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_HOME="$DATA_HOME/$APP_ID"
CONFIG_FILE="$APP_HOME/config.env"
INTAKE_HELPER="$APP_HOME/mod-intake.py"

say() {
  printf '%s\n' "$*"
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

load_config() {
  if [[ ! -r "$CONFIG_FILE" ]]; then
    die "Config not found at $CONFIG_FILE. Run install.sh first."
  fi

  # shellcheck source=/dev/null
  . "$CONFIG_FILE"

  if [[ -z "${STEAM_ROOT:-}" || -z "${PROTON_DIR:-}" || -z "${COMPAT_DATA:-}" ]]; then
    die "Config is incomplete. Rerun install.sh."
  fi
  PROTON_APP_ID="${PROTON_APP_ID:-0}"

  if [[ ! -x "$PROTON_DIR/proton" ]]; then
    die "Proton executable not found at $PROTON_DIR/proton. Rerun install.sh or update $CONFIG_FILE."
  fi
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

  STEAM_COMPAT_DATA_PATH="$COMPAT_DATA" \
  STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT" \
  STEAM_COMPAT_APP_ID="$PROTON_APP_ID" \
  SteamAppId="$PROTON_APP_ID" \
  "$PROTON_DIR/proton" waitforexitandrun "$vortex_exe" "$@"
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
  say "  config:        $CONFIG_FILE"
  say "  steam root:    $STEAM_ROOT"
  say "  proton:        $PROTON_DIR"
  say "  compat data:   $COMPAT_DATA"
  if [[ -d "$COMPAT_DATA/pfx/drive_c" ]]; then
    say "  prefix:        ready"
  else
    say "  prefix:        missing ($COMPAT_DATA/pfx)"
  fi
  say "  proton app id: ${PROTON_APP_ID:-0}"
  say "  vortex exe:    ${vortex_exe:-not found}"
  say "  intake helper: $INTAKE_HELPER"

  if command -v xdg-mime >/dev/null 2>&1; then
    say "  nxm handler:   $(xdg-mime query default x-scheme-handler/nxm || true)"
  fi
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
  proton-vortex api-key set
  proton-vortex api validate
  proton-vortex --download 'nxm://...'
  proton-vortex --install 'nxm://...'
  proton-vortex --print-info

Normal Nexus NXM files are sent to Vortex's native downloader by default so
Vortex keeps Nexus metadata. Set PROTON_VORTEX_API_NXM=1 to force Linux-side
API download for normal mod files. Collections still go straight to Vortex's
collection workflow.
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
  esac

  local vortex_exe
  require_prefix
  vortex_exe="$(find_vortex_exe || true)"
  if [[ -z "$vortex_exe" ]]; then
    die "Vortex.exe was not found in $COMPAT_DATA. Rerun install.sh."
  fi

  if [[ "${1:-}" == "import" ]]; then
    shift
    [[ -n "${1:-}" ]] || die "Usage: proton-vortex import /path/to/mod.zip"
    run_intake "$vortex_exe" "$1"
    return 0
  fi

  if [[ "${1:-}" == nxm:* || "${1:-}" == http://* || "${1:-}" == https://* || "${1:-}" == file://* || -e "${1:-}" ]]; then
    run_intake "$vortex_exe" "$1"
    return 0
  fi

  run_vortex "$vortex_exe" "$@"
}

main "$@"
