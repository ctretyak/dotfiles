#!/bin/bash
set -e

if command -v ansible >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
    exit 0
fi

sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt update
sudo apt install -y ansible git
