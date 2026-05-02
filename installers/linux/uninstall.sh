#!/usr/bin/env bash
# OAL Quickstart - Linux uninstaller. Removes the whole stack cleanly.
set -euo pipefail

note() { printf "\n>>> %s\n" "$*"; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$SCRIPT_DIR"

read -rp "Stop and remove containers + workspace? [y/N] " ans
[[ "$ans" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

note "Backing up your workspace to ~/.oal-quickstart-bak.$(date +%Y%m%d-%H%M%S)/"
BAK="$HOME/.oal-quickstart-bak.$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BAK"
[[ -d "$SCRIPT_DIR/openclaw-state/workspace" ]] && cp -r "$SCRIPT_DIR/openclaw-state/workspace" "$BAK/"
[[ -f "$SCRIPT_DIR/openclaw-state/openclaw.json" ]] && cp "$SCRIPT_DIR/openclaw-state/openclaw.json" "$BAK/"
echo "    backup: $BAK"

note "docker compose down"
docker compose down 2>&1 | sed 's/^/    /' || sg docker -c "docker compose down"

read -rp "Also remove the 5 GB model volume (oal-ollama-models)? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  docker volume rm oal-ollama-models 2>/dev/null || sg docker -c "docker volume rm oal-ollama-models" || true
  note "Volume removed"
fi

read -rp "Remove the openclaw-state/ directory inside the repo? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  rm -rf "$SCRIPT_DIR/openclaw-state"
  note "openclaw-state/ removed (backup is at $BAK)"
fi

echo
echo "Uninstall complete. Backup at $BAK if you change your mind."
echo "Docker itself is left alone — remove with your package manager if you want."
