# The real opencode agent server: a Linux box with processes, a filesystem,
# a PTY, git and ripgrep. Runtimes without those (Workers, Vercel functions)
# can never host this.
FROM oven/bun:1.4.4-debian

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git \
      ripgrep \
      curl \
      ca-certificates \
      python3 \
      make \
      g++ \
 && rm -rf /var/lib/apt/lists/*

ENV OPENCODE_SERVER_PORT=4096

# The same release this fork tracks. --trust is required: the CLI's postinstall
# fetches its platform binary, and Bun blocks postinstalls by default.
RUN bun add -g --trust @opencode/cli@2.4.1

WORKDIR /workspace
EXPOSE 4096

# Render (and most PaaS) inject PORT and route to it; local/Cloudflare runs
# use 4096. 0.0.0.0 matters either way: nothing should be loopback-only.
CMD ["sh", "-c", "opencode serve --hostname 0.0.0.0 --port ${PORT:-4096}"]
