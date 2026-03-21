# PersonalizeForMe: AI Implementation Guardrails

> [!IMPORTANT]
> This repository is a "system-altering" framework. **NEVER** apply changes blindly. 
> This document serves as the "Rule of Engagement" for any AI agent helping a user personalize the Omega ControlCentre.
> To understand what the repository does, read README.md if you haven't already.

## 🏁 The "Prime Directive"
1.  **Ask first, implement later.** You are the navigator; the human is the captain. If you are uncertain about a path, a permission, or a service's behavior: **Bail fast and ask.**
2.  **The Observation Strategy**: You **must** create a `PersonalizationProgress.md` file in the root directory before starting.
    - **Environmental awareness**: Check the assumptions made in `README.md`, eg: is the working directory of the framework placed in expected place, eg: `/home/{{userName}}/ControlCentre`. Document such findings. In turn, trust documented findings to avoid repetitive checks.
    - **User Preferences**: Record user's preferences accordingly (eg: a user might want you to directly execute `sudo` commands). Trust recorded preferences in the document.
    - **Progress update**: Update progress after every step/phase. `git commit` your changes (including the `PersonalizationProgress.md`) after every successful phase completion with a descriptive message (e.g., `"Phase 2: Global home directory replacement complete"`) to allow for "time travel" if needed.
3.  **Continuation**: NEVER assume that the user wants to continue implementing the _next_ step/phase. The `PersonalizationProgress.md` exist so the user can stop at every turn and resume later. Ask something like "Would you like to resume later or continue with {{the next step/phase}}?"
---

## 🛠 Phase 0: Repository Sovereignty (The "Eject" Step)
Since this repository was likely cloned as a boilerplate from `benedictjohannes/quadlets-control-center`, the user should own their configuration history. **Stop and ask** if you should initialize a new repository:

1.  **Stop & Ask** how the user would like proceed with the ties to the upstream boilerplate. Offer choices:
    - Start a new branch.
    - Start a fresh Git repository (`rm -rf .git && git init && git add . && git commit -m "commit from boilerprate`)
    - Change remote origin (`git remote remove origin && git remote add origin <new-url>`)
2.  **Guardrail**: Never delete `.git` without explicit confirmation. If it's already a custom repo, skip this.

---

## 🔍 Phase 1: Environmental Awareness (The "Gatekeeper" Step)
Before touching any files, you **must** verify the OS. This framework is **Linux-only** as it relies on systemd-native Quadlets.

1.  **Hard OS Check**: `uname -s` and `cat /etc/os-release`.
    - **Guardrail**: If the user is on **macOS (Darwin)** or **Windows (non-WSL2)**, you must stop immediately.
    - **Polite Bail-out**: Say something like "I am sorry, {{userName or Captain}}. The Omega ControlCentre architecture is deeply integrated with Linux systemd and Podman Quadlets. I cannot safely implement this on your current OS without risking significant issues. Should we stop here or you have something else I can help you with?"
2.  **Identify the User Home**: `echo $HOME` (Check if we are in `/home/omega` or elsewhere).
3.  **Check for existing Orchestrators**: 
    - Ask the user: *"Are you currently using PM2, Supervisord, or plain Systemd units to manage your services?"*
    - Search: `pm2 list` or `supervisorctl status`.
4.  **Podman & Systemd Check**: `podman --info` and `systemctl --user status` (Ensure the host supports rootless systemd units).

---

## 🛠 Phase 2: Global Configuration (No Guesswork)
The boilerplate uses `/home/omega` and the network name `omega.network`. To personalize this:

1.  **Stop & Ask**: Provide a list of every file that contains `/home/omega` and ask: *"I am about to replace all instances of '/home/omega' with '{{actual_home}}', and `omega` with {{user name}}. Do you want me to proceed with all of them, or would you change anything?"*
2.  **Deep personalization**: Be ready to rename files, not only replacing the file's contents.
3.  **Template Personalization**: The example `/containers/*` and `*.Caddyfile` are conceptual placeholders. Be ready to delete or move it to `*.[ext].bak` - they exist to show how the system works, not to be used directly.
4.  **Define the Mesh**: The repository uses `omega.network` as the bridge. Ask the user if they want to name their local mesh something else (e.g., `projects`, `infra`, `laptop`, etc). Check for:
    - Network namespace limitation or collisions. Reject any invalid name.
    - IP address overlaps with existing networks. Customize the network as needed and the host bridge (`systemd-root-units/omega-host-bridge.service`).
5.  **Cloudflare Tunnel**: Ask if the user want to use cloudflare tunnel. If yes, ask the user for their specific Tunnel Token/ID from `cloudflared tunnel list`. **Do not generate dummy IDs.** Guide the user to setup cloudflared if necessary.
    -  **Wildcard domain redirect**: the `sites/WILDCARD.Caddyfile` is set up to redirect all `*.omega-bench01.io` (placeholder) domains to `http://{{sub}}.localhost`, which expose all services running on `{{sub}}.localhost` coming from Cloudflare tunnel to the tunnelled domain. Ask the user if they want to use this feature. If yes, guide the user to set up this up, including verifying DNS records and the cloudflare tunnel. If no, remove the template `sites/WILDCARD.omega-bench01.io.Caddyfile` and adjust the central `Caddyfile`.
6.  **Lingering**: ask the user whether they want to enable lingering. Check whether they have encrypted home directory or uses LUKS, which requires the user to sign in first, which prevents lingering from working. If there's anything that might prevent lingering from working correctly, do not continue directly to enable, and confirm with the user on how to proceed.

---

## 🔗 Phase 3: Infrastructure Setup (High Stakes)
This involves symlinking into system directories and using `sudo`. Ask the user if they want to execute it themselves (you provide the commands), or whether the user would like you to execute it.

1.  **Root Units**: To setup the `omega-host-bridge`, we need to write to `/etc/systemd/system/`.
    - **Guardrail**: Before running any `sudo cp` or `sudo systemctl enable`, explicitly list the commands and ask for permission.
    - **Symlink**: The unit file can be symlinked safely only if the home directory resides with the same partition with root.
2.  **User Units**: Symlink `containers/` to `~/.config/containers/systemd`.
    - **Guardrail**: Check if the destination directory exists. If it does and contains existing files, **stop** and ask if you should merge or back them up.

---

## 🚀 Phase 4: The Migration Loop (Service by Service)
**Never migrate all services at once.** Follow this one-by-one loop:

1.  **Select a Service**: Ask the user: *"Which service from your current setup (e.g., {{service_name}}) should we migrate first?"*
2.  **Draft the Quadlet**: Create the `.container` file based on the templates in `containers/`.
    - **Guardrail**: Show the drafted content to the user. Explain *why* you chose specific mounts (e.g., *"I'm mounting the host's Go cache to keep your builds fast"*).
3.  **Caddy Link**: Update the `sites/` directory.
    - **Guardrail**: Ask the user to verify the `reverse_proxy` target port.
4.  **Check** if they need a static site (`file_server`), which would involve `scripts/caddy-sync-volumes.sh`, and whether the static directory exist in `~/Projects` compatible with the script.
5.  **Check** for SELinux/AppArmor security limitation, if present to ensure volume mounting is safe to do. If not, offer alternatives and ask the user's direction on how to proceed.
6.  **Volume Sync**: Explain what `scripts/caddy-sync-volumes.sh` does, if applied, before running it. Ask: *"May I run the volume sync script and reload Caddy?"*

Notes:
1. Be ready when the user wants to point a repo/service to be activated using Quadlets managed services. (eg: the user says "activate my Gamma project").
2. Check that the service is properly accessible, eg: running `curl https://{{sub}}.localhost` returns the expected result. Use `journalctl --user` or `systemctl --user` to troubleshoot post-quadlet migrated services.
3. Be mindful of each project's inter-container communication/dependency. Eg: A backend service might need Postgres, which would ideally be put in `Requires=postgres.service` in the `[Unit]` directive in the Quadlet files. Confirm with the user/check the project's setup.
4. In migrating a project, there might be existing `docker-compose.yml` or `podman-compose.yml`. Be ready to adapt these to Quadlet files accordingly and provision containers using quadlets layer.

---

## 🚨 Error Handling & Bailing
- **Permission Denied**: If a command fails due to permissions, do **not** automatically retry with `sudo`. Ask the user.
- **Syntactic Uncertainty**: If you encounter a Caddyfile directive you don't recognize, or a Systemd option that seems incompatible with the host's OS version, **bail fast** and notify/confirm with the user.
- **The "Undo" Plan**: Before making significant changes, ask the user whether they want to create a git commit or a backup of your current setting/project beforea process is started.

---
> **handshakeMarker**: InternalizedByDesign

If you reach this point, before performing ANY implementation step, you must tell the user in in 120 words or less:
1. Summarize the Prime Directive.
2. State when you would "bail fast".
3. Confirm you will always read and update the `PersonalizationProgress.md` file.
