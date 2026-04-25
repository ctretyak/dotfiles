# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Chezmoi dotfiles repository. Manages configs across macOS, Linux (Arch, Debian/Ubuntu/Pop!_OS, Fedora, Fedora Kinoite, Aurora), and Windows. Package installation is delegated to Ansible, triggered automatically by chezmoi.

## Key commands

```sh
chezmoi apply                    # Apply all dotfiles + trigger ansible
chezmoi diff                     # Preview what would change
chezmoi execute-template < file  # Test template rendering
chezmoi data                     # Show template variables (hosttype, os.idLike, etc.)
```

## Architecture

### Execution flow

```
chezmoi init --apply
  → .chezmoiscripts/**/run_onchange_before_*   # Bootstrap: install ansible per distro
  → chezmoi apply                               # Lay down dotfiles from templates
  → .chezmoiscripts/run_onchange_after_exec-ansible-playbook.sh.tmpl
      → ansible-playbook ~/.ansible/playbook.yml
```

The ansible trigger script hashes all `dot_ansible/` content — any change re-runs the playbook.

### Ansible task organization

`dot_ansible/tasks/` has one directory per OS/distro. Each has `_main.yml.tmpl` that imports individual task files (one file per app/tool):

- `linux/` — common Linux tasks (git, zsh, tmux, neovim, nvm, claude-code, keepassxc). **Not loaded on Kinoite or Aurora** — atomic OS has no `package:` support, each has its own task tree.
- `arch/`, `pop/`, `fedora/` — distro-specific packages and repos (insync lives per-distro: AUR on Arch, apt repo on Pop, yum repo on classic Fedora). On Kinoite/Aurora Insync is rpm-ostree-layered from `yum.insync.io` — it's not on Flathub. KDE's native `kio-gdrive` was tried and dropped: Google revoked the OAuth client behind `kaccounts-providers`, Drive scope was stripped from the shipped `google.provider`, and the workaround (per-user Google Cloud project with Testing-mode refresh tokens that rotate weekly) is too fragile to codify. Insync's own OAuth flow is stable, so we pay for the licence instead.
- `pop/` is Pop!_OS-specific (not generic Debian/Ubuntu): uses Flatpak for desktop apps (Obsidian, Telegram, Spotify, Bruno) and targets COSMIC desktop. Fires only when `.os.id == "pop"`
- `kinoite/` — plain **Fedora Kinoite** (atomic KDE). Three-layer model:
  - **Host layer** (`host-packages.yml`): full dev stack via `rpm-ostree install` — zsh + plugins, tmux, CLI (git, ripgrep, fd-find, fzf, lazygit, wl-clipboard, bc, jq), editor (neovim), dev runtimes (nodejs, npm, python3-pip, gcc, gcc-c++, make). Each new layer requires reboot; task ends play so user reboots once and re-runs apply. Distrobox was intentionally dropped — wrapper latency and split-PATH confusion weren't worth the `/usr` isolation on a developer workstation.
  - **Flatpak layer**: every GUI app via Flathub (Telegram, Obsidian, Spotify, TickTick, Chrome, KeePassXC, Bruno, DBeaver, Steam). Flathub is not preconfigured on plain Kinoite, so `flathub.yml` adds the remote system-wide. VS Code and Insync stay on rpm-ostree (Microsoft's yum repo and `yum.insync.io`) — VS Code's Flatpak sandbox breaks Remote-SSH/Remote-Containers and debug adapters, and Insync isn't published on Flathub at all.
  - **HOME layer** — Claude Code via official `curl | bash` into `~/.local/bin`, self-updating (`claude-code.yml`). Plus TPM clone + tmux plugin install (`tmux-plugins.yml`) and Lazy.nvim headless sync (`neovim-plugins.yml`).
- `aurora/` — **Aurora** (ublue-os KDE remix of Kinoite, `FROM quay.io/fedora/fedora-kinoite`). Architecturally identical to Kinoite but the base image adds codecs, Flathub with filters, brew, and daily rebuilds. Updates (system + flatpak + brew) are orchestrated by ublue's `uupd.timer`, which on Aurora supplants `rpm-ostreed-automatic.timer`, `flatpak-system-update.timer`, and `brew-upgrade.timer` (the brew-upgrade unit isn't shipped here at all; uupd shells `brew upgrade` itself). We keep a separate task tree (with duplicated Flatpak tasks) rather than branching the kinoite tree — explicit over concise. Per-layer differences from kinoite:
  - **Host layer** (`host-packages.yml`): minimal — only `zsh-syntax-highlighting`, `zsh-autosuggestions`, `gcc-c++` (needed by nvim-treesitter for C++-scanner parsers: yaml, typescript, tsx, prisma). Everything else (`zsh`, `tmux`, `git`, `gcc`, `distrobox`, `podman-docker`, `ptyxis`, `fastfetch`, `htop`, `wl-clipboard`) ships in the Aurora base image. zsh becomes the login shell unconditionally — it's in the base image, no `missing_layers` gate.
  - **Brew layer** (`brew-packages.yml`): dev CLI via preinstalled `/home/linuxbrew/.linuxbrew/` — `neovim`, `python@3.12`, `ripgrep`, `fd`, `fzf`, `lazygit`, `bc`, `jq`. Brew is chowned to UID 1000 by `brew-setup.service` on first boot (no sudo needed). One bulk `community.general.homebrew` call; first provision takes 5–15 min for python+neovim bottles and ansible buffers stdout silently — that's an `ansible Popen+communicate` artefact, not a hang. Node lives in NVM (per-project versions, see `nvm.yml.tmpl`); `wl-clipboard` is in the Aurora base image; Claude Code uses the official `curl | bash` installer rather than brew.
  - **Flatpak layer**: same app list as Kinoite, but **no `flathub.yml`** — Aurora ships Flathub two ways already: a static `/etc/flatpak/remotes.d/flathub.flatpakrepo` and a one-shot `flatpak-add-flathub-repos.service`. Our task would be a redundant idempotent no-op.
  - **KDE-config layer** — `touchpad.yml` (natural scroll on KWin-detected touchpads), `systray.yml` (hide Insync/brightness/clipboard from the tray), `kwin-shortcuts.yml` (Meta+1..9 desktop switching), `pager.yml` (remove Pager applet from panel via plasmashell scripting), `default-browser.yml` (Chrome via mimeapps.list + kdeglobals), `ptyxis.yml`.
  - **HOME layer** — Claude Code via official `curl | bash` into `~/.local/bin`, self-updating (`claude-code.yml`). Plus the same `tmux-plugins.yml` / `neovim-plugins.yml` as Kinoite (the latter pins the absolute brew path `/home/linuxbrew/.linuxbrew/bin/nvim` because ansible spawns non-interactive subprocesses and `/etc/profile.d/brew.sh` only exports PATH for interactive shells), and `ptyxis.yml` which drives the GTK4 terminal (preinstalled in the Aurora base image) via `community.general.dconf`: login-shell on, JetBrainsMono NFM 11pt, Follow System Style, persistent opacity/palette. Konsole is intentionally not configured here — Aurora's default terminal is Ptyxis and we don't fight the base image.
- `darwin/` — macOS apps via Homebrew

Playbook loads tasks in order: distro-specific (`os.idLike`) first, then OS-level (`chezmoi.os`). Kinoite and Aurora skip the OS-level `linux/` import (no classic package manager).

### Conventions

- **Chezmoi-first workflow** — any system config changes (dotfiles, packages, app settings) must be made in chezmoi source first, then applied via `chezmoi apply`. Exception: when it's easier to edit the target file directly (e.g. binary plists, GUI-configured apps) — but then always `chezmoi add` the changed file immediately after.
- **One task file per app** — never bulk installs. Each file is self-contained.
- **Task name prefix** — every `name:` starts with the file's basename + ` | `, e.g. `host-packages | Check currently layered packages`. Makes ansible output visually grouped by file and disambiguates duplicate names across files (three different `Check currently layered packages` tasks live in `host-packages.yml` / `insync.yml` / `vscode.yml`). Apply to all new tasks in any OS subtree.
- **Conditionals at `_main.yml` level** — task files don't check `hosttype` or OS; `_main.yml.tmpl` wraps imports in `{{ if eq .hosttype "work" }}` etc.
- **`import_tasks` paths are relative** to the file containing the import, not the playbook root.
- **`.tmpl` suffix** only on files that use chezmoi template functions. Plain ansible jinja2 doesn't need it.
- **`gather_facts: false`** globally. Use explicit `setup: gather_subset: min` where `ansible_facts` is needed.

### Zsh config

`dot_zshrc.tmpl` assembles zsh config from templates in `.chezmoitemplates/zsh/` via `{{ template "zsh/foo.zsh" . }}`. OS-specific branches go inside templates (e.g., `fzf.zsh` has darwin/linux paths).

### Template variables

Defined in `.chezmoi.yaml.tmpl`:
- `.hosttype` — `home` or `work` (prompted on init)
- `.os.idLike` — normalized distro family.
  - `"pop"` for Pop!_OS (from `ID`)
  - `"kinoite"` for plain Fedora Kinoite (from `ID=fedora` + `VARIANT_ID=kinoite`)
  - `"aurora"` for ublue-os Aurora (from `ID=aurora`; also accepts `ID=fedora` + `VARIANT_ID=aurora` as a fallback)
  - `"arch"` / `"fedora"` for others (from `ID_LIKE`)
- `.chezmoi.os` — darwin, linux, windows

### OS filtering

`.chezmoiignore` excludes irrelevant files per OS and distro. Scripts in `.chezmoiscripts/linux/{arch,pop,fedora,kinoite,aurora}/` and task trees in `.ansible/tasks/{arch,pop,fedora,kinoite,aurora}/` are filtered by `.os.idLike`.

**When adding new files**, always check if the file is OS-specific and add an exclusion rule to `.chezmoiignore` if needed. Without this, files deploy to all systems (e.g., fontconfig on macOS, aerospace.toml on Linux).

## File naming

Chezmoi prefixes map to target attributes:
- `dot_` → `.` (hidden file)
- `private_` → 0600 permissions
- `executable_` → 0755 permissions
- `create_` → only create if doesn't exist, never overwrite
- `run_onchange_` → re-run when content hash changes
- `run_once_` → run only once ever
