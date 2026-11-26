# Run it free, in the browser (Chromebook-friendly)

No Linux install, no paid plan, no credit card. GitHub Codespaces gives every
personal account **120 core-hours a month** — **60 hours** on a 2-core machine —
plus 15 GB of storage.

## Steps

1. Open the repo on github.com.
2. **Code ▾ → Codespaces → Create codespace on `dev`.**
   The first boot installs Bun deps and the opencode CLI.
3. The server starts on port **4096**; the port is forwarded and public, so a
   tab opens on the app.
4. If it asks for a password, it is in `~/.opencode-password` (and printed in
   `/tmp/opencode.log`):
   ```bash
   cat ~/.opencode-password
   ```
5. Add a model key — without one the UI loads but cannot answer. A free
   OpenRouter account works, and models with the `:free` suffix cost nothing.
   ```bash
   pkill -f "opencode serve"
   OPENCODE_PASSWORD=$(cat ~/.opencode-password) OPENROUTER_API_KEY=... \
     opencode serve --hostname 0.0.0.0 --port 4096
   ```

## Why `--trust` is there

`bun add -g @opencode/cli` without `--trust` installs a CLI that fails on every
command with *"postinstall script was not run"*, because Bun blocks postinstall
scripts by default and the CLI downloads its platform binary in one. Remember
this if you install it by hand.

## What this actually is

- A real Linux box in a browser tab running the real agent: chat, file tools,
  `bash`, git, ripgrep, the terminal panel, dev-server previews.
- The forwarded URL lives only while the codespace runs. It stops after 30
  minutes idle — that is what protects the free hours — and you start it again
  from github.com/codespaces.

## Limits worth knowing

- 60 hours a month on 2 cores.
- Codespaces is your own machine, not a permanent public website. A URL that is
  always up, with a shell behind it, is not free anywhere: the CPU is the cost.
- The port is **public**, and that password is the only thing in front of a
  real shell. Keep it to yourself, or set the port back to private in the Ports
  panel and open it from inside the codespace.
- The **sidebar browser** still needs the missing CDP bridge
  (`experimental.browser` is implemented by the Electron desktop, not by the
  server). Chromium can be installed here, but nothing speaks that protocol yet.
