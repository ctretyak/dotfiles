#!/bin/bash
set -e

if ! command -v brew &> /dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if ! command -v ansible &> /dev/null; then
  brew install ansible
fi
