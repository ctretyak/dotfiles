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
- `arch/`, `pop/`, `fedora/` — distro-specific packages and repos. Insync lives per-distro: AUR on Arch, apt repo on Pop, yum repo on classic Fedora; rpm-ostree-layered on Kinoite/Aurora.
- `pop/` is Pop!_OS-specific (not generic Debian/Ubuntu): Flatpak for desktop apps, targets COSMIC. Fires only when `.os.id == "pop"`.
- `kinoite/` — plain **Fedora Kinoite** (atomic KDE). Three layers: **host** (`rpm-ostree` dev stack, reboot-gated — task ends play so user reboots once and re-runs apply), **Flatpak** (GUI apps; `flathub.yml` adds the remote), **HOME** (`claude-code.yml`, `tmux-plugins.yml`, `neovim-plugins.yml`).
- `aurora/` — **Aurora** (ublue-os KDE remix of Kinoite). Same shape as `kinoite/`, kept as a separate tree with duplicated Flatpak tasks — explicit over concise. Layers: **host** (minimal, most of the stack ships in the base image), **brew** (dev CLI via preinstalled linuxbrew), **Flatpak** (no `flathub.yml`), **KDE config** (`touchpad`, `systray`, `kwin-shortcuts`, `pager`, `default-browser`, `ptyxis`), **HOME** (same as Kinoite).
- `darwin/` — macOS apps via Homebrew

Playbook loads tasks in order: distro-specific (`os.idLike`) first, then OS-level (`chezmoi.os`). Kinoite and Aurora skip the OS-level `linux/` import (no classic package manager).

**Why these trees look the way they do** — package-manager choices, alternatives tried and dropped (`kio-gdrive`, distrobox, VS Code on Flatpak), base-image quirks: [`docs/architecture-decisions.md`](docs/architecture-decisions.md). Read it before changing how an app is installed on a given distro.

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
