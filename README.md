# chezmoi

## Initialization

### Fedora

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply ctretyak
```

### Arch

```sh
sudo pacman -S chezmoi --noconfirm
chezmoi init --apply https://ctretyak:__PROJECT_TOKEN__@gitlab.com/ctretyak/chezmoi.git
```

### Snap

```sh
sudo snap install chezmoi --classic
chezmoi init --apply https://ctretyak:__PROJECT_TOKEN__@gitlab.com/ctretyak/chezmoi.git
```

### Windows

```powershell
Set-ExecutionPolicy RemoteSigned; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'));

choco install chezmoi -y;
chezmoi init --apply https://ctretyak:__PROJECT_TOKEN__@gitlab.com/ctretyak/chezmoi.git;

echo "done"
```

## Problems

### Obsidian wayland support

It doesn't necessary if you don't have fractional scaling

```sh
flatpak override --user --socket=wayland md.obsidian.Obsidian
```
