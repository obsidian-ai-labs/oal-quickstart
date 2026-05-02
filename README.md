# OAL Quickstart

Plug in the USB. Run the installer for your OS. You get your own private local AI agent on your machine in about 10 minutes. Nothing leaves your computer.

## What it actually does

1. Installs [Ollama](https://ollama.com) - the local LLM runtime
2. Pulls a small language model (about 5 GB)
3. Installs [OpenClaw](https://github.com/openclaw/openclaw) - the agent gateway
4. Sets up a starter agent identity in `~/.openclaw/`
5. Starts the gateway as a user-level service so it survives reboot

That's it. No telemetry. No phone-home. Your prompts and your data stay on your machine. Source for everything in this repo so you can verify.

## Hardware requirements

- 16 GB RAM minimum (32 GB if you want it fast)
- 16 GB free disk space
- An NVIDIA GPU helps but is not required
- macOS 12+, Windows 10+, or any modern Linux

If your machine doesn't meet the floor, the installer will refuse rather than give you a bad first experience.

## Install

### Linux

```bash
./installers/linux/install.sh
```

### macOS

Double-click `installers/macos/OALQuickstart.pkg` and follow the prompts.

### Windows

Double-click `installers/windows/OALQuickstart.exe` and click "Yes" when prompted.

### One-liner alternative (developers)

```bash
curl -fsSL https://install.obsidianailabs.co | bash
```

## Uninstall

```bash
./installers/linux/uninstall.sh   # or .pkg uninstaller / Add-Remove-Programs on Win
```

Removes Ollama, OpenClaw, the workspace, and any models you pulled. Your config files in `~/.openclaw/` are saved to `~/.openclaw.bak.YYYYMMDD/` in case you change your mind.

## What's next after install

- Run `openclaw chat` to talk to your agent in the terminal
- Configure a Telegram bot for phone access (instructions in `docs/telegram-setup.md`)
- Edit `~/.openclaw/workspace/IDENTITY.md` to give your agent a personality

## Trust signals

- This repo is public. Read every line of every script before running.
- Linux installer is unsigned but each script publishes a SHA256 in `installers/linux/checksums.txt`.
- macOS installer is signed by "Obsidian AI Labs" (Apple Developer ID, $99/year cert).
- Windows installer is Authenticode-signed by "Obsidian AI Labs" (code-signing cert).
- We never collect telemetry. There is no analytics pixel. There is no phone-home.

## Support

If install fails, the installer drops a log at `~/.oal-quickstart-install.log`. Email it to info@obsidianailabs.ca and we'll triage.

## License

MIT for the installer scripts. Ollama and OpenClaw retain their own licenses.

## Building this yourself

See `docs/BUILDING.md`.

---

Made by [Obsidian AI Labs](https://obsidianailabs.ca).
