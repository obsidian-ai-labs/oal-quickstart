#!/usr/bin/env bash
# OAL Quickstart - Linux installer
# Public domain (MIT). See LICENSE in the repo root.
set -euo pipefail

LOG="${HOME}/.oal-quickstart-install.log"
exec > >(tee -a "$LOG") 2>&1
echo
echo "============================================================"
echo " OAL Quickstart installer (Linux)"
echo " Started $(date -u +%FT%TZ)"
echo "============================================================"

# ---- pre-flight ----------------------------------------------------------------

bail() { echo; echo "INSTALL FAILED: $*"; echo "Log: $LOG"; echo "Email it to info@obsidianailabs.ca for help."; exit 1; }
note() { printf "\n>>> %s\n" "$*"; }
ok()   { printf "    ok: %s\n" "$*"; }

note "Checking OS"
if [[ "$(uname -s)" != "Linux" ]]; then bail "This installer is for Linux. Use the macOS or Windows version."; fi
ok "Linux detected: $(uname -srm)"

note "Checking RAM"
RAM_KB=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
RAM_GB=$(( RAM_KB / 1024 / 1024 ))
if (( RAM_GB < 16 )); then
  bail "Need at least 16 GB RAM. You have ${RAM_GB} GB. The agent will be unusably slow."
fi
ok "RAM: ${RAM_GB} GB"

note "Checking free disk"
DISK_GB=$(df -BG --output=avail "$HOME" | tail -1 | tr -dc '0-9')
if (( DISK_GB < 16 )); then
  bail "Need at least 16 GB free in $HOME. You have ${DISK_GB} GB."
fi
ok "Free disk: ${DISK_GB} GB"

note "Checking for GPU"
if command -v nvidia-smi >/dev/null 2>&1; then
  GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || true)
  ok "NVIDIA GPU: ${GPU:-detected}"
else
  echo "    no NVIDIA GPU detected. Inference will run on CPU - tokens per second will be low."
  echo "    You can still proceed, but expect 1-3 second/word latency."
  read -rp "    Continue anyway? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || bail "Cancelled by user."
fi

note "Checking for Docker (optional, used by OpenClaw)"
if command -v docker >/dev/null 2>&1; then
  ok "Docker: $(docker --version)"
else
  echo "    Docker not found. We'll install OpenClaw natively instead."
fi

# ---- install Ollama -----------------------------------------------------------

note "Installing Ollama"
if command -v ollama >/dev/null 2>&1; then
  ok "Ollama already installed: $(ollama --version 2>&1 | head -1)"
else
  curl -fsSL https://ollama.com/install.sh | sh || bail "Ollama install failed"
fi

note "Starting Ollama service"
if systemctl --user is-active --quiet ollama 2>/dev/null; then
  ok "Ollama user service running"
elif sudo systemctl is-active --quiet ollama 2>/dev/null; then
  ok "Ollama system service running"
else
  ollama serve > "$HOME/.ollama-server.log" 2>&1 &
  sleep 3
  ok "Ollama serve started in background"
fi

note "Pulling starter model (llama3.1:8b, ~5 GB - this is the slow part)"
ollama pull llama3.1:8b || bail "Ollama model pull failed"
ok "Model pulled"

# ---- install OpenClaw ----------------------------------------------------------

note "Installing OpenClaw"
if command -v openclaw >/dev/null 2>&1; then
  ok "OpenClaw already installed: $(openclaw --version 2>&1 | head -1)"
else
  if command -v bun >/dev/null 2>&1; then
    bun install -g @openclaw/openclaw || bail "OpenClaw install via bun failed"
  else
    note "Installing bun first (we don't use npm/pnpm)"
    curl -fsSL https://bun.sh/install | bash || bail "Bun install failed"
    export PATH="$HOME/.bun/bin:$PATH"
    bun install -g @openclaw/openclaw || bail "OpenClaw install via bun failed"
  fi
fi

# ---- workspace bootstrap -------------------------------------------------------

note "Setting up agent workspace at ~/.openclaw/"
WORKSPACE="$HOME/.openclaw/workspace"
mkdir -p "$WORKSPACE"
TPL_DIR="$(cd "$(dirname "$0")/../../templates/workspace" && pwd)"
if [[ -d "$TPL_DIR" ]]; then
  for f in IDENTITY.md SOUL.md AGENTS.md USER.md MEMORY.md; do
    if [[ ! -f "$WORKSPACE/$f" && -f "$TPL_DIR/$f" ]]; then
      cp "$TPL_DIR/$f" "$WORKSPACE/$f"
      ok "wrote $f"
    fi
  done
fi

# ---- minimal openclaw.json -----------------------------------------------------

CONFIG="$HOME/.openclaw/openclaw.json"
if [[ ! -f "$CONFIG" ]]; then
  cat > "$CONFIG" <<'JSON'
{
  "models": {
    "providers": {
      "local-ollama": {
        "baseUrl": "http://localhost:11434/v1",
        "apiKey": "dummy-ollama-no-auth",
        "api": "openai-completions",
        "models": [
          {
            "id": "llama3.1:8b",
            "name": "llama3.1:8b (Local)",
            "contextWindow": 32768,
            "maxTokens": 8192,
            "input": ["text"],
            "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
            "reasoning": false
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {"primary": "local-ollama/llama3.1:8b"},
      "skipBootstrap": false,
      "memorySearch": {"enabled": false}
    }
  },
  "tools": {"profile": "minimal"},
  "commands": {"native": "auto", "nativeSkills": "auto", "restart": true},
  "session": {"dmScope": "per-channel-peer"}
}
JSON
  ok "wrote $CONFIG"
fi

# ---- post-install -----------------------------------------------------

note "Smoke-testing the install"
if openclaw agent --agent main -m "Reply with the word OK and nothing else." 2>&1 | grep -qi "ok"; then
  ok "Agent responded - install succeeded."
else
  echo "    smoke test did not return OK. Install may still work, check ~/.oal-quickstart-install.log"
fi

cat <<EOF

============================================================
 Done. Next steps:
============================================================

 1. Talk to your agent:
      openclaw chat

 2. Edit your agent's personality:
      \$EDITOR ~/.openclaw/workspace/IDENTITY.md
      \$EDITOR ~/.openclaw/workspace/SOUL.md

 3. Set up Telegram (optional):
      see docs/telegram-setup.md in this repo

 If anything broke, the install log is at:
      $LOG
 Email it to info@obsidianailabs.ca for help.
EOF
