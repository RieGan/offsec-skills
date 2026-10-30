#!/usr/bin/env bash
# setup-foundry.sh — idempotent Foundry (forge/cast/anvil/chisel) installer.
# Installs foundryup into ~/.foundry if missing, runs it, prints versions.
# Usage: setup-foundry.sh [--help]
set -euo pipefail

usage() {
  echo "usage: setup-foundry.sh [--help]"
  echo "  installs foundryup (~/.foundry/bin) if absent, runs foundryup, prints tool versions"
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) usage >&2; exit 2 ;;
esac

FOUNDRY_BIN="$HOME/.foundry/bin"

if ! command -v foundryup >/dev/null 2>&1; then
  if [[ ! -x "$FOUNDRY_BIN/foundryup" ]]; then
    echo "[*] installing foundryup into $FOUNDRY_BIN"
    curl -L https://foundry.paradigm.xyz | bash
  fi
  export PATH="$FOUNDRY_BIN:$PATH"
fi

if ! command -v foundryup >/dev/null 2>&1; then
  echo "[!] foundryup still not on PATH; add $FOUNDRY_BIN to PATH and rerun" >&2
  exit 1
fi

if ! command -v cast >/dev/null 2>&1; then
  echo "[*] running foundryup to install forge/cast/anvil/chisel"
  foundryup
fi

echo "[*] versions:"
forge --version
cast --version
anvil --version
chisel --version
