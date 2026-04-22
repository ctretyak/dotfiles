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

- `linux/` — common Linux tasks (git, zsh, tmux, neovim, nvm, claude-code, keepassxc). **Not loaded on Kinoite** — atomic OS has no `package:` support, Kinoite handles everything in `kinoite/`.
- `arch/`, `pop/`, `fedora/` — distro-specific packages and repos (insync lives here per-distro: AUR on Arch, apt repo on Pop, yum repo on Fedora)
- `pop/` is Pop!_OS-specific (not generic Debian/Ubuntu): uses Flatpak for desktop apps (Obsidian, Telegram, Spotify, Bruno) and targets COSMIC desktop. Fires only when `.os.id == "pop"`
- `kinoite/` serves both **Fedora Kinoite** and **Aurora** (ublue-os KDE remix of Kinoite). Aurora is architecturally identical to Kinoite (same rpm-ostree, same KDE, `FROM kinoite` in their Containerfile), so we share the task tree and branch on `.os.variant` only where behavior differs. Layer model:
  - **Host layer** (`host-packages.yml.tmpl`): `rpm-ostree install`. On Kinoite this is the full dev stack — shell, tmux, CLI tools, neovim, nodejs/npm, python3-pip, gcc toolchain. On Aurora base already ships zsh/tmux/git/distrobox/podman-docker/fastfetch etc., so the layer is reduced to just `zsh-syntax-highlighting`, `zsh-autosuggestions`, `gcc`, `gcc-c++`, `make` — dev CLI moves to brew. Each new layer requires reboot; task ends play so user reboots once and re-runs apply. Distrobox was intentionally dropped on Kinoite (wrapper latency, split-PATH) and kept out of Aurora flow despite being preinstalled.
  - **Brew layer** (`brew-packages.yml`, Aurora only): dev CLI via preinstalled `/home/linuxbrew/.linuxbrew/` — `neovim`, `node`, `python@3.12`, `ripgrep`, `fd`, `fzf`, `lazygit`, `bc`, `jq`, `wl-clipboard`. ublue's `brew-upgrade.timer` auto-upgrades on boot + every 8h.
  - **Flatpak layer**: every GUI app via Flathub (Telegram, Obsidian, Spotify, TickTick, Chrome, Ghostty, KeePassXC, Insync, Bruno, DBeaver, Steam). VS Code intentionally stays on rpm-ostree (Microsoft's repo) — the Flatpak sandbox breaks Remote-SSH/Remote-Containers and debug adapters.
  - **HOME layer** — Claude Code. On plain Kinoite (`claude-code-curl.yml`) via official `curl | bash` into `~/.local/bin`, self-updating. On Aurora (`claude-code-brew.yml`) via preinstalled Homebrew — self-updates ride the same brew timer. Also here: TPM clone + tmux plugin install (`tmux-plugins.yml`), Lazy.nvim sync (`neovim-plugins.yml`). Both run for both variants.
  Aurora-specific differences beyond those two branch files are all preinstalled in the base image (codecs, Flathub filters, brew, brew-upgrade.timer) — no extra ansible work needed. Fires when `VARIANT_ID=kinoite` or `VARIANT_ID=aurora` (detected in `.chezmoi.yaml.tmpl`, both set `os.idLike=kinoite`). The `linux/_main.yml` import is skipped on both because package tasks assume a mutable classic package manager.
- `darwin/` — macOS apps via Homebrew

Playbook loads tasks in order: distro-specific (`os.idLike`) first, then OS-level (`chezmoi.os`). Kinoite skips the OS-level import.

### Conventions

- **Chezmoi-first workflow** — any system config changes (dotfiles, packages, app settings) must be made in chezmoi source first, then applied via `chezmoi apply`. Exception: when it's easier to edit the target file directly (e.g. binary plists, GUI-configured apps) — but then always `chezmoi add` the changed file immediately after.
- **One task file per app** — never bulk installs. Each file is self-contained.
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
  - `"kinoite"` for Fedora Atomic KDE **and** Aurora (both route through `kinoite/` tasks)
  - `"arch"` / `"fedora"` for others (from `ID_LIKE`)
- `.os.variant` — distinguishes atomic KDE flavors.
  - `"kinoite"` for plain Fedora Kinoite (`VARIANT_ID=kinoite`)
  - `"aurora"` for ublue-os Aurora (`VARIANT_ID=aurora`)
  - empty string on other systems
- `.chezmoi.os` — darwin, linux, windows

### OS filtering

`.chezmoiignore` excludes irrelevant files per OS and distro. Scripts in `.chezmoiscripts/linux/{arch,pop,fedora,kinoite}/` are filtered by `.os.idLike`.

**When adding new files**, always check if the file is OS-specific and add an exclusion rule to `.chezmoiignore` if needed. Without this, files deploy to all systems (e.g., fontconfig on macOS, aerospace.toml on Linux).

## File naming

Chezmoi prefixes map to target attributes:
- `dot_` → `.` (hidden file)
- `private_` → 0600 permissions
- `executable_` → 0755 permissions
- `create_` → only create if doesn't exist, never overwrite
- `run_onchange_` → re-run when content hash changes
- `run_once_` → run only once ever
