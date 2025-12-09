#!/bin/bash

# Exit immediately if any command fails
set -e

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "[chezmoi] This script is only for macOS"
  exit 1
  
fi

# Install Homebrew if not already installed
if ! command -v brew &> /dev/null; then
  echo "[chezmoi] Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install Ansible if not already installed
if ! command -v ansible &> /dev/null; then
  brew install ansible
fi
