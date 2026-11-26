# opencodeweb on Cloudflare Containers

This is the half a Worker cannot do. The Worker serves the real `packages/app`
build and proxies every API and WebSocket call into a Linux container running
the real opencode server — one origin, no CORS, no mixed content.

```
browser ──► Worker (assets + /api proxy)
                │
                ▼
          Durable Object  ──►  Container (bun, git, ripgrep, Chromium)
                                 opencode serve :4096
```

## What you need

- A Cloudflare account on **Workers Paid** ($5/mo). Containers have no free tier.
- An OpenRouter key (yours; it is only ever stored as a Worker secret).

## Deploy

```bash
# 1. dependencies for this service
cd services/cloud
bun install

# 2. build the real UI at the root path
bun run --cwd ../../packages/app build

# 3. authenticate (opens a browser)
bunx wrangler login

# 4. the model key — paste it here, never into a file or a commit
bunx wrangler secret put OPENROUTER_API_KEY

# 5. ship it
bunx wrangler deploy
```

The first request after a deploy or an idle stop boots the VM, so it can take
30–90 seconds. Every request after that is normal speed.

## Before you share the URL

`wrangler deploy` gives anyone with the URL a shell in the container. For
personal use, put **Cloudflare Access** (Zero Trust → Access → Applications)
in front of the Worker route and leave it to your email. Per-user isolation
means one Durable Object per user, which is a one-line change in
`src/index.ts` (`idFromName(userId)`) once requests carry an identity.

## What works after this deploy

- chat, streaming, sessions
- the file tools, `bash`, `git`, ripgrep, LSPs
- the terminal panel (PTY inside the VM)
- dev-server previews from inside the container

## What does not work yet

The **sidebar browser**. The agent's browser tools are defined in
`packages/plugin-browser`, but the side that executes them is the Electron
desktop app. A container has Chromium installed (`CHROME_PATH`), not a bridge
that speaks `experimental.browser` RPC. That bridge — attach, command, result,
plus screencast frames for the panel — is the next piece of work.

## Cost

`standard-2` (1 vCPU / 6 GiB) is roughly **$0.13/hour while awake**, billed per
10 ms; idle time after the 10-minute timeout is free. For personal use that is
a few dollars a month plus OpenRouter usage. Raise `max_instances` and move to
one Durable Object per user before letting strangers in.
