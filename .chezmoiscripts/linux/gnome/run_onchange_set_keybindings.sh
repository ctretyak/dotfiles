#!/bin/bash

gsettings set org.gnome.desktop.wm.keybindings close "['<Super>q']"
gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-left "['<Super><Shift>h']"
gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-right "['<Super><Shift>l']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-1 "['<Super><Shift>1']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-10 "['<Super><Shift>0']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-2 "['<Super><Shift>2']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-3 "['<Super><Shift>3']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-4 "['<Super><Shift>4']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-5 "['<Super><Shift>5']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-6 "['<Super><Shift>6']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-7 "['<Super><Shift>7']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-8 "['<Super><Shift>8']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-9 "['<Super><Shift>9']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-1 "['<Super>1']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-10 "['<Super>0']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-2 "['<Super>2']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-3 "['<Super>3']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-4 "['<Super>4']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-5 "['<Super>5']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-6 "['<Super>6']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-7 "['<Super>7']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-8 "['<Super>8']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-9 "['<Super>9']"
gsettings set org.gnome.desktop.wm.keybindings toggle-maximized "['<Super>m']"
gsettings set org.gnome.mutter.wayland.keybindings restore-shortcuts "['']"
gsettings set org.gnome.settings-daemon.plugins.media-keys screensaver "['<Super>Escape']"
gsettings set org.gnome.shell.keybindings switch-to-application-1 "[]"
gsettings set org.gnome.shell.keybindings switch-to-application-2 "[]"
gsettings set org.gnome.shell.keybindings switch-to-application-3 "[]"
gsettings set org.gnome.shell.keybindings switch-to-application-4 "[]"
gsettings set org.gnome.shell.keybindings switch-to-application-5 "[]"
gsettings set org.gnome.shell.keybindings switch-to-application-6 "[]"
gsettings set org.gnome.shell.keybindings switch-to-application-7 "[]"
gsettings set org.gnome.shell.keybindings switch-to-application-8 "[]"
gsettings set org.gnome.shell.keybindings switch-to-application-9 "[]"
gsettings set org.gnome.shell.keybindings toggle-message-tray "['<Super>v']"

add_custom_gnome_shortcut() {
  if [ "$#" -ne 4 ]; then
    echo "Usage: add_custom_gnome_shortcut <index> \"<Name>\" \"<Command>\" \"<Binding>\""
    return 1
  fi

  local index="$1"
  local name="$2"
  local command="$3"
  local binding="$4"

  local base_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
  local key_path="${base_path}/custom${index}/"
  local schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${key_path}"

  # Получаем текущий список кастомных биндингов
  local current
  current=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)

  # Если путь ещё не добавлен — добавим
  if [[ "$current" != *"$key_path"* ]]; then
    if [[ "$current" == "@as []" ]]; then
      gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$key_path']"
    else
      # Парсим список и добавляем путь
      local current_cleaned
      current_cleaned=$(echo "$current" | tr -d "[]'" | tr ',' '\n' | sed '/^$/d')

      local current_list=()
      while IFS= read -r item; do
        current_list+=("\"$item\"")
      done <<<"$current_cleaned"

      current_list+=("\"$key_path\"")

      # Склеиваем через запятую
      IFS=,
      local new_value="[${current_list[*]}]"
      unset IFS

      # Устанавливаем обновлённый список
      gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$new_value"
    fi
  fi

  # Устанавливаем параметры биндинга
  gsettings set "$schema" name "$name"
  gsettings set "$schema" command "$command"
  gsettings set "$schema" binding "$binding"
}

add_custom_gnome_shortcut 100 "Open Foot" "foot -m" "<Super>Return"
# add_custom_gnome_shortcut 101 "Open Brave" "brave-browser" "<Super>b"
add_custom_gnome_shortcut 101 "Take annotated screenshot" "gtk-launch annotated-screenshot" "<Shift><Super>s"
