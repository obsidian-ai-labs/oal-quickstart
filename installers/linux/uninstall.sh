#!/usr/bin/env bash
# OAL Quickstart - Linux uninstaller. Removes the agent, keeps a backup.
set -euo pipefail

note() { printf "\n>>> %s\n" "$*"; }

read -rp "This will remove OpenClaw and the agent workspace. Ollama (and your downloaded models) stay unless you say so. Continue? [y/N] " ans
[[ "$ans" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

note "Backing up workspace to ~/.openclaw.bak.$(date +%Y%m%d-%H%M%S)"
if [[ -d "$HOME/.openclaw" ]]; then
  mv "$HOME/.openclaw" "$HOME/.openclaw.bak.$(date +%Y%m%d-%H%M%S)"
fi

note "Removing OpenClaw binary"
if command -v bun >/dev/null 2>&1; then
  bun pm uninstall -g @openclaw/openclaw || true
fi

read -rp "Also remove Ollama and your local models (frees ~5-15 GB)? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  note "Removing Ollama"
  sudo rm -f /usr/local/bin/ollama 2>/dev/null || rm -f "$HOME/.local/bin/ollama" 2>/dev/null || true
  rm -rf "$HOME/.ollama"
fi

echo
echo "Uninstall complete. Workspace backup is at ~/.openclaw.bak.*."
echo "Remove that backup yourself when you're sure you don't want it."
