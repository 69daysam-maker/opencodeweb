# Run it free, in the browser (Chromebook-friendly)

No Linux install, no paid plan, no credit card. GitHub Codespaces gives every
personal account **120 core-hours a month** — that is **60 hours** on a 2-core
machine — plus 15 GB of storage.

## Steps

1. Open the repo on github.com.
2. **Code ▾ → Codespaces → Create codespace on `dev`.**
   First boot takes a couple of minutes; `bun install` runs automatically.
3. The terminal starts the server for you on port **4096**, and the port is
   forwarded and public, so a browser tab opens on the app.
4. Add a model key — with no key the site loads but cannot answer. A free
   OpenRouter account works, and models with the `:free` suffix cost nothing.
   Put the key in the codespace terminal, never in the repo:
   ```bash
   export OPENROUTER_API_KEY=...
   ```
   then restart the server:
   ```bash
   pkill -f "opencode serve"
   OPENROUTER_API_KEY=$OPENROUTER_API_KEY OPENCODE_SERVER_PORT=4096 \
     bunx @opencode/cli@2.4.1 serve --hostname 0.0.0.0 --port 4096
   ```

## What this actually is

- A real Linux box, in a browser tab, running the real agent: chat, file tools,
  `bash`, git, ripgrep, the terminal panel, dev-server previews.
- The forwarded URL only lives while the codespace is running. It stops after
  30 minutes idle (that is what protects the free hours), and you start it
  again from github.com/codespaces.

## Limits worth knowing

- 60 hours a month on 2 cores. Running it all day every day will exhaust that.
- Codespaces is your own machine, not a permanent public website. A URL that is
  always up, with a shell behind it, is not free anywhere — the CPU is the cost.
- The **sidebar browser** still needs the missing CDP bridge (`experimental.browser`
  is implemented by the Electron desktop, not by the server). Chromium can be
  installed in the codespace, but nothing speaks that protocol to it yet.
