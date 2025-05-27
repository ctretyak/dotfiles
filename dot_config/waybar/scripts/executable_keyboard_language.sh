#!/bin/bash

layout=$(hyprctl devices | awk '
    /active keymap:/ {
        sub(/.*active keymap: /, "");
        layout=$0
    }
    /main: yes/ {
        print layout;
        exit
    }
')

# Получаем первые две буквы и переводим их в верхний регистр
short_layout=$(echo "$layout" | cut -c1-2 | tr '[:lower:]' '[:upper:]')

echo "{\"text\": \"$short_layout\", \"tooltip\": \"$layout\"}"
