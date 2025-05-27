#!/bin/bash

DIRECTORY="$HOME/.install"

for script in "$DIRECTORY"/*.sh; do
  if [[ -f "$script" ]]; then
    ACCESS_TIME=$(stat -c %X "$script")
    MODIFY_TIME=$(stat -c %Y "$script")

    if [[ "$ACCESS_TIME" -eq "$MODIFY_TIME" ]]; then
      bash "$script"
      touch -a "$script"
    fi
  fi
done
