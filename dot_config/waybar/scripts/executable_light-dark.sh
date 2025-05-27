#!/bin/bash

# Если вызвано с "toggle", переключаем тему
if [ "$1" = "toggle" ]; then
  current=$(gsettings get org.gnome.desktop.interface color-scheme)

  if [[ "$current" == *'dark'* ]]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
  else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  fi

  pkill -RTMIN+8 waybar
  exit 0
fi

# Показываем иконку в зависимости от текущей темы
# Проверяем GNOME значение или кэш
scheme=$(gsettings get org.gnome.desktop.interface color-scheme)
if [[ "$scheme" == *'dark'* ]]; then
  state="dark"
else
  state="light"
fi

# Выводим нужную иконку
if [ "$state" = "dark" ]; then
  echo "󰖔" # значок луны
else
  echo "󰖙" # значок солнца
fi
