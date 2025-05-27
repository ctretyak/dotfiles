#!/bin/bash

gsettings set org.gnome.GWeather4 temperature-unit "centigrade"
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ru')]"
gsettings set org.gnome.desktop.interface clock-format '24h'
gsettings set org.gnome.desktop.peripherals.touchpad disable-while-typing false
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
gsettings set org.gnome.desktop.privacy old-files-age "uint32 60"
gsettings set org.gnome.desktop.privacy remove-old-trash-files true
gsettings set org.gnome.desktop.wm.preferences num-workspaces 4
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.mutter workspaces-only-on-primary false
gsettings set org.gnome.shell favorite-apps "['brave-browser.desktop', 'org.gnome.nautilus.desktop', 'foot.desktop', 'org.telegram.desktop.desktop', 'obsidian.desktop']"
gsettings set org.gnome.system.location enabled true

if ! lspci -nn | grep -i 'vga' | grep -iqE 'nvidia|geforce'; then
  gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
fi
