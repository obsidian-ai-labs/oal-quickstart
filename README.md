# OAL Quickstart

A private AI agent that lives entirely on your computer. Plug in the USB (or run one curl command), wait ten minutes, and you have a real local-first AI assistant. Your prompts never leave your machine. We never see your data.

## What this is for

You want to try running a private AI on your own hardware, but the path between "interested" and "running" is paved with broken installers, mismatched dependencies, weird Docker permission errors, GPU drivers that don't load, and config files written for a developer audience. We hit every one of those installing this stuff for ourselves over the past few months. This installer turns each of those moments into a one-line check that tells you what's wrong and how to fix it.

If you can run a script, you can run this.

## What you'll have when it finishes

- [Ollama](https://ollama.com) on your machine, with a small open-source language model pulled and ready
- [OpenClaw](https://github.com/openclaw/openclaw) running in a Docker container as your agent gateway
- A starter agent identity at `~/.openclaw/workspace/` that you edit to give your agent a personality
- A `docker exec` one-liner that drops you into a chat with your agent

That's it. No cloud accounts. No telemetry. No phone-home. The source for every line is in this repo so you can verify.

## Hardware floor (the installer checks this for you)

- 8 GB RAM minimum, 16+ GB strongly recommended (the install warns at 8, refuses at less)
- 16 GB free disk space (the model itself is ~5 GB, plus Ollama, OpenClaw, Docker, and headroom)
- An x86-64-v2 CPU (Intel Nehalem 2008+ / AMD Bulldozer 2011+). The installer refuses on older silicon because Bun and modern Node won't run there. We learned this the hard way trying to install on a 2007 Xeon.
- A GPU is not required, but without one the agent runs at roughly one word per second. Fine for trying it out, painful for daily use.

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

**1. CPU too old.** We tried installing on a 2007 Xeon X5365. Bun crashed with "illegal instruction" because the chip is x86-64-v1 and Bun needs v2 (SSE4.2 + POPCNT, late-2008 onward). Now the installer reads `/proc/cpuinfo` first and refuses cleanly with a message instead of bailing five steps in.

**2. Docker permission denied.** Docker installs cleanly but your user isn't in the `docker` group yet, so `docker ps` returns "permission denied". The installer adds you to the group and uses `sg docker -c` for the rest of this session, then reminds you to log out and back in.

**3. Model pull dropped halfway.** A 5 GB pull on flaky internet often drops. We retry up to 3 times with a 10s backoff, and the installer is idempotent so re-running picks up where it left off.

**4. Ollama running but unreachable.** We've seen Ollama start as a systemd unit but the API not bind to port 11434 for 4-5 seconds. The installer probes `localhost:11434/api/tags` for 10s before declaring it ready.

**5. Container can't reach Ollama.** OpenClaw runs in Docker, Ollama runs on the host. By default the container has no route to host services. The generated `openclaw.json` uses `host.docker.internal` and the container is started with `--add-host=host.docker.internal:host-gateway` so it just works.

**6. Re-running the installer doesn't work.** Most installers expect virgin systems. This one writes a progress marker at `~/.oal-quickstart-progress` and skips the steps it already finished. Safe to re-run any time.

**7. Curl-pipe install can't read prompts.** When you do `curl ... | bash`, stdin is the pipe, not your terminal, so any `read -rp` prompts get garbage. The installer detects the pipe and assumes "yes" on the safe questions.

**8. macOS Gatekeeper / Windows SmartScreen.** Unsigned installers get blocked by default on Mac and warned-against on Windows. We sign both. Apple Developer ID + Authenticode code-signing certs, on the OAL business account. If you ever see "OAL Quickstart" as the publisher, it's actually us.

**9. Bun vs npm.** We don't use npm or pnpm anywhere. Reasons in `docs/why-bun.md`. The installer pulls Bun via `curl ... | bash` from bun.sh and adds it to your shell PATH for future sessions.

**10. The "trust this folder" prompt killed our droplet for 3 hours.** Not relevant to this installer (we don't use Claude Code), but if you ever set up a similar tool that does, watch for that prompt before assuming the daemon is doing nothing.

## Uninstall

```bash
./installers/linux/uninstall.sh
```

Removes the OpenClaw container, your workspace files (after backing them up to `~/.openclaw.bak.YYYYMMDD/`), and optionally Ollama and the downloaded models. Anything you wrote in `USER.md` survives in the backup so you can restore it.

## What's next after install

Three things to do, in order:

1. **Tell your agent who you are.** Open `~/.openclaw/workspace/USER.md` and replace the placeholder with a real bio. The agent reads this file at the start of every turn. The more concrete you are, the better it'll fit you.

2. **Talk to it.**
   ```bash
   docker exec -it oal-gateway openclaw chat --agent main
   ```

3. **Optional: hook it up to Telegram** so you can text it from your phone. See `docs/telegram-setup.md`.

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
