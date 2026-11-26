# The real opencode agent server, running on a Cloudflare Container.
#
# This is the piece a Worker cannot provide: a Linux box with processes, a
# filesystem, a PTY, git, ripgrep and Chromium.
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
      chromium \
 && rm -rf /var/lib/apt/lists/*

# opencode's browser and shell tools look for these.
ENV CHROME_PATH=/usr/bin/chromium
ENV CHROMIUM_PATH=/usr/bin/chromium
ENV OPENCODE_SERVER_PORT=4096

# The same release this fork tracks. --trust is required: the CLI's postinstall
# fetches its platform binary, and Bun blocks postinstalls by default.
RUN bun add -g --trust @opencode/cli@2.4.1

WORKDIR /workspace
EXPOSE 4096

# 0.0.0.0 matters: the Durable Object reaches the container over its private
# network, never over loopback.
CMD ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
