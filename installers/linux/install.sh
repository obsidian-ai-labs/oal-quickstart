#!/usr/bin/env bash
# OAL Quickstart - Linux installer
# Public domain (MIT). See LICENSE in the repo root.
#
# Designed for: someone who heard "private local AI agent" and clicked install,
# not for someone who already knows what Ollama is. Every step explains itself.
# Every error tells you exactly what to do next.
#
# Run interactively:    ./install.sh
# Run unattended:       OAL_ASSUME_YES=1 ./install.sh
# Run from a curl pipe: curl -fsSL https://install.obsidianailabs.co | bash
set -euo pipefail

LOG="${HOME}/.oal-quickstart-install.log"
MARK="${HOME}/.oal-quickstart-progress"
exec > >(tee -a "$LOG") 2>&1

# Detect curl-pipe mode (no terminal stdin)
PIPED=0; [ -t 0 ] || PIPED=1
ASSUME_YES="${OAL_ASSUME_YES:-0}"

note() { printf "\n>>> %s\n" "$*"; }
ok()   { printf "    ok: %s\n" "$*"; }
warn() { printf "    WARN: %s\n" "$*"; }
ask()  {
  # Prints a yes/no question. Returns 0 (yes) by default if piped or assume-yes.
  local prompt="$1" default_yes="${2:-1}"
  if [[ "$ASSUME_YES" == "1" || "$PIPED" == "1" ]]; then
    [[ "$default_yes" == "1" ]] && return 0 || return 1
  fi
  read -rp "    $prompt [Y/n] " ans
  [[ -z "$ans" || "$ans" =~ ^[Yy]$ ]]
}
bail() {
  echo
  echo "============================================================"
  echo " INSTALL STOPPED: $*"
  echo "============================================================"
  echo " Full log: $LOG"
  echo " If you want help, email the log to info@obsidianailabs.ca"
  echo " Most installs that fail here recover with:"
  echo "   $0       # re-run, the script picks up where it left off"
  exit 1
}

mark_done() { echo "$1" >> "$MARK"; }
already_done() { [[ -f "$MARK" ]] && grep -q "^$1$" "$MARK"; }

echo
echo "============================================================"
echo " OAL Quickstart installer (Linux)"
echo " $(date -u +%FT%TZ)"
echo " Log: $LOG"
echo "============================================================"
echo
echo " This will install Ollama, pull a 5 GB AI model, and install"
echo " OpenClaw (the agent gateway). It runs entirely on your machine"
echo " and we never see your data."
echo
echo " Idempotent: safe to re-run if anything fails. It picks up where"
echo " it left off."
echo
ask "Continue?" || { echo "Cancelled."; exit 0; }

# ---- pre-flight ----------------------------------------------------------------

note "Checking OS"
if [[ "$(uname -s)" != "Linux" ]]; then
  bail "This installer is for Linux. macOS users: open OALQuickstart.pkg. Windows users: run OALQuickstart.exe."
fi
ok "Linux: $(uname -srm)"

note "Checking CPU instruction set (Bun and modern Node need x86-64-v2)"
if ! grep -q sse4_2 /proc/cpuinfo; then
  bail "Your CPU is too old. We need at least x86-64-v2 (SSE4.2 + POPCNT, Intel Nehalem 2008+ / AMD Bulldozer 2011+). Bun won't run on older silicon. Try a newer machine."
fi
if ! grep -q popcnt /proc/cpuinfo; then
  bail "Your CPU lacks POPCNT. We need x86-64-v2. This typically means a server/laptop from before 2010."
fi
ok "CPU OK (x86-64-v2 confirmed)"

note "Checking RAM"
RAM_KB=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
RAM_GB=$(( RAM_KB / 1024 / 1024 ))
if (( RAM_GB < 8 )); then
  bail "Need at least 8 GB RAM. You have ${RAM_GB} GB. The 8B model needs ~5 GB resident plus your OS overhead."
fi
if (( RAM_GB < 16 )); then
  warn "Only ${RAM_GB} GB RAM. Install will work but the agent will swap on big prompts. 16+ GB strongly recommended."
  ask "Continue anyway?" 0 || bail "Cancelled."
else
  ok "RAM: ${RAM_GB} GB"
fi

note "Checking free disk in $HOME"
DISK_GB=$(df -BG --output=avail "$HOME" | tail -1 | tr -dc '0-9')
if (( DISK_GB < 16 )); then
  bail "Need at least 16 GB free in $HOME. You have ${DISK_GB} GB. Free up space (the model alone is 5 GB) and re-run."
fi
ok "Free disk: ${DISK_GB} GB"

note "Checking for GPU"
if command -v nvidia-smi >/dev/null 2>&1; then
  GPU=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1 || true)
  ok "NVIDIA GPU: ${GPU:-detected}"
elif command -v rocm-smi >/dev/null 2>&1; then
  ok "AMD ROCm GPU detected"
elif [[ -e /dev/kfd ]]; then
  ok "Possible AMD GPU (kfd device present)"
else
  warn "No GPU detected. Inference will run on CPU - expect ~1 second per word, sometimes slower."
  warn "This is fine for trying it out, painful for daily use."
  ask "Continue anyway?" 1 || bail "Cancelled. Try again on a machine with an NVIDIA or AMD GPU."
fi

note "Checking package manager (we use apt-get / pacman / dnf for some deps)"
if command -v apt-get >/dev/null; then PM=apt-get
elif command -v dnf >/dev/null;     then PM=dnf
elif command -v pacman >/dev/null;  then PM=pacman
else
  warn "Unknown package manager. Will skip system-package install steps."
  PM=""
fi
[[ -n "$PM" ]] && ok "Package manager: $PM" || true

note "Checking ports we'll use"
for p in 11434 18789; do
  if command -v ss >/dev/null && ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":${p}\$"; then
    warn "Port $p is already in use. If install fails later, free it and re-run."
  fi
done

# ---- bun (we never use npm or pnpm) -------------------------------------------

note "Installing Bun (we deliberately avoid npm and pnpm - long story, ask Brandon)"
if command -v bun >/dev/null 2>&1; then
  ok "Bun: $(bun --version)"
elif already_done bun_installed; then
  export PATH="$HOME/.bun/bin:$PATH"
  ok "Bun was installed earlier"
else
  curl -fsSL https://bun.sh/install | bash || bail "Bun install failed. Check the log for the actual curl error. Re-running this script will retry."
  export PATH="$HOME/.bun/bin:$PATH"
  mark_done bun_installed
  ok "Bun: $(bun --version)"
fi

# Persist Bun on PATH for the user's future shells
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [[ -f "$rc" ]] && ! grep -q '/.bun/bin' "$rc"; then
    echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$rc"
    ok "Added Bun to PATH in $rc"
  fi
done

# ---- Ollama -------------------------------------------------------------------

note "Installing Ollama (the local LLM runtime)"
if command -v ollama >/dev/null 2>&1; then
  ok "Ollama already installed: $(ollama --version 2>&1 | head -1)"
elif already_done ollama_installed; then
  ok "Ollama install was already attempted"
else
  if ! curl -fsSL https://ollama.com/install.sh | sh; then
    bail "Ollama install failed. Common causes: sudo prompt declined, or your distro's systemd is unhappy. Re-run after fixing."
  fi
  mark_done ollama_installed
fi

note "Starting Ollama (it needs to be running so we can pull a model)"
if pgrep -x ollama >/dev/null 2>&1; then
  ok "Ollama already running"
else
  # Try systemd user, then system, then nohup foreground
  if systemctl --user start ollama 2>/dev/null; then
    ok "Started Ollama as user service"
  elif sudo systemctl start ollama 2>/dev/null; then
    ok "Started Ollama as system service"
  else
    nohup ollama serve > "$HOME/.ollama-server.log" 2>&1 &
    sleep 4
    pgrep -x ollama >/dev/null 2>&1 || bail "Could not start Ollama. Check ~/.ollama-server.log"
    warn "Ollama running as a backgrounded process. It will not survive reboot. Set up a systemd unit later."
  fi
fi

# Wait for the API socket
for i in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1; then break; fi
  sleep 1
done
curl -fsS http://localhost:11434/api/tags >/dev/null || bail "Ollama API not responding on port 11434 after 10s. Check ~/.ollama-server.log"
ok "Ollama API responding on :11434"

note "Pulling the starter model llama3.1:8b (~5 GB - this is the slow part on first install)"
if ollama list 2>/dev/null | grep -q '^llama3.1:8b'; then
  ok "Model already pulled"
elif already_done model_pulled; then
  ok "Model pull was already attempted"
else
  echo "    Estimated time: 5-30 min depending on your internet."
  echo "    If your connection drops, just re-run this script and the resume will pick up."
  for attempt in 1 2 3; do
    if ollama pull llama3.1:8b; then
      mark_done model_pulled
      ok "Model pulled"
      break
    fi
    warn "Pull attempt $attempt failed. Waiting 10s and retrying."
    sleep 10
    [[ "$attempt" == "3" ]] && bail "Model pull failed 3 times. Check internet, then re-run."
  done
fi

# ---- OpenClaw (Docker) --------------------------------------------------------

note "Installing OpenClaw"
echo "    OpenClaw runs in Docker. It's the agent gateway that lets you talk"
echo "    to your local model from a CLI, Telegram, Slack, etc."

if ! command -v docker >/dev/null 2>&1; then
  warn "Docker not found. Installing the official Docker engine."
  if [[ -n "$PM" ]]; then
    curl -fsSL https://get.docker.com | sh || bail "Docker install failed. Try manually: https://docs.docker.com/engine/install/"
  else
    bail "No package manager and no Docker. Install Docker manually first: https://docs.docker.com/engine/install/"
  fi
fi

# Permission check: can we talk to docker without sudo?
if ! docker ps >/dev/null 2>&1; then
  warn "Your user can't reach the docker socket. Adding you to the 'docker' group."
  warn "After this script finishes you MUST log out and back in (or run 'newgrp docker') so the group takes effect."
  sudo usermod -aG docker "$USER" || bail "Couldn't add you to docker group. Run: sudo usermod -aG docker \$USER, then re-run this script."
  if command -v sg >/dev/null; then
    DOCKER_PREFIX="sg docker -c "
    warn "Using 'sg docker -c' for the rest of this run."
  else
    bail "You're not in the docker group yet. Log out, log back in, then re-run."
  fi
else
  DOCKER_PREFIX=""
fi

run_docker() {
  if [[ -n "$DOCKER_PREFIX" ]]; then
    sg docker -c "$*"
  else
    eval "$@"
  fi
}

note "Pulling OpenClaw image (~600 MB)"
run_docker "docker pull ghcr.io/openclaw/openclaw:main" || bail "Docker pull failed. Check network and re-run."
ok "Image pulled"

# ---- workspace bootstrap ------------------------------------------------------

note "Setting up your agent workspace at ~/.openclaw/"
WORKSPACE="$HOME/.openclaw/workspace"
mkdir -p "$WORKSPACE"

# Find templates - works whether we're in a clone or running via curl pipe
TPL_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -d "$(dirname "${BASH_SOURCE[0]}")/../../templates/workspace" ]]; then
  TPL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../templates/workspace" && pwd)"
elif [[ -d "/tmp/oal-quickstart-templates" ]]; then
  TPL_DIR="/tmp/oal-quickstart-templates"
else
  # Curl-pipe path: download templates fresh
  warn "Templates not found locally; downloading from github."
  TPL_DIR=$(mktemp -d)
  for f in IDENTITY.md SOUL.md AGENTS.md USER.md MEMORY.md; do
    curl -fsSL -o "$TPL_DIR/$f" "https://raw.githubusercontent.com/obsidian-ai-labs/oal-quickstart/main/templates/workspace/$f" || true
  done
fi

for f in IDENTITY.md SOUL.md AGENTS.md USER.md MEMORY.md; do
  if [[ ! -f "$WORKSPACE/$f" && -f "$TPL_DIR/$f" ]]; then
    cp "$TPL_DIR/$f" "$WORKSPACE/$f"
    ok "wrote workspace/$f"
  fi
done

# ---- minimal openclaw.json ----------------------------------------------------

CONFIG="$HOME/.openclaw/openclaw.json"
if [[ ! -f "$CONFIG" ]]; then
  cat > "$CONFIG" <<'JSON'
{
  "models": {
    "providers": {
      "local-ollama": {
        "baseUrl": "http://host.docker.internal:11434/v1",
        "apiKey": "dummy-ollama-no-auth",
        "api": "openai-completions",
        "models": [{
          "id": "llama3.1:8b",
          "name": "llama3.1:8b (Local)",
          "contextWindow": 32768,
          "maxTokens": 8192,
          "input": ["text"],
          "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
          "reasoning": false
        }]
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

# ---- start the gateway --------------------------------------------------------

note "Starting OpenClaw gateway container"
run_docker "docker rm -f oal-gateway 2>/dev/null || true"
run_docker "docker run -d --name oal-gateway --restart unless-stopped \
  --add-host=host.docker.internal:host-gateway \
  -p 127.0.0.1:18789:18789 \
  -v $HOME/.openclaw:/home/node/.openclaw \
  ghcr.io/openclaw/openclaw:main" || bail "Container start failed. Check 'docker logs oal-gateway'."

sleep 4
if run_docker "docker ps --filter name=oal-gateway --format '{{.Status}}'" | grep -q -i "Up"; then
  ok "Gateway running on 127.0.0.1:18789"
else
  bail "Gateway didn't stay up. Check: docker logs oal-gateway"
fi

# ---- post-install -------------------------------------------------------------

mark_done install_complete

cat <<EOF

============================================================
 Done. Your private local AI agent is running.
============================================================

 Talk to it:
   docker exec -it oal-gateway openclaw chat --agent main

 Edit its personality (this is the file it reads every turn):
   \$EDITOR ~/.openclaw/workspace/USER.md
   \$EDITOR ~/.openclaw/workspace/SOUL.md

 Stop it:
   docker stop oal-gateway

 Start it again:
   docker start oal-gateway

 Set up Telegram (optional):
   See docs/telegram-setup.md in this repo.

 Logs and state:
   $LOG       (this install)
   docker logs oal-gateway   (the running gateway)

 If something broke, email the install log to info@obsidianailabs.ca.
EOF

if [[ -n "$DOCKER_PREFIX" ]]; then
  echo
  echo " IMPORTANT: log out and back in (or run 'newgrp docker') so you can"
  echo " 'docker' without 'sg docker -c' going forward."
fi
