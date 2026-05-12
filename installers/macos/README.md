# PAI Setup for macOS — you

Welcome. This walks you from a fresh MacBook to a working PAI install in about 20-30 minutes. We'll go end-to-end together when I'm out at your home or office, but you can do most of it on your own in advance if you want a head start.

## What you're installing

PAI (Personal AI Infrastructure) is a directory tree at `~/.claude/` that gives you:

- A persistent AI assistant (Claude Code) running in your terminal
- A memory tree that survives across sessions
- A place to add skills, agents, and tools as you grow the system
- The substrate to eventually run a fleet of named agents that handle specific jobs for your business

This package gives you the foundation. We'll wire up the actual your industry-specific agents (paperwork generation, transaction coordination, follow-up automation) when I'm in your home or office.

## Prerequisites

- A Mac (Apple Silicon M1/M2/M3/M4 preferred; Intel will work but slower)
- macOS 13 (Ventura) or newer
- About 5 GB of free disk space
- An Anthropic account (for Claude API access — sign up at console.anthropic.com if you don't have one)
- Optional but recommended: an OpenAI account for Whisper transcription
- Optional: an ElevenLabs account if you want voice features

## Step 1 — Run the installer script

Open Terminal (Cmd+Space, type "Terminal", press Enter).

Copy and paste this single line:

```bash
curl -fsSL https://obsidianailabs.ca/install/install-pai-mac.sh | bash
```

(Brandon will give you the exact URL when the package is hosted. For now you can run the local copy I'm sending you.)

The script will:

1. Install Homebrew if you don't have it (asks for your password)
2. Install bun, git, ffmpeg, yt-dlp, gh, jq, ripgrep via Homebrew
3. Install Node.js 22 (Claude Code requires Node)
4. Install Claude Code CLI globally
5. Create `~/.claude/` with the PAI skeleton directories
6. Drop a `.env.template` you fill in with your own keys
7. Create a minimal `CLAUDE.md` you can customize as you go
8. Print next-step instructions

The whole script is non-destructive. If you already have Homebrew or any of the tools, it skips them. If anything fails, it stops and tells you why.

Expected runtime: 10-15 minutes on a fresh Mac, mostly waiting for Homebrew to download things.

## Step 2 — Fill in your `.env`

After the script finishes:

```bash
cd ~/.claude
cp .env.template .env
nano .env       # or open in any editor: open -e .env
```

You'll fill in at least:

- `ANTHROPIC_API_KEY` — from console.anthropic.com → Settings → API Keys
- `USER_EMAIL` — your email address
- `USER_NAME` — "you"

Optional (add later):

- `OPENAI_API_KEY` — for Whisper voice transcription
- `ELEVENLABS_API_KEY` — for voice cloning / TTS
- `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` — to reach your assistant via Telegram (we'll set this up together in the office)
- `DIGITALOCEAN_ACCESS_TOKEN` — for deploying client-facing infrastructure
- `CLOUDFLARE_API_TOKEN` — for DNS automation

Leave anything you don't have blank. The system handles missing keys gracefully and you can fill them in as you go.

## Step 3 — Customize `CLAUDE.md`

`~/.claude/CLAUDE.md` is the instruction file your AI reads at the start of every session. The installer drops a minimal version that says "you are you's assistant; be helpful." We'll add the more sophisticated structure (modes, agents, voice rules) together when I'm out.

## Step 4 — Launch Claude Code

From your terminal:

```bash
cd ~/.claude
claude
```

You should see the Claude Code interface. Try asking it: "What's in this directory?" — it should be able to read your files and answer.

If you see an "Allow this folder?" prompt, type `1` and press Enter. (This is Claude Code's "trust this workspace" check.)

## Step 5 — Send me a screenshot

Once you're at the Claude Code prompt with no errors, screenshot the terminal and send it to me via the same channel we've been using. That confirms everything's installed and we can do the rest in person.

## Things that might go wrong (and how to recover)

### "Command not found: brew"
The Homebrew install didn't complete. Run the installer again:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then re-run my installer script.

### "Permission denied" when running the script
Sometimes macOS gates curl-piped-to-bash. Download the script first:

```bash
curl -fsSL https://obsidianailabs.ca/install/install-pai-mac.sh -o ~/install-pai-mac.sh
chmod +x ~/install-pai-mac.sh
~/install-pai-mac.sh
```

### "Claude Code wants to allow incoming network connections"
Click Allow. Claude Code needs to reach Anthropic's API.

### Anything else
Save the terminal output (Cmd+A, Cmd+C, paste to a file), send it to me. We'll figure it out together.

## What you'll have when this is done

- `~/.claude/` with the standard PAI directory tree
- Claude Code installed and running
- All the system-level tools (bun, ffmpeg, yt-dlp, etc) that the more advanced workflows need
- A clean foundation we can build your your industry-specific agents on top of

## What you WON'T have yet

- Any of my actual production data, agents, clients, memory, or skills. This is intentional. You're getting the architecture, not my business. We build YOUR fleet from scratch on top of this foundation.

## When you're ready

Tell me which day works for the office visit and I'll come out. Plan for 6-8 hours so we have time to actually wire things up to your real workflows (paperwork generation, transaction coordination, the DocuSign pain you showed me).

Talk soon.

— Brandon
