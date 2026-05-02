#!/usr/bin/env bash
# OAL Quickstart - Linux installer (docker-compose edition)
# MIT. See LICENSE.
#
# Strategy: install docker if missing, clone the repo if missing, run
# `docker compose up -d`. That's it. No host-Ollama, no host-Bun, no
# host-OpenClaw — everything lives in containers so we can blow it
# away cleanly with `docker compose down -v`.
#
# Run interactively:    ./install.sh
# Run unattended:       OAL_ASSUME_YES=1 ./install.sh
# Run from curl pipe:   curl -fsSL https://install.obsidianailabs.co | bash
set -euo pipefail

LOG="${HOME}/.oal-quickstart-install.log"
exec > >(tee -a "$LOG") 2>&1

# Detect curl-pipe mode (no terminal stdin)
PIPED=0; [ -t 0 ] || PIPED=1
ASSUME_YES="${OAL_ASSUME_YES:-0}"

note() { printf "\n>>> %s\n" "$*"; }
ok()   { printf "    ok: %s\n" "$*"; }
warn() { printf "    WARN: %s\n" "$*"; }
ask()  {
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
  echo " For help, email the log to info@obsidianailabs.ca"
  echo " Re-run this script to retry. Most failures are recoverable."
  exit 1
}

echo
echo "============================================================"
echo " OAL Quickstart installer (docker-compose edition)"
echo " $(date -u +%FT%TZ)"
echo " Log: $LOG"
echo "============================================================"
echo
echo " Heads up before we start:"
echo
echo "  1. We'll install Docker if you don't have it."
echo "  2. We'll pull two container images: Ollama (~600 MB) and OpenClaw (~600 MB)."
echo "  3. We'll pull a 5 GB language model. On flaky internet this is the long part."
echo "  4. The first time you talk to your agent, the model loads into RAM."
echo "     YOUR COMPUTER MAY GET SLUGGISH FOR 30-60 SECONDS while it loads."
echo "     Your mouse may stutter. Apps may not respond. This is normal. It"
echo "     passes. After load, you can chat smoothly until you stop it."
echo "  5. Everything lives in containers. To completely remove this stack:"
echo "       docker compose down -v"
echo "     and the host stays clean."
echo
echo " The whole flow is roughly 10-30 minutes depending on your internet."
echo
ask "Continue?" || { echo "Cancelled."; exit 0; }

# ---- pre-flight ---------------------------------------------------------------

note "Checking OS"
[[ "$(uname -s)" == "Linux" ]] || bail "This installer is for Linux. macOS users: open OALQuickstart.pkg. Windows: OALQuickstart.exe."
ok "Linux: $(uname -srm)"

note "Checking CPU instruction set (modern Docker images need x86-64-v2)"
grep -q sse4_2 /proc/cpuinfo || bail "Your CPU is too old. We need x86-64-v2 (SSE4.2 + POPCNT, Intel 2008+ / AMD 2011+)."
grep -q popcnt /proc/cpuinfo || bail "Your CPU lacks POPCNT. Same x86-64-v2 issue."
ok "CPU OK (x86-64-v2)"

note "Checking RAM"
RAM_KB=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
RAM_GB=$(( RAM_KB / 1024 / 1024 ))
if (( RAM_GB < 8 )); then bail "Need 8 GB RAM minimum. You have ${RAM_GB} GB."; fi
if (( RAM_GB < 12 )); then
  warn "${RAM_GB} GB RAM. The model alone wants 5 GB resident. While it's running:"
  warn "  - your browser may have fewer free tabs"
  warn "  - the GUI may stutter during model load"
  warn "  - Docker will throttle other containers when memory gets tight"
  warn "16+ GB is the sweet spot. 12 GB is workable. 8 GB is 'try it but don't"
  warn "leave it running while you're doing other heavy work.'"
  ask "Proceed anyway?" 0 || bail "Cancelled."
else
  ok "RAM: ${RAM_GB} GB"
fi

note "Checking free disk in $HOME"
DISK_GB=$(df -BG --output=avail "$HOME" | tail -1 | tr -dc '0-9')
(( DISK_GB >= 20 )) || bail "Need 20 GB free in $HOME. You have ${DISK_GB} GB. Model + images + headroom."
ok "Free disk: ${DISK_GB} GB"

note "Checking for GPU"
if command -v nvidia-smi >/dev/null 2>&1; then
  GPU=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1 || true)
  ok "NVIDIA GPU: ${GPU:-detected}"
  if ! command -v nvidia-ctk >/dev/null 2>&1 && ! [ -e /etc/docker/daemon.json ]; then
    warn "GPU detected but nvidia-container-toolkit isn't installed."
    warn "Without it, the Docker container can't reach the GPU and inference"
    warn "falls back to CPU. To enable GPU later:"
    warn "  https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/"
    warn "Then uncomment the GPU block in docker-compose.yml and re-run 'docker compose up -d'."
  fi
else
  warn "No NVIDIA GPU detected. Inference will run on CPU."
  warn "Expect ~1 second per word. The first prompt of each session takes 30-60s"
  warn "to load the model into memory. Your GUI WILL stutter during that load."
  warn "After the first prompt it gets faster but stays CPU-bound."
  ask "Proceed anyway?" 1 || bail "Cancelled."
fi

# ---- Docker -------------------------------------------------------------------

note "Checking Docker"
if ! command -v docker >/dev/null 2>&1; then
  warn "Docker not found. Installing the official Docker Engine."
  curl -fsSL https://get.docker.com | sh || bail "Docker install failed. Manual: https://docs.docker.com/engine/install/"
fi
ok "Docker: $(docker --version)"

note "Checking docker compose plugin"
if ! docker compose version >/dev/null 2>&1; then
  bail "Docker Compose v2 plugin not found. Most modern docker installs ship it. Try: sudo apt-get install docker-compose-plugin"
fi
ok "Compose: $(docker compose version --short)"

note "Checking docker permissions"
if ! docker ps >/dev/null 2>&1; then
  warn "Your user can't talk to the docker socket. Adding you to the docker group."
  sudo usermod -aG docker "$USER" || bail "usermod failed."
  if command -v sg >/dev/null; then
    DOCKER_PREFIX="sg docker -c "
    warn "Using 'sg docker -c' for the rest of this run. After install, log out and back in to make it permanent."
  else
    bail "Group added but no 'sg' command. Log out, back in, then re-run."
  fi
else
  DOCKER_PREFIX=""
fi
run_dc() {
  if [[ -n "$DOCKER_PREFIX" ]]; then sg docker -c "docker compose $*"
  else docker compose "$@"
  fi
}

# ---- repo --------------------------------------------------------------------

note "Locating the OAL Quickstart repo"
SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "$(dirname "${BASH_SOURCE[0]}")/../../docker-compose.yml" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
elif [[ -d "$HOME/oal-quickstart" ]] && [[ -f "$HOME/oal-quickstart/docker-compose.yml" ]]; then
  SCRIPT_DIR="$HOME/oal-quickstart"
else
  warn "Repo not found locally. Cloning to $HOME/oal-quickstart"
  if ! command -v git >/dev/null 2>&1; then
    bail "git missing. Install: sudo apt-get install git, or use the USB stick / direct download."
  fi
  git clone https://github.com/obsidian-ai-labs/oal-quickstart.git "$HOME/oal-quickstart" || bail "git clone failed."
  SCRIPT_DIR="$HOME/oal-quickstart"
fi
cd "$SCRIPT_DIR"
ok "Repo: $SCRIPT_DIR"

# ---- compose up --------------------------------------------------------------

note "Pulling container images (Ollama + OpenClaw, ~1.2 GB total)"
run_dc "pull" || bail "compose pull failed. Check network."
ok "Images pulled"

note "Starting services (Ollama → ollama-init pulls the model → OpenClaw gateway)"
echo "    The model pull (~5 GB) runs once and is the slow part."
echo "    Watch it live: docker compose logs -f ollama-init"
run_dc "up -d" || bail "compose up failed. Try: docker compose logs"

note "Waiting for the gateway to come up"
for i in $(seq 1 60); do
  if run_dc "ps gateway --format json" 2>/dev/null | grep -q '"State":"running"'; then
    ok "Gateway running"
    break
  fi
  if (( i == 60 )); then
    bail "Gateway didn't start in 60s. Run: docker compose logs gateway"
  fi
  sleep 2
done

# ---- post-install ------------------------------------------------------------

cat <<EOF

============================================================
 Done. Your private local AI agent is online.
============================================================

 Talk to it:
   cd $SCRIPT_DIR
   docker compose exec gateway openclaw chat --agent main

 Edit its personality (the agent reads this every turn):
   \$EDITOR $SCRIPT_DIR/openclaw-state/workspace/USER.md
   \$EDITOR $SCRIPT_DIR/openclaw-state/workspace/SOUL.md

 Stop everything:
   cd $SCRIPT_DIR && docker compose down

 Start it back up:
   cd $SCRIPT_DIR && docker compose up -d

 NUKE everything (containers, volumes, model weights):
   cd $SCRIPT_DIR && docker compose down -v
   docker volume rm oal-ollama-models 2>/dev/null

 Logs:
   docker compose logs -f          (all services)
   docker compose logs -f gateway  (just the agent)
   docker compose logs -f ollama   (just the model server)

 If your computer feels sluggish: that's the model loading into RAM.
 Wait 30-60 seconds, then talk to your agent. If it's permanently
 sluggish, your machine is below the recommended floor — bump RAM
 or add a GPU. You can also lower the memory cap in docker-compose.yml
 (services.ollama.deploy.resources.limits.memory) to be a less
 greedy neighbor.

 Help: $LOG  →  email it to info@obsidianailabs.ca
EOF

if [[ -n "$DOCKER_PREFIX" ]]; then
  echo
  echo " IMPORTANT: log out and back in (or run 'newgrp docker') so your"
  echo " shell can run 'docker compose' without 'sg docker -c' going forward."
fi
