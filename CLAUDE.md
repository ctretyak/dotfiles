# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Chezmoi dotfiles repository. Manages configs across macOS, Linux (Arch, Debian/Ubuntu/Pop!_OS, Fedora, Fedora Kinoite), and Windows. Package installation is delegated to Ansible, triggered automatically by chezmoi.

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
- `kinoite/` is Fedora Atomic KDE-specific. Three-layer model:
  - **Host layer** (`host-packages.yml`): `rpm-ostree install` everything needed for interactive + dev work — shell, tmux, CLI tools (git, ripgrep, fd, fzf, lazygit, wl-clipboard, bc, jq), editor (neovim), dev runtimes (nodejs, npm, python3-pip, gcc, gcc-c++, make). Each new layer requires reboot; task ends play so user reboots once, then re-runs apply. Distrobox was intentionally dropped — wrapper latency and split-PATH confusion weren't worth the `/usr` isolation on a developer workstation.
  - **Flatpak layer** (all `*.yml` except host/claude-code/fonts): every GUI app via Flathub (Telegram, Obsidian, Spotify, TickTick, Chrome, VS Code, Ghostty, KeePassXC, Insync, Bruno, DBeaver, Steam).
  - **HOME layer** (`claude-code.yml`): official `curl | bash` installers that write into `$HOME` directly (Claude Code → `~/.local/bin/claude`). No layer, no container — HOME is writable on Kinoite. Use this path for vendor installers that respect `$HOME` and carry their own self-update.
  Fires only when `VARIANT_ID=kinoite` (detected in `.chezmoi.yaml.tmpl`). The `linux/_main.yml` import is skipped on Kinoite because package tasks assume a mutable classic package manager.
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
  - `"kinoite"` for Fedora Atomic KDE (from `ID=fedora` + `VARIANT_ID=kinoite`)
  - `"arch"` / `"fedora"` for others (from `ID_LIKE`)
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
