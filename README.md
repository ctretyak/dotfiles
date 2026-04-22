# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/), provisioned via Ansible.

## Supported systems

| OS | Distros |
|----|---------|
| macOS | Homebrew |
| Linux | Arch, Pop!_OS, Fedora, Fedora Kinoite (atomic KDE), Aurora (ublue-os KDE) |
| Windows | Chocolatey (minimal) |

## What's managed

**Shell:** Zsh, Powerlevel10k, Zinit (autosuggestions, completions, syntax highlighting), fzf, NVM

**Dev tools:** Neovim, Git (multi-identity + GPG), Docker, tmux + TPM, Claude Code

**Apps:** Google Chrome, Obsidian, Telegram, Spotify, TickTick, KeePassXC, VSCode

**macOS-only:** Google Drive, CleanShot, Viscosity, DarkModeBuddy (MacBook)

**Linux-only:** Insync (Google Drive), libsecret (credential storage); Pop!_OS uses Flatpak for desktop apps (Obsidian, Telegram, Spotify, Bruno); Kinoite uses rpm-ostree + Flatpak; Aurora same as Kinoite but Claude Code installed via preinstalled Homebrew

**Work profile:** Bruno, DBeaver &mdash; enabled via `hosttype: work` in chezmoi config

## Bootstrap

### macOS

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install chezmoi
chezmoi init --apply ctretyak
```

### Arch

```sh
sudo pacman -S chezmoi --noconfirm
chezmoi init --apply ctretyak
```

### Debian / Ubuntu / Pop!_OS

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply ctretyak
```

### Fedora

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply ctretyak
```

### Fedora Kinoite

Atomic KDE variant &mdash; `/usr` is read-only, so the provision runs in 2 cycles: bootstrap layers `ansible` + `git`, reboot, re-run apply, the second cycle layers shell/CLI/editor/dev runtimes plus installs Flatpaks, reboot again to activate.

```sh
# rpm-ostree install chezmoi  &&  sudo systemctl reboot
chezmoi init --apply ctretyak
sudo systemctl reboot
chezmoi apply
```

After bootstrap:
- **Host** (rpm-ostree layers): shell (`zsh` + plugins, `tmux`), CLI (`git`, `ripgrep`, `fd-find`, `fzf`, `lazygit`, `wl-clipboard`, `bc`, `jq`), editor (`neovim`), dev runtimes (`nodejs`, `npm`, `python3-pip`, `gcc`, `gcc-c++`, `make`)
- **Flatpak**: all GUI apps (Chrome, Telegram, Obsidian, Spotify, TickTick, VS Code, KeePassXC, Insync, Ghostty, Steam, Bruno, DBeaver)
- **HOME installers**: Claude Code via official `curl | bash` &mdash; lands in `~/.local/bin/claude`, self-updates

### Aurora (ublue-os KDE)

Image-based KDE remix of Kinoite from [Universal Blue](https://projectbluefin.io/). Inherits Fedora Kinoite base (same rpm-ostree, same KDE) and adds preinstalled codecs, filtered Flathub, Homebrew, and daily rebuilds. Everything in chezmoi routes through the same `tasks/kinoite/` tree — Aurora is detected via `VARIANT_ID=aurora` and only differs in how Claude Code is installed (Homebrew instead of `curl | bash`).

```sh
# rpm-ostree install chezmoi  &&  sudo systemctl reboot
chezmoi init --apply ctretyak
sudo systemctl reboot
chezmoi apply
```

After bootstrap (delta vs Kinoite):
- **Host codecs and Mesa-freeworld**: preinstalled in Aurora image, no manual RPM Fusion override needed (Kinoite requires it for hardware H.264/H.265 decode)
- **Flathub**: preinstalled with filters, bootstrap skips the remote-add step
- **Homebrew**: preinstalled at `/home/linuxbrew/.linuxbrew/` &mdash; Claude Code and any future `curl | bash` HOME installers should prefer brew on Aurora for self-updates
- Everything else (rpm-ostree layers, Flatpak app list) is identical to Kinoite

Switching between Kinoite and Aurora post-install is a single `bootc switch` command (no reinstall).

### Windows

Admin:
```powershell
Set-ExecutionPolicy RemoteSigned
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
choco install chezmoi -y
```

Non-admin:
```powershell
chezmoi init --apply ctretyak
```

## How it works

```
chezmoi init --apply
  -> .chezmoiscripts/   # install ansible + dependencies
  -> chezmoi apply      # lay down dotfiles
  -> ansible-playbook   # install packages & configure apps
```

**Chezmoi scripts** (`.chezmoiscripts/`) bootstrap Ansible per distro, then trigger the playbook.

**Ansible tasks** (`dot_ansible/tasks/`) are organized by OS:
- `linux/` &mdash; common Linux tasks (zsh, git, tmux, neovim, claude-code, nvm, keepassxc). Skipped on Kinoite/Aurora (no `package:` support).
- `arch/`, `pop/`, `fedora/` &mdash; distro-specific packages and repos (including insync, which uses different package managers per distro)
- `kinoite/` &mdash; serves both Fedora Kinoite and Aurora (same base image architecture): rpm-ostree layering for shell + CLI + editor + dev runtimes, Flatpak for GUI apps. Claude Code installs via `curl | bash` into `$HOME` on Kinoite or `brew install` on Aurora (variant detected in `.chezmoi.yaml.tmpl`).
- `darwin/` &mdash; macOS apps via Homebrew

Each directory has `_main.yml.tmpl` that imports individual task files. Work/home conditionals live at `_main.yml` level.

**Templates** (`.chezmoitemplates/zsh/`) are shared zsh config fragments included by `dot_zshrc.tmpl`.

## Git identities

The `git/setup-git-identities.sh` script manages multiple git identities stored in `~/git/{name}/.gitconfig`, each with its own email, name, and optional GPG key. Identities are activated via `includeIf` in `~/.gitconfig.local`.

## Configuration

`~/.config/chezmoi/chezmoi.yaml` is generated from `.chezmoi.yaml.tmpl` and sets:
- `hosttype` &mdash; `home` or `work` (controls which apps are installed)
- `os.idLike` &mdash; normalized distro family:
  - `"pop"` for Pop!_OS (from `ID=pop`)
  - `"kinoite"` for Fedora Atomic KDE **and** Aurora (both are atomic KDE — same task tree)
  - `"arch"` / `"fedora"` otherwise (from `ID_LIKE`)
- `os.variant` &mdash; distinguishes atomic KDE flavors:
  - `"kinoite"` for plain Fedora Kinoite
  - `"aurora"` for ublue-os Aurora
  - empty on other systems
