#!/bin/bash

WALLPAPER_DIR="$HOME/.local/share/backgrounds/wallpapers"

# Проверка: существует ли папка
if [ ! -d "$WALLPAPER_DIR" ]; then
  echo "❌ Directory not found: $WALLPAPER_DIR"
  exit 1
fi

# Поиск изображений (jpg, png, jpeg, webp, avif, etc.)
mapfile -t images < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.avif" \))

# Проверка: есть ли изображения
if [ "${#images[@]}" -eq 0 ]; then
  echo "❌ No image files found in $WALLPAPER_DIR"
  exit 1
fi

# Выбор случайного изображения
RANDOM_IMAGE="${images[RANDOM % ${#images[@]}]}"

# Установка обоев через gsettings
gsettings set org.gnome.desktop.background picture-uri "file://$RANDOM_IMAGE"
gsettings set org.gnome.desktop.background picture-uri-dark "file://$RANDOM_IMAGE"
