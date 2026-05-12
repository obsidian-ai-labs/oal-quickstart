#!/usr/bin/env bash
# install-pai-mac.sh — PAI bootstrap installer for macOS
#
# Idempotent. Re-runnable. Non-destructive to existing tooling.
# Brings a fresh Mac (or a partial install) to a working PAI baseline.
#
# Run:
#   curl -fsSL <hosted-url>/install-pai-mac.sh | bash
# Or:
#   chmod +x install-pai-mac.sh && ./install-pai-mac.sh
#
# What it does:
#   1. Verifies macOS + checks Apple Silicon vs Intel
#   2. Installs Homebrew (if missing)
#   3. Installs core CLI tools (bun, git, ffmpeg, yt-dlp, gh, jq, ripgrep, node@22)
#   4. Installs Claude Code CLI globally
#   5. Scaffolds ~/.claude/ with the PAI baseline directory tree
#   6. Drops .env.template, CLAUDE.md skeleton, and ABOUTME template
#   7. Prints next-step instructions
#
# What it does NOT do:
#   - Touch existing ~/.claude/ files (will skip with a warning if found)
#   - Install any of Brandon's production data, agents, memory, or skills
#   - Set up SSH keys, Telegram bots, or any agent fleet beyond the local Claude Code session
#
# License: MIT
# Author: Brandon Dietz / Obsidian AI Labs Inc. (obsidianailabs.ca)
# Repo: https://github.com/obsidianailabs/pai-install   (placeholder — update once repo is live)
# ---------------------------------------------------------------------------

set -euo pipefail

# Colors
RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YLW=$'\033[1;33m'; BLU=$'\033[0;34m'; NC=$'\033[0m'

log()  { printf "%s\n" "${BLU}[pai-install]${NC} $*"; }
ok()   { printf "%s\n" "${GRN}[ok]${NC} $*"; }
warn() { printf "%s\n" "${YLW}[warn]${NC} $*"; }
err()  { printf "%s\n" "${RED}[err]${NC} $*" >&2; }

# ---------------------------------------------------------------------------
# Step 1 — Sanity checks
# ---------------------------------------------------------------------------
log "Step 1/6 — Sanity checks"

if [[ "$(uname)" != "Darwin" ]]; then
  err "This installer is macOS-only. Detected: $(uname)"
  exit 1
fi

MAC_ARCH="$(uname -m)"
case "$MAC_ARCH" in
  arm64) ok "Apple Silicon Mac detected (${MAC_ARCH})" ;;
  x86_64) warn "Intel Mac detected. Will work, but slower. Consider an M-series upgrade eventually." ;;
  *) err "Unknown architecture: $MAC_ARCH"; exit 1 ;;
esac

MAC_VERSION="$(sw_vers -productVersion)"
log "macOS version: $MAC_VERSION"

# Check macOS >= 13 (Ventura). String comparison is fine for "13.x" vs "12.x".
MAC_MAJOR="${MAC_VERSION%%.*}"
if (( MAC_MAJOR < 13 )); then
  err "macOS 13 (Ventura) or newer required. You're on $MAC_VERSION."
  err "Upgrade via System Settings > General > Software Update, then re-run this script."
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 2 — Homebrew
# ---------------------------------------------------------------------------
log "Step 2/6 — Homebrew"

if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew (will prompt for your Mac password)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for current shell (Apple Silicon vs Intel paths differ)
  if [[ "$MAC_ARCH" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  ok "Homebrew already installed: $(brew --version | head -1)"
fi

# ---------------------------------------------------------------------------
# Step 3 — Core CLI tools
# ---------------------------------------------------------------------------
log "Step 3/6 — Core CLI tools"

CORE_PKGS=(git bun ffmpeg yt-dlp gh jq ripgrep node@22)

for pkg in "${CORE_PKGS[@]}"; do
  if brew list "$pkg" >/dev/null 2>&1; then
    ok "$pkg already installed"
  else
    log "Installing $pkg..."
    brew install "$pkg" || warn "$pkg install failed — continuing"
  fi
done

# Make sure node@22 is linked
brew link --overwrite node@22 2>/dev/null || true

# Sanity-check the toolchain
log "Verifying tool versions:"
for cmd in git bun node ffmpeg yt-dlp gh jq rg; do
  if command -v "$cmd" >/dev/null 2>&1; then
    v="$("$cmd" --version 2>/dev/null | head -1 || echo '?')"
    ok "  $cmd: $v"
  else
    warn "  $cmd: NOT FOUND"
  fi
done

# ---------------------------------------------------------------------------
# Step 4 — Claude Code CLI
# ---------------------------------------------------------------------------
log "Step 4/6 — Claude Code CLI"

if command -v claude >/dev/null 2>&1; then
  ok "Claude Code already installed: $(claude --version 2>/dev/null || echo 'present')"
else
  log "Installing Claude Code globally via npm..."
  npm install -g @anthropic-ai/claude-code
fi

# ---------------------------------------------------------------------------
# Step 5 — PAI directory scaffold
# ---------------------------------------------------------------------------
log "Step 5/6 — PAI directory scaffold at ~/.claude/"

PAI_ROOT="$HOME/.claude"
mkdir -p "$PAI_ROOT"

# Standard PAI tree
mkdir -p "$PAI_ROOT/PAI/USER"
mkdir -p "$PAI_ROOT/PAI/Tools"
mkdir -p "$PAI_ROOT/PAI/DOCUMENTATION"
mkdir -p "$PAI_ROOT/skills"
mkdir -p "$PAI_ROOT/agents"
mkdir -p "$PAI_ROOT/MEMORY/KNOWLEDGE"
mkdir -p "$PAI_ROOT/MEMORY/WORK"
mkdir -p "$PAI_ROOT/MEMORY/STATE"
mkdir -p "$PAI_ROOT/MEMORY/LOGS"

# .env.template — never overwrite an existing .env
ENV_TEMPLATE="$PAI_ROOT/.env.template"
cat > "$ENV_TEMPLATE" <<'ENVEOF'
# PAI Environment Variables
# Copy this file to ~/.claude/.env and fill in your own keys.
# Source: this template ships blank. Brandon's production keys are NOT in here.

# ----- REQUIRED -----
ANTHROPIC_API_KEY=""
USER_EMAIL=""
USER_NAME=""

# ----- OPTIONAL (add as you need them) -----

# Whisper transcription
OPENAI_API_KEY=""

# ElevenLabs voice features
ELEVENLABS_API_KEY=""

# Telegram bridge (Brandon will help you set this up in person)
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Cloud infrastructure (when you start deploying client-facing tools)
DIGITALOCEAN_ACCESS_TOKEN=""
CLOUDFLARE_API_TOKEN=""

# DNS provider (if you use GoDaddy instead of Cloudflare)
GODADDY_API_KEY=""
GODADDY_API_SECRET=""

# Reach: add your own keys as you expand the system.
ENVEOF

ok "Wrote $ENV_TEMPLATE"

# CLAUDE.md skeleton — minimal, NOT Brandon's production one
CLAUDE_MD="$PAI_ROOT/CLAUDE.md"
if [[ -f "$CLAUDE_MD" ]]; then
  warn "$CLAUDE_MD already exists — leaving it alone"
else
  cat > "$CLAUDE_MD" <<'CMDEOF'
# Personal AI Infrastructure (PAI) — Minimal Configuration

You are my AI assistant. We're at the beginning of building out the system.

## About me
See `PAI/USER/ABOUTME.md` for the canonical bio.

## How we work
- Be direct. Be honest. Skip the preamble.
- Read files before answering questions about them.
- When I ask you to build or change something, walk me through what you're about to do before you do it for the first few sessions, then move faster once we've established rhythm.

## What lives where
- `PAI/USER/` — about me, my preferences, my goals
- `PAI/Tools/` — scripts and helpers you and I write together
- `skills/` — capability packages we add over time
- `agents/` — specialized agents we add later (sales, ops, content)
- `MEMORY/KNOWLEDGE/` — notes you take that should persist
- `MEMORY/WORK/` — current and recent project notes
- `MEMORY/STATE/` — runtime state files
- `MEMORY/LOGS/` — observability and audit logs

## Notes for the install session with Brandon
This is the bootstrap CLAUDE.md. Brandon will expand it during the office visit to include the more sophisticated structure (operating modes, agent fleet, voice rules, etc).
CMDEOF
  ok "Wrote $CLAUDE_MD"
fi

# ABOUTME.md template
ABOUT_ME="$PAI_ROOT/PAI/USER/ABOUTME.md"
if [[ -f "$ABOUT_ME" ]]; then
  warn "$ABOUT_ME already exists — leaving it alone"
else
  cat > "$ABOUT_ME" <<'AMEOF'
# About Me

This file is the canonical place where my AI assistant learns who I am. Update it whenever your situation changes — career, family, business, goals, preferences, ongoing projects.

## Identity
- **Name:** [your name]
- **Location:** [city, country]
- **Role:** [what you do for a living, in plain language]

## Background
- [Education or formative experience]
- [Years/decades in your primary field]
- [Anything else relevant]

## What I'm working on right now
- [Current project / focus / pain]

## How I like to communicate
- [Direct vs verbose, formal vs casual, etc.]

## What's off-limits
- [Topics, content types, or framings you don't want generated]
AMEOF
  ok "Wrote $ABOUT_ME (template — fill it in)"
fi

# README inside PAI
cat > "$PAI_ROOT/PAI/README.md" <<'PAIRMEOF'
# PAI — Personal AI Infrastructure

This is the substrate. Skills, agents, tools, and memory all live underneath.

Conventions:
- One folder per skill at `~/.claude/skills/<SkillName>/SKILL.md`
- One file per agent at `~/.claude/agents/<AgentName>.md`
- Tools as standalone executable scripts at `~/.claude/PAI/Tools/`
- Memory organized by purpose (KNOWLEDGE = facts, WORK = active projects, STATE = runtime, LOGS = observability)

To launch Claude Code with this directory loaded:

```bash
cd ~/.claude && claude
```
PAIRMEOF

# ---------------------------------------------------------------------------
# Step 6 — Done
# ---------------------------------------------------------------------------
log "Step 6/6 — Wrap-up"

cat <<DONEEOF

${GRN}═══════════════════════════════════════════════════════════════${NC}
${GRN}  PAI installation complete${NC}
${GRN}═══════════════════════════════════════════════════════════════${NC}

Next steps:

  1. Copy the env template and fill in your keys:
       ${BLU}cp ~/.claude/.env.template ~/.claude/.env${NC}
       ${BLU}open -e ~/.claude/.env${NC}

  2. Fill in PAI/USER/ABOUTME.md with your real info:
       ${BLU}open -e ~/.claude/PAI/USER/ABOUTME.md${NC}

  3. Launch Claude Code:
       ${BLU}cd ~/.claude && claude${NC}

  4. When prompted "Allow this folder?", type ${BLU}1${NC} and press Enter

  5. Ask Claude: "${BLU}What's in this directory?${NC}" to verify everything's wired up

  6. Screenshot the working Claude Code prompt and send it to Brandon

The next layer (Telegram bridge, voice features, agent fleet, real-estate-specific
skills) will get built together during the office visit. Tonight you have the
foundation. That's enough.

— Brandon / Obsidian AI Labs
DONEEOF
