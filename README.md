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

**Linux-only:** Insync (Google Drive — rpm-ostree layer from yum.insync.io on Kinoite/Aurora, AUR on Arch, apt repo on Pop, yum repo on classic Fedora), libsecret (credential storage); Pop!_OS uses Flatpak for desktop apps (Obsidian, Telegram, Spotify, Bruno); Kinoite uses rpm-ostree + Flatpak; Aurora uses preinstalled Homebrew for the dev CLI + Claude Code, minimal rpm-ostree layer, and the same Flatpak GUI list

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
- **Flatpak**: all GUI apps (Chrome, Telegram, Obsidian, Spotify, TickTick, VS Code, KeePassXC, Steam, Bruno, DBeaver)
- **HOME installers**: Claude Code via official `curl | bash` &mdash; lands in `~/.local/bin/claude`, self-updates

### Aurora (ublue-os KDE)

Image-based KDE remix of Kinoite from [Universal Blue](https://projectbluefin.io/). Inherits Fedora Kinoite base (same rpm-ostree, same KDE, `FROM quay.io/fedora/fedora-kinoite` in their Containerfile) and adds preinstalled codecs, filtered Flathub, Homebrew, and daily rebuilds. Detected via `VARIANT_ID=aurora` (`os.idLike=aurora`) and routed to its own `tasks/aurora/` tree — the Flatpak task files duplicate the Kinoite ones for explicit visibility rather than sharing via conditional imports.

Chezmoi itself is installed via the preinstalled Homebrew instead of rpm-ostree — userland install means no bootstrap reboot. Updates (system + flatpak + brew) are driven by ublue's `uupd.timer`, so we don't manage brew upgrades from chezmoi.

The provision needs two reboots: one to activate the layered `ansible` package, then one to activate everything else the playbook layers in (host packages, VS Code, Insync). The actual chezmoi/ansible work happens on the second `chezmoi apply`.

```sh
brew install chezmoi
chezmoi init --apply ctretyak
sudo systemctl reboot   # 1st reboot: ansible layered during bootstrap
chezmoi apply           # 2nd apply: layers host packages + VS Code + Insync,
                        #            installs brew formulae, Flatpaks, configs
sudo systemctl reboot   # 2nd reboot: activates the layered rpm-ostree slice
```

After bootstrap (delta vs Kinoite):
- **Host codecs and Mesa-freeworld**: preinstalled in Aurora image, no manual RPM Fusion override needed (Kinoite requires it for hardware H.264/H.265 decode)
- **Flathub**: preconfigured two ways — a static `/etc/flatpak/remotes.d/flathub.flatpakrepo` ships in the image, and ublue's `flatpak-add-flathub-repos.service` adds the remote one-shot at first boot. `aurora/` has no `flathub.yml` task
- **Updates**: handled end-to-end by `uupd.timer` (Universal blue update daemon) — supplants `rpm-ostreed-automatic.timer`, `flatpak-system-update.timer`, and `brew-upgrade.timer` (the brew-upgrade unit isn't shipped on Aurora; uupd shells `brew upgrade` itself)
- **Homebrew**: preinstalled at `/home/linuxbrew/.linuxbrew/` and chowned to UID 1000 by `brew-setup.service` on first boot. Dev CLI lives here — `neovim`, `python@3.12`, `ripgrep`, `fd`, `fzf`, `lazygit`, `bc`, `jq`. Node moved to NVM (per-project versions), Claude Code to the official `curl | bash` installer in `~/.local/bin`. chezmoi itself is bootstrapped via brew rather than rpm-ostree
- **Host layer shrinks**: rpm-ostree layers only `zsh-syntax-highlighting`, `zsh-autosuggestions`, `gcc-c++` (the latter for nvim-treesitter's C++ scanners). Everything else moves to brew or already ships in the Aurora image (zsh, tmux, git, gcc, fastfetch, htop, distrobox, podman-docker, ptyxis, wl-clipboard)
- Flatpak app list, VS Code rpm repo, and fonts tasks mirror Kinoite (duplicated files under `tasks/aurora/`)

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

**Ansible tasks** (`dot_ansible/tasks/`) are organized by OS &mdash; one directory per distro (`linux/`, `arch/`, `pop/`, `fedora/`, `kinoite/`, `aurora/`, `darwin/`), each with an `_main.yml.tmpl` that imports one task file per app. Work/home conditionals live at `_main.yml` level. Kinoite and Aurora are atomic and skip the shared `linux/` tree entirely.

**Templates** (`.chezmoitemplates/zsh/`) are shared zsh config fragments included by `dot_zshrc.tmpl`.

For the per-distro breakdown see [`CLAUDE.md`](CLAUDE.md); for why each distro installs things the way it does &mdash; dropped alternatives, base-image quirks &mdash; see [`docs/architecture-decisions.md`](docs/architecture-decisions.md).

## Git identities

The `git/setup-git-identities.sh` script manages multiple git identities stored in `~/git/{name}/.gitconfig`, each with its own email, name, and optional GPG key. Identities are activated via `includeIf` in `~/.gitconfig.local`.

## Configuration

`~/.config/chezmoi/chezmoi.yaml` is generated from `.chezmoi.yaml.tmpl` and sets two variables: `hosttype` (`home` or `work` &mdash; controls which apps are installed) and `os.idLike` (normalized distro family). Detection rules and the full value list are in [`CLAUDE.md`](CLAUDE.md).
