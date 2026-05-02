# Why Bun, not npm

Short version: npm and pnpm have an active history of supply-chain compromises. We don't want any of our installer scripts running malicious code that snuck into a transitive dependency overnight.

We use Bun for everything that needs JavaScript:
- Bun's lockfile is binary and content-addressed (harder to tamper with)
- Bun does NOT run package postinstall scripts by default (this alone blocks most npm-side attacks)
- Bun's install path is faster and produces fewer files
- One binary, no Node version manager required

If you've never used Bun, the only thing that changes from your perspective is `npm install` becomes `bun install` and `npm run X` becomes `bun run X`. Same `package.json`. Bun reads it natively.

For more on why this matters:
- [npm Shai-Hulud worm (Sep 2025)](https://socket.dev/blog/) - self-replicating malware in 100+ packages
- [chalk + debug compromise (Sep 2025)](https://socket.dev/blog/)
- [colors.js sabotage (Jan 2023)](https://snyk.io/blog/why-colors-and-faker-were-deliberately-sabotaged/) - maintainer pushed an infinite loop into versions used by 22M+ projects/week
- [ua-parser-js compromise (Oct 2024)](https://snyk.io/blog/) - cryptominer in 8M-downloads-per-week package

Some of these get caught in 24 hours. Some don't. The defense isn't auditing every dependency manually; it's running an installer that doesn't auto-execute scripts when you `install`.
