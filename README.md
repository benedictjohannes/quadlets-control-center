# 🚀 Omega Control Center: Stop Memorizing Localhost Ports

Are you tired of **memorizing `localhost:3002`** for every project, or which project is running on that port?  
Do you keep **forgetting which command** starts your project - is it `npm run start`, `bun dev`, or `make dev`?

This **Omega Control Center** template provide ingredients to bootstrap your development environment into a production-grade local cloud that "just works" the moment you log in. Featuring:
- **Containerized Deployment**: Run your project using Podman Quadlets. The very same system that powers orchestrated system like production k8s.
- **Isolation**: Run your containers as rootless user for maximum security.
- **Beautiful URLs**: Map `myProject.localhost` or `personalHobby.localhost` to your containers. No more port recall, courtesy of Caddy. And oh, caddy runs containerized, too.
- **One Command to Rule Them All**: Stop juggling multiple terminals. Your projects are managed by `systemd`, meaning one command starts your entire stack (Backend + Frontend + DB).
- **Session-Integrated**: Your projects start automatically with your user session. Boot your computer, login to your user, and your dev environment is already live.
- **World accessible**: Expose your local services to the world using Cloudflare Tunnel. Showcase your dev progress in realtime without waiting 15 minutes for build pipeline to finish.
- **Utility commands**: `qctl` script to help you manage your containers. Less typing `systemctl --user` or `journalctl --user`, more time to build cool stuff.

## 🧑‍💻 The "omega" Reference User
To keep these configurations concrete and "living," this repository uses a reference user named **`omega`**. 
*   **User Home**: `/home/omega`
*   **Repo Location**: `/home/omega/ControlCentre`
*   **Project Source**: `/home/omega/Projects`

## AI Onboarding

This project includes an AI guide to safely help you personalize and implement this setup for your own system in [PersonalizeForMe.md](./PersonalizeForMe.md). You can safely `mv PersonalizeForMe.md AGENTS.md` to include this as your system prompt for implementation. 

<details>
<summary>AI Coding Assistant Instructions</summary>
If you don't find the **handshakeMarker** `InternalizedByXXXXXX` in the system prompt (that `XXXXXX` is for `Design`), you MUST read [PersonalizeForMe.md](./PersonalizeForMe.md), look for it, or ask the user before implementing any changes in helping the user implementing this project in their system.
</details>

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
ln -s /home/omega/ControlCentre/scripts/qctl.sh ~/.local/bin/qctl
```


## 🛠️ Key Management Tools

### 1. `scripts/caddy-sync-volumes.sh`
A security-focused script that ensures Caddy only has access to the specific folders it needs.
- **Precision Mounting**: Scans Caddyfiles for `/srv/...` paths and generates explicit `Volume=` entries in `caddy.container`.
- **Static/Proxy Toggling**: Recognizes commented-out `root` paths, allowing you to "toggle" between static serving and reverse proxying by just editing Caddyfiles.
- **Why?** Avoids the "Mega-Mount" security hole where Caddy can see your entire user directory.

### 2. `scripts/qctl.sh`
A PM2-inspired CLI for managing Quadlet services. It streamlines `systemctl --user` boilerplate and provides a centralized dashboard.

- **`qctl status`**: Displays a snapshot that shows CPU, Memory, Restarts, and Since (uptime). The **STARTUP** column indicates if the service is set to auto-start (via `WantedBy=`).
- **`qctl enable | disable <name> [--now]`**: Toggles persistence by commenting/uncommenting `WantedBy=` lines in the `.container` file—necessary because standard `systemctl enable` doesn't apply to Quadlets. `--now` immediately starts or stops the service alongside enabling/disabling them.
- **`qctl logs <name> [flags]`**: A smart `journalctl` wrapper that defaults to follow (`-f`) and accepts all standard journalctl arguments.
- **`qctl start | stop | restart | reload`**: Wraps `systemctl --user start | stop | restart`. `reload` runs `daemon-reload` before restarting.

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

