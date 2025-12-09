# chezmoi

## Initialization

### Windows

```powershell
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "This script must be run as Administrator." -ForegroundColor Red
    exit 1
}

Set-ExecutionPolicy RemoteSigned; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'));
```

and after in non-admin terminal

```powershell
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "This script must NOT be run as Administrator." -ForegroundColor Red
    exit 1
}

choco install chezmoi -y;
chezmoi init --apply ctretyak
```

### Ubuntu

```sh
sudo snap install chezmoi --classic
chezmoi init --apply ctretyak
```

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

## Problems

### Obsidian wayland support

It doesn't necessary if you don't have fractional scaling

```sh
flatpak override --user --socket=wayland md.obsidian.Obsidian
```
