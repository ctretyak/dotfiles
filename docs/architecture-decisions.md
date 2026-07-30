# Architecture decisions

Why the ansible task trees look the way they do — package-manager choices, alternatives that
were tried and dropped, base-image quirks. `CLAUDE.md` carries the shape; this file carries
the reasoning. Read it before changing how an app is installed on a given distro.

## Insync vs. KDE's native `kio-gdrive`

Insync lives per-distro: AUR on Arch, apt repo on Pop, yum repo on classic Fedora. On
Kinoite/Aurora it is rpm-ostree-layered from `yum.insync.io` — it's not on Flathub.

KDE's native `kio-gdrive` was tried and dropped: Google revoked the OAuth client behind
`kaccounts-providers`, Drive scope was stripped from the shipped `google.provider`, and the
workaround (per-user Google Cloud project with Testing-mode refresh tokens that rotate weekly)
is too fragile to codify. Insync's own OAuth flow is stable, so we pay for the licence instead.

## Fedora Kinoite (`kinoite/`)

Plain **Fedora Kinoite** (atomic KDE). Three-layer model:

- **Host layer** (`host-packages.yml`): full dev stack via `rpm-ostree install` — zsh + plugins,
  tmux, CLI (git, ripgrep, fd-find, fzf, lazygit, wl-clipboard, bc, jq), editor (neovim), dev
  runtimes (nodejs, npm, python3-pip, gcc, gcc-c++, make). Each new layer requires reboot; task
  ends play so user reboots once and re-runs apply. Distrobox was intentionally dropped — wrapper
  latency and split-PATH confusion weren't worth the `/usr` isolation on a developer workstation.
- **Flatpak layer**: every GUI app via Flathub (Telegram, Obsidian, Spotify, TickTick, Chrome,
  KeePassXC, Bruno, DBeaver, Steam). Flathub is not preconfigured on plain Kinoite, so
  `flathub.yml` adds the remote system-wide. VS Code and Insync stay on rpm-ostree (Microsoft's
  yum repo and `yum.insync.io`) — VS Code's Flatpak sandbox breaks Remote-SSH/Remote-Containers
  and debug adapters, and Insync isn't published on Flathub at all.
- **HOME layer** — Claude Code via official `curl | bash` into `~/.local/bin`, self-updating
  (`claude-code.yml`). Plus TPM clone + tmux plugin install (`tmux-plugins.yml`) and Lazy.nvim
  headless sync (`neovim-plugins.yml`).

## Aurora (`aurora/`)

**Aurora** (ublue-os KDE remix of Kinoite, `FROM quay.io/fedora/fedora-kinoite`).
Architecturally identical to Kinoite but the base image adds codecs, Flathub with filters, brew,
and daily rebuilds. Updates (system + flatpak + brew) are orchestrated by ublue's `uupd.timer`,
which on Aurora supplants `rpm-ostreed-automatic.timer`, `flatpak-system-update.timer`, and
`brew-upgrade.timer` (the brew-upgrade unit isn't shipped here at all; uupd shells `brew upgrade`
itself). We keep a separate task tree (with duplicated Flatpak tasks) rather than branching the
kinoite tree — explicit over concise. Per-layer differences from kinoite:

- **Host layer** (`host-packages.yml`): minimal — only `zsh-syntax-highlighting`,
  `zsh-autosuggestions`, `gcc-c++` (needed by nvim-treesitter for C++-scanner parsers: yaml,
  typescript, tsx, prisma). Everything else (`zsh`, `tmux`, `git`, `gcc`, `distrobox`,
  `podman-docker`, `ptyxis`, `fastfetch`, `htop`, `wl-clipboard`) ships in the Aurora base image.
  zsh becomes the login shell unconditionally — it's in the base image, no `missing_layers` gate.
- **Brew layer** (`brew-packages.yml`): dev CLI via preinstalled `/home/linuxbrew/.linuxbrew/` —
  `neovim`, `python@3.12`, `ripgrep`, `fd`, `fzf`, `lazygit`, `bc`, `jq`. Brew is chowned to UID
  1000 by `brew-setup.service` on first boot (no sudo needed). One bulk
  `community.general.homebrew` call; first provision takes 5–15 min for python+neovim bottles and
  ansible buffers stdout silently — that's an `ansible Popen+communicate` artefact, not a hang.
  Node lives in NVM (per-project versions, see `nvm.yml.tmpl`); `wl-clipboard` is in the Aurora
  base image; Claude Code uses the official `curl | bash` installer rather than brew.
- **Flatpak layer**: same app list as Kinoite, but **no `flathub.yml`** — Aurora ships Flathub two
  ways already: a static `/etc/flatpak/remotes.d/flathub.flatpakrepo` and a one-shot
  `flatpak-add-flathub-repos.service`. Our task would be a redundant idempotent no-op.
- **KDE-config layer** — `touchpad.yml` (natural scroll on KWin-detected touchpads), `systray.yml`
  (hide Insync/brightness/clipboard from the tray), `kwin-shortcuts.yml` (Meta+1..9 desktop
  switching), `pager.yml` (remove Pager applet from panel via plasmashell scripting),
  `default-browser.yml` (Chrome via mimeapps.list + kdeglobals), `ptyxis.yml`.
- **HOME layer** — Claude Code via official `curl | bash` into `~/.local/bin`, self-updating
  (`claude-code.yml`). Plus the same `tmux-plugins.yml` / `neovim-plugins.yml` as Kinoite (the
  latter pins the absolute brew path `/home/linuxbrew/.linuxbrew/bin/nvim` because ansible spawns
  non-interactive subprocesses and `/etc/profile.d/brew.sh` only exports PATH for interactive
  shells), and `ptyxis.yml` which drives the GTK4 terminal (preinstalled in the Aurora base image)
  via `community.general.dconf`: login-shell on, JetBrainsMono NFM 11pt, Follow System Style,
  persistent opacity/palette. Konsole is intentionally not configured here — Aurora's default
  terminal is Ptyxis and we don't fight the base image.

## Pop!_OS (`pop/`)

Pop!_OS-specific, not generic Debian/Ubuntu: uses Flatpak for desktop apps (Obsidian, Telegram,
Spotify, Bruno) and targets COSMIC desktop. Fires only when `.os.id == "pop"`.
