#!/usr/bin/env bash
# OpenCode Web — one-shot installer for an Oracle Cloud Always Free Ubuntu VM.
#
# The whole site runs from this one box: the real opencode agent server, its
# web UI and its login screen. No Vercel, Codespaces, Render or paid service is
# involved — the server serves the app itself (verified: GET / is the OpenCode
# HTML app, /api returns 401 until the password is entered).
#
# Quick start, pasted into the OCI console "Initialization script" box:
#
#   #!/bin/bash
#   export OPENCODE_PASSWORD='pick-a-long-password'
#   curl -fsSL https://raw.githubusercontent.com/69daysam-maker/opencodeweb/dev/deploy/oracle/setup.sh | bash
#
# Or over SSH:  sudo OPENCODE_PASSWORD='...' bash setup.sh
#
# Re-running is safe: packages and the CLI are skipped when present, an existing
# password is kept, and the service is restarted.
set -euo pipefail

OPENCODE_VERSION="${OPENCODE_VERSION:-2.4.1}"
APP_PORT="${APP_PORT:-4096}"
BUN_INSTALL="${BUN_INSTALL:-/root/.bun}"
ENV_FILE="/etc/opencode-web.env"
LOG_FILE="/var/log/opencode-web-setup.log"

export BUN_INSTALL
export HOME="${HOME:-/root}"
export DEBIAN_FRONTEND=noninteractive

mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===== OpenCode Web installer — $(date -u '+%Y-%m-%dT%H:%M:%SZ') ====="
echo "arch: $(uname -m)   ram: $(awk '/^MemTotal:/ {printf "%d MB", $2/1024}' /proc/meminfo)"

# --- 1. system packages -----------------------------------------------------
# git, ripgrep and python3 are used by the agent's own tools.
echo "==> [1/7] system packages"
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates curl unzip git ripgrep python3 jq gnupg \
  debian-keyring debian-archive-keyring apt-transport-https \
  iptables-persistent

# --- 2. swap on the 1 GB shapes --------------------------------------------
echo "==> [2/7] swap (only when RAM is small)"
mem_mb="$(awk '/^MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo)"
if [ "$mem_mb" -lt 3000 ] && [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# --- 3. bun + the real opencode CLI ----------------------------------------
# @opencode/cli picks its platform binary (linux-x64 / linux-arm64) by itself,
# so this works on both the Ampere A1 and the AMD micro Always Free shapes.
echo "==> [3/7] bun + @opencode/cli@${OPENCODE_VERSION}"
if [ ! -x "$BUN_INSTALL/bin/bun" ]; then
  curl -fsSL https://bun.sh/install | BUN_INSTALL="$BUN_INSTALL" bash
fi
export PATH="$BUN_INSTALL/bin:$PATH"
bun --version
# --trust is required: the CLI's postinstall fetches its platform binary and Bun
# blocks postinstalls by default.
bun add -g --trust "@opencode/cli@${OPENCODE_VERSION}"
if [ ! -x "$BUN_INSTALL/bin/opencode" ]; then
  echo "!! opencode binary is missing after install" >&2
  exit 1
fi

# --- 4. access password ----------------------------------------------------
# `opencode serve` serves the web UI and answers 401 to every API call until the
# password is entered on the login screen.
echo "==> [4/7] access password"
if [ -n "${OPENCODE_PASSWORD:-}" ]; then
  PASSWORD="$OPENCODE_PASSWORD"
elif [ -s "$ENV_FILE" ] && grep -q '^OPENCODE_PASSWORD=' "$ENV_FILE"; then
  PASSWORD="$(sed -n 's/^OPENCODE_PASSWORD=//p' "$ENV_FILE" | head -n1)"
else
  PASSWORD="$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c1-20)"
fi

umask 077
{
  printf 'OPENCODE_PASSWORD=%s\n' "$PASSWORD"
  if [ -n "${OPENROUTER_API_KEY:-}" ]; then
    printf 'OPENROUTER_API_KEY=%s\n' "$OPENROUTER_API_KEY"
  fi
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    printf 'ANTHROPIC_API_KEY=%s\n' "$ANTHROPIC_API_KEY"
  fi
} > "$ENV_FILE"
chmod 600 "$ENV_FILE"

# --- 5. systemd service ----------------------------------------------------
echo "==> [5/7] systemd service (starts on boot, restarts on crash)"
mkdir -p /workspace
cat > /etc/systemd/system/opencode-web.service <<UNIT
[Unit]
Description=OpenCode Web - agent server and web UI
Documentation=https://github.com/69daysam-maker/opencodeweb
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=HOME=/root
Environment=BUN_INSTALL=$BUN_INSTALL
Environment=PATH=$BUN_INSTALL/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EnvironmentFile=$ENV_FILE
WorkingDirectory=/workspace
ExecStart=$BUN_INSTALL/bin/opencode serve --hostname 0.0.0.0 --port $APP_PORT
Restart=always
RestartSec=3
KillMode=mixed
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable opencode-web.service >/dev/null 2>&1 || true
systemctl restart opencode-web.service

# --- 6. instance firewall --------------------------------------------------
# OCI's Ubuntu images ship with iptables allowing only 22. The VCN security list
# is a second, separate gate — it has to be opened in the console.
echo "==> [6/7] instance firewall (80, 443, ${APP_PORT})"
for port in 80 443 "$APP_PORT"; do
  if ! iptables -C INPUT -p tcp -m state --state NEW --dport "$port" -j ACCEPT 2>/dev/null; then
    iptables -I INPUT 6 -p tcp -m state --state NEW --dport "$port" -j ACCEPT
  fi
done
netfilter-persistent save >/dev/null 2>&1 || true

# --- 7. HTTPS in front -----------------------------------------------------
# sslip.io is free wildcard DNS: <ip>.sslip.io resolves to <ip>, so Let's
# Encrypt can issue a real certificate for the instance's IP with no domain
# purchase and no DNS setup.
echo "==> [7/7] HTTPS in front (Caddy + sslip.io)"
if ! command -v caddy >/dev/null 2>&1; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update -y
  apt-get install -y caddy
fi

PUBLIC_IP="$(curl -s --max-time 5 -H 'Authorization: Bearer Oracle' \
  http://169.254.169.254/opc/v2/vnics/ 2>/dev/null \
  | grep -o '"publicIp":"[0-9.]*"' | head -n1 | cut -d'"' -f4 || true)"
if [ -z "${PUBLIC_IP:-}" ]; then
  PUBLIC_IP="$(curl -s --max-time 10 https://ifconfig.me || true)"
fi

URL="http://<this-instance-public-ip>:${APP_PORT}"
if [ -n "${PUBLIC_IP:-}" ]; then
  cat > /etc/caddy/Caddyfile <<CADDY
https://${PUBLIC_IP}.sslip.io {
	encode zstd gzip
	reverse_proxy 127.0.0.1:${APP_PORT} {
		flush_interval -1
	}
}
CADDY
  systemctl enable caddy >/dev/null 2>&1 || true
  systemctl restart caddy
  URL="https://${PUBLIC_IP}.sslip.io"
fi

echo "==> waiting for the app on 127.0.0.1:${APP_PORT}"
ready=""
for _ in $(seq 1 45); do
  if [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${APP_PORT}/" || true)" = "200" ]; then
    ready=1
    break
  fi
  sleep 2
done

echo
echo "======================================================================"
if [ -n "$ready" ]; then
  echo " OpenCode Web is up."
else
  echo " OpenCode Web did not answer yet. Check:"
  echo "   journalctl -u opencode-web -n 80 --no-pager"
fi
echo
echo "   Site:     $URL"
echo "   Password: $PASSWORD"
echo
echo " Still not loading from a browser? Add ingress rules for TCP 80, 443 and"
echo " ${APP_PORT} to the VCN Default Security List (console side, not this box)."
echo "======================================================================"
