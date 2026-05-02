# OAL Quickstart

A private AI agent that lives entirely on your computer. Plug in the USB (or run one curl command), wait ten minutes, and you have a real local-first AI assistant. Your prompts never leave your machine. We never see your data.

## What this is for

You want to try running a private AI on your own hardware, but the path between "interested" and "running" is paved with broken installers, mismatched dependencies, weird Docker permission errors, GPU drivers that don't load, and config files written for a developer audience. We hit every one of those installing this stuff for ourselves over the past few months. This installer turns each of those moments into a one-line check that tells you what's wrong and how to fix it.

If you can run a script, you can run this.

## What you'll have when it finishes

The whole stack is one Docker Compose file. Two containers:

- **ollama** - serves a small open-source language model on the docker network, with a 5 GB persistent volume for weights
- **gateway** (OpenClaw) - your agent runtime, listens on `127.0.0.1:18789` (loopback only, not exposed to the internet)

Plus a starter agent identity at `openclaw-state/workspace/` that you edit to give your agent a personality. The agent reads those files at the start of every turn.

That's it. No cloud accounts. No telemetry. No phone-home. The source for every line is in this repo so you can verify.

**Why containers for everything?** So you can stop and start the whole stack as a unit (`docker compose down` / `docker compose up -d`), and so a clean uninstall is `docker compose down -v` and you're back to a virgin host. No leftover host-installed services, no PATH mods you have to clean up.

## A real heads-up about your computer

The agent runs locally. That means your machine actually does the work. Two times this is noticeable:

**First-prompt model load (30-60 seconds, once per session).** When you start the gateway and ask it the first thing, the model loads from disk into RAM. It's a 5 GB load. Your computer will feel sluggish during the load. Mouse may stutter. Apps may not respond instantly. This is normal. After load, the model stays warm.

**Every inference, every time (a few seconds, every prompt).** The model has to compute the response. On CPU that's tokens-per-second territory and your machine is doing real work the whole time it's generating. On GPU it's much faster but still ramps the GPU to 100% briefly. If you're trying to do a video call AND chat with the agent at the same time, expect the video call to glitch. Don't run the agent while you're doing memory-heavy work like a build or a virtual machine.

If the sluggishness sticks around between prompts — meaning your apps are slow even when the agent is idle — your machine is below the recommended floor. Two options:

1. Lower the memory cap in `docker-compose.yml` under `services.ollama.deploy.resources.limits.memory`. Default is `8G`. Try `6G`. You'll trade some speed for not locking up your other apps.
2. Stop the stack when you're not using it. `docker compose down` parks everything; `docker compose up -d` brings it back in seconds.

If you're on a laptop without a GPU and you find the per-prompt latency painful, this is a hardware ceiling, not an installer issue. The model doing real math on a CPU is just slow. The fix is either a GPU or a smaller model (uncomment qwen2.5:3b in `docker-compose.yml` once we add it).

## Hardware floor (the installer checks this for you)

- 8 GB RAM minimum, 16+ GB strongly recommended. The install warns between 8 and 12, refuses below 8. At 8 GB you can run it but expect to keep your browser tab count modest.
- 20 GB free disk space (the model itself is ~5 GB, plus container images, plus headroom).
- An x86-64-v2 CPU (Intel Nehalem 2008+ / AMD Bulldozer 2011+). The installer refuses on older silicon because modern container images won't run there. We learned this trying to install on a 2007 Xeon.
- A GPU is not required, but without one the agent runs at roughly one word per second. Fine for trying it out, painful for daily use. With NVIDIA GPU you can uncomment the GPU block in `docker-compose.yml` (requires `nvidia-container-toolkit`).

If your machine doesn't pass these checks the installer stops and tells you exactly why.

## Install

Pick one path:

### Path A: USB stick (the lowest-friction path)

Plug in the USB. It auto-mounts. Run the installer for your OS.

- Linux: `cd /media/<your-user>/OAL-Quickstart && ./installers/linux/install.sh`
- macOS: double-click `installers/macos/OALQuickstart.pkg`
- Windows: double-click `installers/windows/OALQuickstart.exe`

The USB carries the model file (~5 GB) so first install works without internet.

### Path B: One-liner from the public repo

For Linux and macOS users who'd rather pull from source:

```bash
curl -fsSL https://install.obsidianailabs.co | bash
```

(Behind the scenes that's just `installers/linux/install.sh` from this repo. Read it before running.)

### Path C: Clone and run

```bash
git clone https://github.com/obsidian-ai-labs/oal-quickstart.git
cd oal-quickstart
./installers/linux/install.sh   # or installers/macos/install.command
```

## Issues we hit so you don't have to

These were our actual failures during weeks of installing this for ourselves and clients. The installer detects each one and tells you what to do.

**0. Your computer freezes for a minute the first time you ask the agent anything.** This is the single biggest "is it broken?" moment. It isn't. The model is loading 5 GB into RAM. Your GUI may stutter. Wait it out. After the first prompt the chat goes smoothly. We mention this in the install output, in this README, and on the post-install screen because it's the most common false-alarm bug report.

**1. CPU too old.** We tried installing on a 2007 Xeon X5365. Bun crashed with "illegal instruction" because the chip is x86-64-v1 and Bun needs v2 (SSE4.2 + POPCNT, late-2008 onward). Now the installer reads `/proc/cpuinfo` first and refuses cleanly with a message instead of bailing five steps in.

**2. Docker permission denied.** Docker installs cleanly but your user isn't in the `docker` group yet, so `docker ps` returns "permission denied". The installer adds you to the group and uses `sg docker -c` for the rest of this session, then reminds you to log out and back in.

**3. Model pull dropped halfway.** A 5 GB pull on flaky internet often drops. We retry up to 3 times with a 10s backoff, and the installer is idempotent so re-running picks up where it left off.

**4. Ollama running but unreachable.** We've seen Ollama start as a systemd unit but the API not bind to port 11434 for 4-5 seconds. The installer probes `localhost:11434/api/tags` for 10s before declaring it ready.

**5. Container can't reach Ollama.** OpenClaw runs in Docker, Ollama runs on the host. By default the container has no route to host services. The generated `openclaw.json` uses `host.docker.internal` and the container is started with `--add-host=host.docker.internal:host-gateway` so it just works.

**6. Re-running the installer doesn't work.** Most installers expect virgin systems. This one writes a progress marker at `~/.oal-quickstart-progress` and skips the steps it already finished. Safe to re-run any time.

**7. Curl-pipe install can't read prompts.** When you do `curl ... | bash`, stdin is the pipe, not your terminal, so any `read -rp` prompts get garbage. The installer detects the pipe and assumes "yes" on the safe questions.

**8. macOS Gatekeeper / Windows SmartScreen.** Unsigned installers get blocked by default on Mac and warned-against on Windows. We sign both. Apple Developer ID + Authenticode code-signing certs, on the OAL business account. If you ever see "OAL Quickstart" as the publisher, it's actually us.

**9. Bun vs npm.** Earlier installer versions installed Bun and OpenClaw on the host. The current docker-compose version skips this entirely — OpenClaw runs in its container, no host-side Bun needed. If you DO want bun on the host for other reasons, install it from [bun.sh/install](https://bun.sh/install). We deliberately avoid npm and pnpm because of [supply-chain attack history](docs/why-bun.md).

**10. The "trust this folder" prompt killed our droplet for 3 hours.** Not relevant to this installer (we don't use Claude Code), but if you ever set up a similar tool that does, watch for that prompt before assuming the daemon is doing nothing.

**11. Memory pressure freezes the desktop.** If your machine has just enough RAM to run the model AND your daily apps, allocating 8 GB to the Ollama container can push the rest of your apps into swap. Symptoms: GUI is sluggish forever, not just during model load. Fix: lower the memory cap in `docker-compose.yml` (`services.ollama.deploy.resources.limits.memory`) to something like `5G` or `6G`. You'll trade speed for getting your laptop back.

**12. NVIDIA GPU not visible inside the container.** Symptom: install completes, agent works, but inference is dog-slow. Cause: `nvidia-container-toolkit` isn't installed on the host, OR you didn't uncomment the GPU block in `docker-compose.yml`. Fix: install the toolkit (Nvidia's docs), then uncomment the `runtime: nvidia` section under `services.ollama` in `docker-compose.yml`, then `docker compose up -d` to recreate the container with GPU access.

**13. `docker compose` vs `docker-compose`.** Modern Docker installs ship Compose v2 as a plugin, invoked as `docker compose <cmd>`. Older systems have v1, invoked as `docker-compose <cmd>` (with a dash). The installer requires v2. If your distro only has v1, install the modern plugin: `sudo apt-get install docker-compose-plugin` (or your distro's equivalent).

## Uninstall

```bash
./installers/linux/uninstall.sh
```

Or directly:

```bash
cd /path/to/oal-quickstart
docker compose down -v        # stops everything, removes the volume
rm -rf openclaw-state          # remove your workspace (back it up first if you want)
```

The `-v` flag in `docker compose down -v` removes the `oal-ollama-models` volume (frees the 5 GB model weights). Without `-v`, the model stays on disk for next time.

The uninstall script backs up your workspace files to `~/.oal-quickstart-bak.YYYYMMDD/` before deleting. Anything you wrote in `USER.md` survives so you can restore later.

## What's next after install

Three things to do, in order:

1. **Tell your agent who you are.** Open `openclaw-state/workspace/USER.md` (relative to the repo root) and replace the placeholder with a real bio. The agent reads this file at the start of every turn. The more concrete you are, the better it'll fit you.

2. **Talk to it.**
   ```bash
   cd /path/to/oal-quickstart
   docker compose exec gateway openclaw chat --agent main
   ```

3. **Optional: hook it up to Telegram** so you can text it from your phone. See `docs/telegram-setup.md`.

## Daily-use commands

```bash
cd /path/to/oal-quickstart

# Start the agent (after a reboot, or after `docker compose down`)
docker compose up -d

# Talk to the agent
docker compose exec gateway openclaw chat --agent main

# Stop the agent (frees ~5 GB RAM, keeps the model on disk)
docker compose down

# See what's happening
docker compose logs -f gateway
docker compose logs -f ollama

# Update to the latest images
docker compose pull && docker compose up -d
```

## Trust signals

- Public repo, MIT license, every script in plain bash or TypeScript. Read before you run.
- Linux installer is unsigned but each release publishes a SHA256 in `installers/linux/checksums.txt`. We sign the checksums file with the OAL GPG key (fingerprint in `docs/security.md`).
- macOS and Windows installers are signed by "Obsidian AI Labs" (Apple Developer ID + Authenticode).
- We never collect telemetry. There is no analytics pixel. There is no phone-home. Verify by running `docker network inspect bridge` after install and confirming `oal-gateway` only talks to your own host.

## Why we built this

We were tired of paying for cloud AI subscriptions to summarize emails and rewrite captions. Once you have a passable open-source model running on your own GPU (or a patient CPU), most of the daily AI tasks anyone actually does work fine without sending your data anywhere.

The problem was always installation. Every "run an LLM locally" guide assumed you already knew Docker, Ollama, what a tokenizer is, why Bun is different from npm, what an OpenAI-compatible endpoint looks like, and so on. So we wrote this installer to reduce the path between "I want to try this" and "I'm using it" to a single script that explains itself.

## Get help

- Open an [issue](https://github.com/obsidian-ai-labs/oal-quickstart/issues) on this repo
- Email the install log (`~/.oal-quickstart-install.log`) to info@obsidianailabs.ca

## License

MIT for the installer scripts. Ollama and OpenClaw retain their own licenses (also permissive).

---

Made by [Obsidian AI Labs](https://obsidianailabs.ca). We help individuals and small teams run private AI on their own hardware.
