#!/bin/bash
set -e
sudo pacman -Syu --noconfirm ansible base-devel git
ansible-galaxy collection install kewlfft.aur
