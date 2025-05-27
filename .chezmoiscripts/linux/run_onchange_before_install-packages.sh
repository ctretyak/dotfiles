#!/bin/bash

# Exit immediately if any command fails
set -e

# Detect the OS ID from /etc/os-release
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_ID=$ID
else
  echo "[chezmoi] Could not detect the operating system."
  exit 1
fi

# Install Ansible using the appropriate package manager
case "$OS_ID" in
ubuntu | debian | pop)
  sudo apt update
  sudo apt install -y software-properties-common
  sudo add-apt-repository --yes --update ppa:ansible/ansible
  sudo apt update
  sudo apt install -y ansible
  ;;

fedora)
  sudo dnf makecache
  sudo dnf install -y ansible
  ;;

centos | rhel)
  sudo dnf makecache
  sudo dnf install -y epel-release
  sudo dnf makecache
  sudo dnf install -y ansible
  ;;

arch | endeavouros)
  sudo pacman -Syu --noconfirm ansible
  ansible-galaxy collection install kewlfft.aur
  ;;

void)
  sudo xbps-install -S
  sudo xbps-install -y ansible
  ;;

alpine)
  sudo apk update
  sudo apk add ansible
  ;;

opensuse* | sles)
  sudo zypper refresh
  sudo zypper install -y ansible
  ;;

*)
  echo "[chezmoi] Unsupported or unknown distro: $OS_ID"
  exit 1
  ;;
esac
