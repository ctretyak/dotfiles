#!/bin/bash

prev_layout=""

while true; do
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
  if [ "$layout" != "$prev_layout" ]; then
    kill -SIGRTMIN+8 $(pidof waybar)
    prev_layout=$layout
  fi
  sleep 0.1
done
