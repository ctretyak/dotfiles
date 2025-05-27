#!/bin/bash

if ! lspci -nn | grep -i 'vga' | grep -iqE 'nvidia|geforce'; then
  flags="--ozone-platform-hint=auto"

  mkdir -p ~/.config

  echo "$flags" >~/.config/brave-flags.conf
  echo "$flags" >~/.config/chrome-flags.conf
fi
