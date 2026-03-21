# Omega ControlCentre: Rootless Caddy & Quadlet Stack

This repository is a generalized reference for a high-performance, security-focused container orchestration setup using **Podman Quadlets** and **Caddy**.

## 🏗️ The Architecture Philosophy

The setup is built on the **"ControlCentre vs. Projects"** separation:
*   **Projects (`/home/omega/Projects`)**: Where your source code lives. Each project (e.g., Alpha, Beta) is independent.
*   **ControlCentre (`/home/omega/ControlCentre`)**: This repository. It contains all the infrastructure, orchestration manifests, and management scripts.

This separation ensures that your application code stays clean of deployment-specific "glue" while giving you a single, version-controlled repository for your entire server's infrastructure.

## 📂 Directory Structure

*   `Caddyfile`: Main entry point (imports `sites/*.Caddyfile`).
*   `sites/`: Per-site Caddy configurations.
*   `containers/`: Quadlet `.container` and `.network` files.
*   `scripts/`: Automation for volume syncing and status monitoring.
*   `cloudflared/`: Cloudflare Tunnel configuration.

## 🧑‍💻 The "Omega" Reference User
To keep these configurations concrete and "living," this repository uses a reference user named **`omega`**. 
*   **User Home**: `/home/omega`
*   **Repo Location**: `/home/omega/ControlCentre`
*   **Project Source**: `/home/omega/Projects`

> [!TIP]
> **AI Onboarding**: If you are an AI Coding Assistant helping a user implement this setup, please refer to [PersonalizeForMe.md](./PersonalizeForMe.md) for explicit guardrails and the step-by-step personalization workflow.

## 🔗 Integration with systemd

To integrate this "ControlCentre" into your Linux system while keeping everything in this repository, use symlinks. This setup distinguishes between **root units** (for system-wide networking) and **user units** (for your applications).

```bash
# 1. Symlink Quadlets and User Units to systemd user path
ln -s /home/omega/ControlCentre/containers ~/.config/containers/systemd
ln -s /home/omega/ControlCentre/systemd-user-units/* ~/.config/systemd/user/
systemctl --user daemon-reload

# 2. Copy Root Units (requires sudo)
# Symlink is safe only if the homedir resides in the same partition
sudo cp /home/omega/ControlCentre/systemd-root-units/* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now omega-host-bridge.service

# 3. Symlink Cloudflare config for user ran cloudflared
ln -s /home/omega/ControlCentre/cloudflared /home/omega/.cloudflared

# 4. Symlink management scripts to local bin (optional)
ln -s /home/omega/ControlCentre/scripts/quadlets-status.sh ~/.local/bin/quadlets-status
```


## 🛠️ Key Management Tools

### 1. `scripts/caddy-sync-volumes.sh`
A security-focused script that ensures Caddy only has access to the specific folders it needs.
- **Precision Mounting**: Scans Caddyfiles for `/srv/...` paths and generates explicit `Volume=` entries in `caddy.container`.
- **Static/Proxy Toggling**: Recognizes commented-out `root` paths, allowing you to "toggle" between static serving and reverse proxying by just editing Caddyfiles.
- **Why?** Avoids the "Mega-Mount" security hole where Caddy can see your entire user directory.

### 2. `scripts/quadlets-status.sh`
Provides a PM2-style dashboard for your systemd-managed containers.
- **View**: CPU%, Memory, Restarts, and Uptime at a glance.

### 3. `scripts/caddy-https-warmup.sh`
Warms up TLS certificates for all configured sites to ensure zero-latency first visits.

## 🚀 "Hub and Spoke" Project Pattern

We manage multi-container projects (e.g., a Backend + Frontend) using native systemd dependencies:
*   **The Anchor (Backend)**: Defines `WantedBy=default.target`.
*   **The Spoke (Frontend)**: Defines `PartOf=project-be.service` and `After=project-be.service`.

This allows you to start/stop the entire project stack with a single `start` or `stop` command on the anchor service.

## 📦 Dependency Strategy (Extreme Build Parity)

*   **SDK & Cache Mounting (Uses Go installed on host)**: To achieve near-instant builds and zero re-downloads, we mount the host's Go toolchain directly into the container:
    - Mount **Module Cache** (`GOPATH/pkg/mod`) and **Build Cache** (`GOCACHE`).
    - Mount **GOROOT** (the Go compiler itself) from the host.
    - Set `PATH` and `Environment` to map to these folders.
    - **Result**: You can use tools like `gow` (installed on the host) to trigger hot-reloads inside the container with 0ms configuration overhead.
*   **Bun / Node 24**: Our examples use `node:24-slim` and `oven/bun:latest` to demonstrate support for modern runtimes.

## 🔑 Permissions (Rootless Binding)

To allow Caddy to bind to ports 80 and 443 without root:
```bash
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee /etc/sysctl.d/99-rootless-caddy.conf
sudo sysctl --system
```

## ☁️ Bonus: Exposing *.localhost to the world using Cloudflare Tunnel

The `cloudflared/config.yml` is configured to map `*.omega-bench01.io` to your local Caddy instance. The `sites/WILDCARD.omega-bench01.io.Caddyfile` handles the internal routing, allowing you to expose any local service by simply adding a subdomain to your Caddyfile.

## 🤖 AI Assisted Implementation

This repo includes AI guide to safely help you personalize and implement this for your own setup in [PersonalizeForMe.md](./PersonalizeForMe.md). You can safely include this as your system prompt for implementation. 

> Pro tip: `mv PersonalizeForMe.md AGENTS.md`
