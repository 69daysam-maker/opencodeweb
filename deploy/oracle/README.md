# Deploying the real OpenCode web app on Oracle Cloud Always Free

Oracle's Always Free tier is the no-card-free option that gives a persistent Linux
VM with a public IP, so the real agent server (`opencode serve`, PTY and all) can
run 24/7 for $0. That server serves the web UI itself — login screen, chat,
files, terminals — so nothing else has to be deployed. (Verified locally: `GET /`
returns the OpenCode app HTML and `/api` answers `401` until the password is
entered.)

**What you get:** `https://<your-public-ip>.sslip.io` running the actual
`@opencode/cli@2.4.1` server — password protected, HTTPS, restarts on crash,
starts on boot. 4 CPUs / 24 GB RAM on the Ampere shape.

## 1. Create the VM (~5 minutes, console only — no terminal needed)

1. Sign in at <https://cloud.oracle.com>. A card is used for identity
   verification; Always Free resources never charge it.
2. **Compute → Instances → Create instance**
3. Name: `opencode`
4. **Image and shape**: *Canonical Ubuntu 24.04*, shape
   **Ampere → VM.Standard.A1.Flex**, 4 OCPUs / 24 GB memory (all Always Free).
   If OCI reports *out of capacity*, create a `VM.Standard.E2.1.Micro` instead
   (also Always Free) — the installer adds swap for it.
5. **Primary VNIC**: *Assign a public IPv4 address* = **Yes**.
6. **SSH keys**: *Generate a key pair for me* and download it. Only needed for
   troubleshooting; the install itself needs no SSH.
7. **Show advanced options → Management → Initialization script**, paste:

   ```bash
   #!/bin/bash
   export OPENCODE_PASSWORD='PUT-YOUR-OWN-PASSWORD-HERE'
   curl -fsSL https://raw.githubusercontent.com/69daysam-maker/opencodeweb/dev/deploy/oracle/setup.sh | bash
   ```

   Optional: add `export OPENROUTER_API_KEY='sk-or-...'` on its own line to keep
   the key on the server instead of adding it in the app's settings.

8. **Create**. The instance boots in ~1 minute; the install finishes ~5–10
   minutes later.

## 2. Open the ports in the VCN

The instance's own firewall is handled by the installer. The VCN security list
is a second gate and has to be opened in the console.

**Networking → Virtual Cloud Networks → (your VCN) → Security Lists → Default
Security List → Add Ingress Rules**, one per row:

| Stateless | Source      | IP Protocol | Destination Port Range |
|-----------|-------------|-------------|------------------------|
| No        | `0.0.0.0/0` | TCP         | `80`                   |
| No        | `0.0.0.0/0` | TCP         | `443`                  |
| No        | `0.0.0.0/0` | TCP         | `4096`                 |

Port 4096 is only a plain-HTTP fallback.

## 3. Open the site

Copy the instance's **Public IP address** from its page and open:

```
https://<public-ip>.sslip.io
```

`sslip.io` is free wildcard DNS, so that name resolves to your IP and Caddy
obtains a real Let's Encrypt certificate for it — no domain to buy, no DNS to
configure. The first screen is the login screen; enter the password from step 7.

## Managing it

One systemd service does everything:

```bash
systemctl status opencode-web     # is it running
journalctl -u opencode-web -f     # live logs
systemctl restart opencode-web    # restart
```

Provider keys live in `/etc/opencode-web.env` (mode 600). Add one and restart, or
connect the provider in the app's settings. Sessions and provider auth live in
`/root/.local/share/opencode`.

Re-running the installer upgrades in place and keeps the password:

```bash
curl -fsSL https://raw.githubusercontent.com/69daysam-maker/opencodeweb/dev/deploy/oracle/setup.sh | sudo bash
```

## Notes

- Oracle may reclaim an Always Free instance that stays idle for 7 days (under
  10% CPU, network and memory). Ordinary chatting is activity; if it is ever
  reclaimed, the same script rebuilds it in minutes.
- Always Free compute: either 4 OCPUs / 24 GB of Ampere A1 in total, or two
  `E2.1.Micro` instances. This uses one instance.
